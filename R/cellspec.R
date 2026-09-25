# Internal adapter for the cellspec 1.0 cell-table format.
#
# The cellspec specification and canonical disk schema are owned by cellspecR.
# gatekeepR retains its minimal in-memory validation and legacy disk adapter
# for compatibility. Canonical disk I/O delegates to cellspecR; it must not
# silently reinterpret uncalibrated legacy objects as canonical objects.

.gk_cellspec_version <- "1.0.0"

#' Declare which measurement represents each marker
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A signal policy chooses, per marker, the compartment and statistic whose
#' value represents the marker, with an optional fallback compartment used per
#' cell when the preferred value is missing or below `min_value`. The result
#' has the same structure as `cellspecR::cs_signal_policy()`, so either can be
#' used in [gk_config()].
#'
#' @param marker Character vector of unique marker names.
#' @param compartment Preferred compartment per marker: `"cell"`,
#'   `"nucleus"`, `"cytoplasm"` or `"membrane"`. Recycled.
#' @param statistic Statistic per marker, e.g. `"mean"`. Recycled.
#' @param fallback_compartment Compartment used when the preferred value is
#'   unavailable, or `NA` for none. Recycled.
#' @param min_value Values below this are treated as unavailable. Recycled.
#'
#' @return A data frame of class `gk_signal_policy` (also `cs_signal_policy`)
#'   with columns `marker`, `compartment`, `statistic`,
#'   `fallback_compartment` and `min_value`.
#'
#' @examples
#' gk_signal_policy(
#'   marker = c("CD3e", "FOXP3", "PanCK"),
#'   compartment = c("cell", "nucleus", "cytoplasm"),
#'   fallback_compartment = c(NA, NA, "cell")
#' )
#'
#' @family configuration
#' @export
gk_signal_policy <- function(marker, compartment = "cell", statistic = "mean",
                             fallback_compartment = NA_character_,
                             min_value = 0) {
  .gk_check_character(marker, min_length = 1L, unique = TRUE)
  n <- length(marker)
  recycle <- function(x, arg) {
    if (length(x) == 1L) {
      return(rep(x, n))
    }
    if (length(x) != n) {
      .gk_abort(
        "{.arg {arg}} must have length 1 or {n} (the number of markers).",
        class = "config", call = rlang::caller_env(2L)
      )
    }
    x
  }
  compartment <- recycle(compartment, "compartment")
  statistic <- recycle(statistic, "statistic")
  fallback_compartment <- recycle(as.character(fallback_compartment), "fallback_compartment")
  min_value <- recycle(min_value, "min_value")
  policy <- data.frame(
    marker = as.character(marker),
    compartment = as.character(compartment),
    statistic = as.character(statistic),
    fallback_compartment = as.character(fallback_compartment),
    min_value = as.double(min_value),
    stringsAsFactors = FALSE
  )
  .gk_validate_signal_policy(policy)
}

.gk_compartments <- c("cell", "nucleus", "cytoplasm", "membrane")

