#' Prepare marker signals for gating
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Selects one signal per cell and marker according to the configuration's
#' signal policy, applies the per-marker transform, resolves localisation
#' measurements, and computes callability checks that run before any
#' correction or threshold (see [gk_callability()]).
#'
#' A panel marker whose measurement is missing from the cell table is a
#' structural failure (`gatekeepr_error_structure`). A marker that is present
#' but carries no usable signal is not an error: it is reported as not
#' callable, and every rule depending on it is disabled later.
#'
#' @param x A `cellspec` object (see [gk_cellspec()]) or the path of a
#'   cellspec directory.
#' @param config A [gk_config()].
#' @param image_id `NULL` for all images, or the images to keep.
#' @param quiet Suppress the summary message?
#'
#' @return An object of class `gk_prepared`, a list with:
#' * `cells`: data frame `image_id`, `cell_id`, `sample_id`, `x`, `y`;
#' * `signal_raw`: cells x panel markers, selected raw signal (`NA` where
#'   unavailable);
#' * `score`: transformed signal;
#' * `source`: integer matrix, 1 = preferred compartment, 2 = fallback,
#'   0 = unavailable; `source_labels` describes the features;
#' * `localization`: named list of per-marker data frames with
#'   `numerator`, `denominator`, `ratio` and `evaluable`;
#' * `callability`: see [gk_callability()];
#' * `transforms`: marker, transform and cofactor;
#' * `config`, `config_sha256`, `source_sha256` and `source_manifest_sha256`.
#'
#' @examples
#' x <- gk_read_cellspec(gk_example_path("example-slide"))
#' prep <- gk_prepare(x, gk_example_config())
#' prep
#' gk_callability(prep)
#'
#' @family preparation
#' @export
gk_prepare <- function(x, config, image_id = NULL, quiet = FALSE) {
  if (is.character(x) && length(x) == 1L) {
    x <- gk_read_cellspec(x)
  }
  .gk_validate_cellspec(x)
  .gk_check_class(config, "gk_config", hint = "Build it with {.fn gk_config} or {.fn gk_read_config}.")
  .gk_check_flag(quiet)
  rows <- seq_len(nrow(x$cells))
  if (!is.null(image_id)) {
    .gk_check_character(image_id, min_length = 1L)
    unknown <- setdiff(image_id, x$cells$image_id)
    if (length(unknown) > 0L) {
      .gk_abort("Image{?s} {.val {unknown}} {?is/are} not in the cell table.", class = "input")
    }
    rows <- which(x$cells$image_id %in% image_id)
  }
  if (length(rows) == 0L) {
    .gk_abort("The cell table has no cells.", class = "structure")
  }
  pm <- config$panel$markers
  policy <- config$signal_policy[match(pm$marker, config$signal_policy$marker), , drop = FALSE]
  sig <- .gk_signal_matrix(x, policy, rows = rows)
  score <- .gk_transform(sig$signal, pm)
  localization <- .gk_localization(x, config, rows)
  cells <- x$cells[rows, c("image_id", "cell_id", "sample_id", "x", "y"), drop = FALSE]
  rownames(cells) <- NULL

  d <- x$dictionary
  used_features <- unique(c(
    unlist(lapply(seq_len(nrow(policy)), function(j) {
      fb <- policy$fallback_compartment[[j]]
      d$feature_id[c(
        .gk_find_feature(d, policy$marker[[j]], policy$compartment[[j]], policy$statistic[[j]]),
        if (!is.na(fb)) .gk_find_feature(d, policy$marker[[j]], fb, policy$statistic[[j]])
      )]
    })),
    attr(localization, "features")
  ))
  used_features <- sort(used_features)
  source_sha256 <- .gk_sha256_data(
    cells$image_id, cells$cell_id, cells$x, cells$y,
    x$measurements[rows, used_features, drop = FALSE]
  )
  prepared <- structure(
    list(
      cells = cells,
      signal_raw = sig$signal,
      score = score,
      source = sig$source,
      source_labels = sig$labels,
      localization = localization,
      callability = NULL,
      transforms = pm[, c("marker", "transform", "cofactor")],
      config = config,
      config_sha256 = gk_config_hash(config),
      source_sha256 = source_sha256,
      source_manifest_sha256 = x$provenance$manifest_sha256 %||% NA_character_,
      created_utc = .gk_utc_now(),
      gatekeepr_version = .gk_package_version()
    ),
    class = "gk_prepared"
  )
  prepared$callability <- .gk_support_callability(prepared)
  if (!quiet) {
    cb <- prepared$callability
    n_not <- sum(grepl("^NOT_CALLABLE", cb$status))
    cli::cli_inform(c(
      "v" = "Prepared {format(nrow(cells), big.mark = ',')} {cli::qty(nrow(cells))}cell{?s} on {length(unique(cells$image_id))} image{?s}, {nrow(pm)} marker{?s}.",
      if (n_not > 0L) {
        c("!" = "{n_not} image x marker combination{?s} not callable: {.val {unique(paste(cb$marker[grepl('^NOT_CALLABLE', cb$status)]))}}.")
      }
    ))
  }
  prepared
}

.gk_transform <- function(signal, pm) {
  score <- signal
  for (j in seq_len(nrow(pm))) {
    v <- signal[, j]
    score[, j] <- switch(pm$transform[[j]],
      asinh = asinh(v / pm$cofactor[[j]]),
      log1p = log1p(v),
      none = v
    )
  }
  score
}

# Raw numerator/denominator measurements for localisation rules; ratio as in
# the reference builder: (numerator + 1e-9) / (denominator + 1e-9), evaluable only
# where both are finite.
.gk_localization <- function(x, config, rows) {
  loc <- config$panel$localization
  loc <- loc[!vapply(loc, is.null, logical(1))]
  d <- x$dictionary
  features <- character()
  out <- lapply(names(loc), function(mk) {
    rule <- loc[[mk]]
    stat <- rule$statistic %||% "mean"
    jn <- .gk_find_feature(d, mk, rule$numerator, stat)
    jd <- .gk_find_feature(d, mk, rule$denominator, stat)
    features <<- c(features, d$feature_id[c(jn, jd)])
    num <- x$measurements[rows, jn]
    den <- x$measurements[rows, jd]
    evaluable <- is.finite(num) & is.finite(den)
    ratio <- rep(NA_real_, length(rows))
    ratio[evaluable] <- (num[evaluable] + 1e-9) / (den[evaluable] + 1e-9)
    data.frame(numerator = num, denominator = den, ratio = ratio, evaluable = evaluable)
  })
  names(out) <- names(loc)
  attr(out, "features") <- features
  out
}

#' @export
print.gk_prepared <- function(x, ...) {
  cb <- x$callability
  imgs <- unique(x$cells$image_id)
  cli::cli_text(
    "{.cls gk_prepared}: {format(nrow(x$cells), big.mark = ',')} {cli::qty(nrow(x$cells))}cell{?s}, ",
    "{length(imgs)} image{?s}, {ncol(x$score)} marker{?s}"
  )
  cli::cli_bullets(c(
    "*" = "Config SHA-256: {.val {(.gk_short_hash(x$config_sha256))}}",
    "*" = "Source SHA-256: {.val {(.gk_short_hash(x$source_sha256))}}"
  ))
  tab <- table(cb$status)
  cli::cli_text("Callability: {paste(names(tab), tab, sep = ' = ', collapse = '; ')}")
  invisible(x)
}