.gk_validate_signal_policy <- function(policy, call = rlang::caller_env()) {
  need <- c("marker", "compartment", "statistic", "fallback_compartment", "min_value")
  if (!is.data.frame(policy) || !all(need %in% names(policy))) {
    .gk_abort(
      c(
        "The signal policy must be a data frame with columns {.field {need}}.",
        "i" = "Build one with {.fn gk_signal_policy}."
      ),
      class = "config", call = call
    )
  }
  policy <- as.data.frame(policy, stringsAsFactors = FALSE)[, need]
  policy$fallback_compartment <- as.character(policy$fallback_compartment)
  policy$min_value <- as.double(policy$min_value)
  bad_marker <- is.na(policy$marker) | !nzchar(policy$marker) |
    grepl(":", policy$marker, fixed = TRUE) | policy$marker != trimws(policy$marker)
  if (any(bad_marker)) {
    .gk_abort(
      c(
        "Signal policy marker names must be non-empty, trimmed and free of {.val :}.",
        "x" = "Offending: {.val {policy$marker[bad_marker]}}."
      ),
      class = "config", call = call
    )
  }
  if (anyDuplicated(policy$marker)) {
    .gk_abort(
      "Signal policy lists marker {.val {policy$marker[duplicated(policy$marker)]}} more than once.",
      class = "config", call = call
    )
  }
  bad_comp <- !policy$compartment %in% .gk_compartments
  bad_fb <- !is.na(policy$fallback_compartment) &
    !policy$fallback_compartment %in% .gk_compartments
  if (any(bad_comp | bad_fb)) {
    .gk_abort(
      c(
        "Signal policy compartments must be one of {.val {(.gk_compartments)}}.",
        "x" = "Offending markers: {.val {policy$marker[bad_comp | bad_fb]}}."
      ),
      class = "config", call = call
    )
  }
  if (anyNA(policy$statistic) || any(!nzchar(policy$statistic))) {
    .gk_abort("Signal policy statistics must be non-empty.", class = "config", call = call)
  }
  same <- !is.na(policy$fallback_compartment) &
    policy$fallback_compartment == policy$compartment
  if (any(same)) {
    .gk_abort(
      "Fallback compartment equals the preferred compartment for {.val {policy$marker[same]}}.",
      class = "config", call = call
    )
  }
  if (anyNA(policy$min_value) || any(!is.finite(policy$min_value))) {
    .gk_abort("Signal policy {.field min_value} must be finite.", class = "config", call = call)
  }
  rownames(policy) <- NULL
  class(policy) <- c("gk_signal_policy", "cs_signal_policy", "data.frame")
  policy
}

#' @export
print.gk_signal_policy <- function(x, ...) {
  cli::cli_text("{.cls gk_signal_policy} for {nrow(x)} marker{?s}")
  df <- x
  class(df) <- "data.frame"
  print(df, row.names = FALSE)
  invisible(x)
}

#' Build a cell table in the cellspec 1.0 format
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Assembles a `cellspec` object from a cell table and a measurement matrix.
#' This is an interim constructor that follows the cellspec 1.0 specification;
#' once cellspecR is released, its readers produce the same object from tool
#' exports.
#'
#' @param cells Data frame with one row per cell and at least the columns
#'   `cell_id`, `image_id`, `x` and `y` (centroids in um). `sample_id` defaults
#'   to `image_id`. Identifiers are coerced to character.
#' @param measurements Numeric matrix, cells x features, rows in the order of
#'   `cells`. Column names are feature IDs of the form
#'   `"<compartment>:<marker>:<statistic>"`, e.g. `"nucleus:FOXP3:mean"`.
#' @param dictionary Optional feature dictionary (columns `feature_id`,
#'   `kind`, `marker`, `compartment`, `statistic`, `unit`, `source_name`).
#'   Derived from the column names of `measurements` when `NULL`.
#' @param images Optional image table (`image_id`, `sample_id`,
#'   `pixel_size`). Derived from `cells` when `NULL`.
#' @param channels Optional channel table (`image_id`, `channel_index`,
#'   `channel_name`, `marker`). Derived from the dictionary when `NULL`.
#' @param provenance Optional list describing the origin of the data.
#'
#' @return An object of class `cellspec`: a list with `spec_version`,
#'   `cells`, `measurements`, `dictionary`, `images`, `channels`,
#'   `provenance` and `adjacency` (`NULL`).
#'
#' @examples
#' cells <- data.frame(
#'   cell_id = c("c1", "c2", "c3"), image_id = "img1",
#'   x = c(10, 20, 30), y = c(5, 5, 5)
#' )
#' m <- cbind("cell:CD3e:mean" = c(1, 50, 3), "nucleus:FOXP3:mean" = c(0, 12, 1))
#' x <- gk_cellspec(cells, m)
#' x
#'
#' @family cell tables
#' @export
gk_cellspec <- function(cells, measurements, dictionary = NULL, images = NULL,
                        channels = NULL, provenance = NULL) {
  if (!is.data.frame(cells)) {
    .gk_abort("{.arg cells} must be a data frame.", class = "structure")
  }
  cells <- as.data.frame(cells, stringsAsFactors = FALSE)
  need <- c("cell_id", "image_id", "x", "y")
  miss <- setdiff(need, names(cells))
  if (length(miss) > 0L) {
    .gk_abort(
      "{.arg cells} lacks required column{?s} {.field {miss}}.",
      class = "structure"
    )
  }
  if (!"sample_id" %in% names(cells)) {
    cells$sample_id <- cells$image_id
  }
  for (nm in c("cell_id", "image_id", "sample_id")) {
    cells[[nm]] <- as.character(cells[[nm]])
  }
  cells$x <- as.double(cells$x)
  cells$y <- as.double(cells$y)
  if (!is.matrix(measurements) || !is.numeric(measurements)) {
    .gk_abort("{.arg measurements} must be a numeric matrix.", class = "structure")
  }
  storage.mode(measurements) <- "double"
  if (is.null(dictionary)) {
    dictionary <- .gk_dictionary_from_ids(colnames(measurements))
  }
  if (is.null(images)) {
    first <- !duplicated(cells$image_id)
    images <- data.frame(
      image_id = cells$image_id[first],
      sample_id = cells$sample_id[first],
      pixel_size = NA_real_,
      stringsAsFactors = FALSE
    )
  }
  if (is.null(channels)) {
    markers <- unique(dictionary$marker[dictionary$kind == "intensity"])
    channels <- do.call(rbind, lapply(images$image_id, function(img) {
      data.frame(
        image_id = rep(img, length(markers)),
        channel_index = seq_along(markers),
        channel_name = markers,
        marker = markers,
        stringsAsFactors = FALSE
      )
    }))
  }
  if (is.null(provenance)) {
    provenance <- list(
      producer = list(tool = "gatekeepR::gk_cellspec", version = .gk_package_version()),
      created_utc = .gk_utc_now()
    )
  }
  x <- structure(
    list(
      spec_version = .gk_cellspec_version,
      cells = cells,
      measurements = measurements,
      dictionary = as.data.frame(dictionary, stringsAsFactors = FALSE),
      images = as.data.frame(images, stringsAsFactors = FALSE),
      channels = as.data.frame(channels, stringsAsFactors = FALSE),
      provenance = provenance,
      adjacency = NULL
    ),
    class = "cellspec"
  )
  .gk_validate_cellspec(x)
}

.gk_dictionary_from_ids <- function(ids, call = rlang::caller_env()) {
  if (is.null(ids) || anyNA(ids) || any(!nzchar(ids))) {
    .gk_abort(
      "{.arg measurements} needs feature IDs as column names.",
      class = "structure", call = call
    )
  }
  parts <- strsplit(ids, ":", fixed = TRUE)
  n_parts <- lengths(parts)
  if (any(n_parts != 3L)) {
    .gk_abort(
      c(
        "Cannot derive a dictionary from feature IDs {.val {ids[n_parts != 3L]}}.",
        "i" = "Use {.val <compartment>:<marker>:<statistic>} or supply {.arg dictionary}."
      ),
      class = "structure", call = call
    )
  }
  data.frame(
    feature_id = ids,
    kind = "intensity",
    marker = vapply(parts, `[[`, character(1), 2L),
    compartment = vapply(parts, `[[`, character(1), 1L),
    statistic = vapply(parts, `[[`, character(1), 3L),
    unit = "a.u.",
    source_name = ids,
    stringsAsFactors = FALSE
  )
}

.gk_validate_cellspec <- function(x, arg = rlang::caller_arg(x),
                                  call = rlang::caller_env()) {
  fail <- function(msg) {
    .gk_abort(c("{.arg {arg}} is not a valid cellspec object.", "x" = msg),
      class = "structure", call = call
    )
  }
  if (!inherits(x, "cellspec") || !is.list(x)) {
    .gk_abort(
      c(
        "{.arg {arg}} must be a {.cls cellspec} object.",
        "x" = "Got {.obj_type_friendly {x}}.",
        "i" = "Build one with {.fn gk_cellspec} or read one with {.fn gk_read_cellspec}."
      ),
      class = "input", call = call
    )
  }
  req <- c("spec_version", "cells", "measurements", "dictionary", "images", "channels")
  if (!all(req %in% names(x))) {
    fail(paste("missing element(s):", paste(setdiff(req, names(x)), collapse = ", ")))
  }
  major <- sub("\\..*$", "", as.character(x$spec_version))
  if (!identical(major, "1")) {
    fail(paste0("unsupported spec_version ", x$spec_version, "."))
  }
  cells <- x$cells
  if (!all(c("cell_id", "image_id", "sample_id", "x", "y") %in% names(cells))) {
    fail("cells must have cell_id, image_id, sample_id, x and y.")
  }
  if (!is.character(cells$cell_id) || !is.character(cells$image_id) ||
    anyNA(cells$cell_id) || anyNA(cells$image_id)) {
    fail("cell_id and image_id must be character without missing values.")
  }
  if (anyDuplicated(data.frame(cells$image_id, cells$cell_id))) {
    fail("(image_id, cell_id) must be unique.")
  }
  if (!is.numeric(cells$x) || !is.numeric(cells$y) ||
    any(!is.finite(cells$x)) || any(!is.finite(cells$y))) {
    fail("x and y must be finite numbers.")
  }
  m <- x$measurements
  if (!is.matrix(m) || !is.numeric(m) || nrow(m) != nrow(cells)) {
    fail("measurements must be a numeric matrix with one row per cell.")
  }
  d <- x$dictionary
  dneed <- c("feature_id", "kind", "marker", "compartment", "statistic")
  if (!all(dneed %in% names(d))) {
    fail("dictionary lacks feature_id, kind, marker, compartment or statistic.")
  }
  if (!identical(as.character(colnames(m)), as.character(d$feature_id))) {
    fail("measurement column names must equal dictionary feature_id, in order.")
  }
  intensity <- d$kind == "intensity"
  key <- paste(d$kind, d$marker, d$compartment, d$statistic, sep = "\r")
  if (anyDuplicated(key[intensity])) {
    fail("duplicate (kind, marker, compartment, statistic) in the dictionary.")
  }
  if (any(grepl(":", d$marker[intensity], fixed = TRUE))) {
    fail("marker names must not contain ':'.")
  }
  if (!all(unique(cells$image_id) %in% x$images$image_id)) {
    fail("every image_id in cells must appear in images.")
  }
  invisible(x)
}

#' @export
print.cellspec <- function(x, ...) {
  n_img <- length(unique(x$cells$image_id))
  markers <- unique(x$dictionary$marker[x$dictionary$kind == "intensity"])
  cli::cli_text(
    "{.cls cellspec} {x$spec_version}: {format(nrow(x$cells), big.mark = ',')} {cli::qty(nrow(x$cells))}cell{?s}, ",
    "{n_img} image{?s}, {length(markers)} marker{?s}, ",
    "{ncol(x$measurements)} feature{?s}"
  )
  if (length(markers) > 0L) {
    cli::cli_text("Markers: {.val {markers}}")
  }
  invisible(x)
}

# Select one value per cell and marker according to the policy (spec
# section 10). Returns the signal matrix, an integer source code matrix
# (1 preferred, 2 fallback, 0 unavailable) and the feature labels used.
# Features are looked up through dictionary columns, never by pasting names.
.gk_signal_matrix <- function(x, policy, rows = NULL, call = rlang::caller_env()) {
  d <- x$dictionary
  rows <- rows %||% seq_len(nrow(x$cells))
  n <- length(rows)
  k <- nrow(policy)
  signal <- matrix(NA_real_, n, k, dimnames = list(NULL, policy$marker))
  source <- matrix(0L, n, k, dimnames = list(NULL, policy$marker))
  labels <- data.frame(
    marker = policy$marker,
    preferred = paste(policy$compartment, policy$statistic, sep = ":"),
    fallback = ifelse(is.na(policy$fallback_compartment), NA_character_,
      paste("fallback", policy$fallback_compartment, policy$statistic, sep = ":")
    ),
    stringsAsFactors = FALSE
  )
  for (j in seq_len(k)) {
    col <- .gk_find_feature(d, policy$marker[[j]], policy$compartment[[j]],
      policy$statistic[[j]],
      call = call
    )
    a <- x$measurements[rows, col]
    ok <- is.finite(a) & a >= policy$min_value[[j]]
    signal[ok, j] <- a[ok]
    source[ok, j] <- 1L
    fb <- policy$fallback_compartment[[j]]
    if (!is.na(fb)) {
      col_fb <- .gk_find_feature(d, policy$marker[[j]], fb, policy$statistic[[j]], call = call)
      b <- x$measurements[rows, col_fb]
      use <- !ok & is.finite(b) & b >= policy$min_value[[j]]
      signal[use, j] <- b[use]
      source[use, j] <- 2L
    }
  }
  list(signal = signal, source = source, labels = labels)
}

.gk_find_feature <- function(dictionary, marker, compartment, statistic,
                             call = rlang::caller_env()) {
  hit <- which(dictionary$kind == "intensity" & dictionary$marker == marker &
    dictionary$compartment == compartment & dictionary$statistic == statistic)
  if (length(hit) != 1L) {
    .gk_abort(
      c(
        "The cell table has no {.val {statistic}} measurement of {.val {marker}} in the {.val {compartment}} compartment.",
        "i" = "Check the signal policy and localisation rules against {.code x$dictionary}."
      ),
      class = "structure", call = call
    )
  }
  hit
}

#' Read and write cellspec directories
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' `gk_write_cellspec()` writes a `cellspec` object to a selected directory
#' layout. The legacy layout uses `cells.tsv.gz` (cell columns then
#' measurement columns), `cellspec.json` (spec version, images, channels,
#' dictionary, provenance), `MANIFEST.sha256` and `DONE`. The directory is
#' staged and renamed atomically. `gk_read_cellspec()` reads it back and, with
#' `verify = TRUE`, refuses a directory whose manifest does not match.
#'
#' The default `format = "legacy"` retains the original gatekeepR layout for
#' compatibility. It is not the canonical cellspecR disk schema and is planned
#' for retirement after migration is qualified. It does not serialize adjacency
#' or typed sidecar metadata. Select `"parquet"` or
#' `"tsv.gz"` explicitly for canonical storage owned by cellspecR. These formats
#' require cellspecR and a valid canonical object, including declared positive
#' pixel calibration; missing calibration is never guessed. Canonical storage
#' preserves adjacency, typed metadata and additional columns.
#'
#' Reading dispatches by the declared sidecar schema. Malformed or unsupported
#' canonical data never fall back to the legacy reader. Canonical validation
#' failures retain their `cellspec_error` condition classes.
#'
#' @param x A `cellspec` object.
#' @param dir Directory path.
#' @param overwrite Replace an existing directory?
#' @param verify Check `DONE` and every manifest hash before reading?
#' @param format Output layout: `"legacy"` for compatibility, or canonical
#'   `"parquet"` or `"tsv.gz"` through cellspecR.
#'
#' @return `gk_write_cellspec()` returns `x` invisibly. `gk_read_cellspec()`
#'   returns a `cellspec` object whose `provenance$manifest_sha256` holds the
#'   SHA-256 of `MANIFEST.sha256`.
#'
#' @examples
#' x <- gk_read_cellspec(gk_example_path("example-slide"))
#' x
#' out <- file.path(tempdir(), "copy-of-example")
#' gk_write_cellspec(x, out, overwrite = TRUE)
#' unlink(out, recursive = TRUE)
#'
#' @family cell tables
#' @export
gk_write_cellspec <- function(x, dir, overwrite = FALSE,
                             format = c("legacy", "parquet", "tsv.gz")) {
  .gk_validate_cellspec(x)
  .gk_check_string(dir)
  .gk_check_flag(overwrite)
  format <- match.arg(format)
  if (format != "legacy") {
    .gk_require("cellspecR", "Canonical cellspec writing")
    cellspecR::cs_assert_valid(x)
    cellspecR::cs_write(x, dir, format = format, overwrite = overwrite)
    return(invisible(x))
  }
  stage <- .gk_stage_dir(dir, overwrite = overwrite)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  table <- cbind(x$cells, as.data.frame(x$measurements, check.names = FALSE))
  .gk_write_tsv(table, file.path(stage, "cells.tsv.gz"))
  meta <- list(
    spec_version = x$spec_version,
    images = x$images,
    channels = x$channels,
    dictionary = x$dictionary,
    cell_columns = I(names(x$cells)),
    provenance = .gk_json_ready(x$provenance)
  )
  .gk_write_json(meta, file.path(stage, "cellspec.json"))
  .gk_write_manifest(stage, c("cells.tsv.gz", "cellspec.json"))
  .gk_publish_dir(stage, dir, overwrite = overwrite)
  invisible(x)
}

#' @rdname gk_write_cellspec
#' @export
gk_read_cellspec <- function(dir, verify = TRUE) {
  .gk_check_dir_exists(dir)
  .gk_check_flag(verify)
  if (verify) {
    .gk_verify_manifest(dir, class = "structure")
  }
  meta <- .gk_read_json(file.path(dir, "cellspec.json"), tolerate_trailing = !verify)
  major <- sub("\\..*$", "", as.character(meta$spec_version %||% ""))
  if (!identical(major, "1")) {
    .gk_abort(
      "Unsupported cellspec version {.val {meta$spec_version}} in {.path {dir}}.",
      class = "structure"
    )
  }
  canonical <- !is.null(meta$files) || !is.null(meta$cells) ||
    all(c("columns", "rows") %in% names(meta$dictionary))
  if (canonical) {
    if (!is.list(meta$files) || !is.character(meta$files$cells) ||
        length(meta$files$cells) != 1L ||
        !meta$files$cells %in% c("cells.parquet", "cells.tsv.gz") ||
        !is.null(meta$cell_columns)) {
      .gk_abort("Unsupported or ambiguous canonical cellspec sidecar schema.",
                 class = "structure")
    }
    .gk_require("cellspecR", "Canonical cellspec reading")
    x <- cellspecR::cs_read_cellspec(dir, verify = verify)
    x$provenance$manifest_sha256 <- .gk_sha256_file(file.path(dir, "MANIFEST.sha256"))
    return(.gk_validate_cellspec(x))
  }
  if (is.null(meta$cell_columns)) {
    .gk_abort("The legacy cellspec sidecar must declare cell_columns.",
               class = "structure")
  }
  dictionary <- .gk_rows_to_df(meta$dictionary)
  dictionary <- dictionary[, intersect(
    c("feature_id", "kind", "marker", "compartment", "statistic", "unit", "source_name"),
    names(dictionary)
  ), drop = FALSE]
  images <- .gk_rows_to_df(meta$images)
  channels <- .gk_rows_to_df(meta$channels)
  cell_cols <- unlist(meta$cell_columns)
  types <- c(x = "double", y = "double", area = "double")
  feat_types <- stats::setNames(rep("double", nrow(dictionary)), dictionary$feature_id)
  table <- .gk_read_tsv(file.path(dir, "cells.tsv.gz"), types = c(types, feat_types))
  cells <- table[, cell_cols, drop = FALSE]
  m <- as.matrix(table[, dictionary$feature_id, drop = FALSE])
  storage.mode(m) <- "double"
  dimnames(m) <- list(NULL, dictionary$feature_id)
  provenance <- meta$provenance %||% list()
  provenance$manifest_sha256 <- .gk_sha256_file(file.path(dir, "MANIFEST.sha256"))
  x <- structure(
    list(
      spec_version = meta$spec_version,
      cells = cells,
      measurements = m,
      dictionary = dictionary,
      images = images,
      channels = channels,
      provenance = provenance,
      adjacency = NULL
    ),
    class = "cellspec"
  )
  .gk_validate_cellspec(x)
}

# Convert a JSON array of row objects back to a data frame.
.gk_rows_to_df <- function(rows) {
  if (length(rows) == 0L) {
    return(data.frame())
  }
  cols <- unique(unlist(lapply(rows, names)))
  out <- lapply(cols, function(nm) {
    vals <- lapply(rows, function(r) r[[nm]])
    nulls <- vapply(vals, is.null, logical(1))
    vals[nulls] <- NA
    unlist(vals)
  })
  names(out) <- cols
  as.data.frame(out, stringsAsFactors = FALSE)
}

# Make arbitrary nested lists JSON-writable (drop attributes, keep names).
.gk_json_ready <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  if (is.data.frame(x)) {
    return(x)
  }
  if (is.list(x)) {
    out <- lapply(x, .gk_json_ready)
    names(out) <- names(x)
    return(out)
  }
  if (is.atomic(x) && length(x) != 1L) {
    return(I(as.vector(x)))
  }
  as.vector(x)
}
