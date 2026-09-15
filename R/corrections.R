# Signal corrections. Corrections are fitted only to markers that passed the
# raw support checks; an absent marker must remain NA after every method.

.gk_correction_methods <- c(
  "none", "robust_z", "common_score_residual", "pc1_panel_residual"
)

.gk_correction_callable <- function(prepared, markers) {
  cb <- prepared$callability
  status <- vapply(markers, function(mk) {
    rows <- cb$status[cb$marker == mk]
    length(rows) > 0L && !any(grepl("^NOT_CALLABLE", rows))
  }, logical(1))
  status
}

.gk_correction_stats <- function(x) {
  med <- vapply(seq_len(ncol(x)), function(j) {
    stats::median(x[, j], na.rm = TRUE)
  }, numeric(1))
  mad <- vapply(seq_len(ncol(x)), function(j) {
    stats::mad(x[, j], constant = 1.4826, na.rm = TRUE)
  }, numeric(1))
  fallback <- !is.finite(mad) | mad <= 0
  mad[fallback] <- 1
  list(median = med, mad = mad, mad_fallback = fallback)
}

.gk_canonicalize_pca <- function(p) {
  if (ncol(p$rotation) == 0L) {
    return(p)
  }
  for (j in seq_len(ncol(p$rotation))) {
    i <- which.max(abs(p$rotation[, j]))
    if (is.finite(p$rotation[i, j]) && p$rotation[i, j] < 0) {
      p$rotation[, j] <- -p$rotation[, j]
      p$x[, j] <- -p$x[, j]
    }
  }
  p
}

.gk_apply_robust_z <- function(x, center, scale) {
  out <- sweep(sweep(x, 2L, center, "-"), 2L, scale, "/")
  out <- pmin(pmax(out, -5), 5)
  dimnames(out) <- dimnames(x)
  out
}

.gk_fit_common_score <- function(x, row_center) {
  robust <- .gk_correction_stats(x)
  z <- .gk_apply_robust_z(x, robust$median, robust$mad)
  common <- rowMeans(z, na.rm = TRUE)
  design <- cbind(intercept = 1, robust_identity_common = common)
  fit <- stats::lm.fit(design, z)
  resid <- fit$residuals
  if (isTRUE(row_center)) {
    resid <- sweep(resid, 1L, rowMeans(resid, na.rm = TRUE), "-")
  }
  center <- colMeans(resid, na.rm = TRUE)
  scale <- vapply(seq_len(ncol(resid)), function(j) {
    stats::sd(resid[, j], na.rm = TRUE)
  }, numeric(1))
  scale[!is.finite(scale) | scale <= 0] <- 1
  matrix <- sweep(sweep(resid, 2L, center, "-"), 2L, scale, "/")
  dimnames(matrix) <- dimnames(x)
  list(
    matrix = matrix, robust_z = z, common_score = common,
    coefficients = unname(fit$coefficients), center = center, scale = scale,
    median = robust$median, mad = robust$mad,
    mad_fallback = robust$mad_fallback, row_center = isTRUE(row_center)
  )
}

.gk_fit_pc1_panel <- function(x, identity_markers, row_center) {
  robust <- .gk_correction_stats(x)
  z <- .gk_apply_robust_z(x, robust$median, robust$mad)
  zid <- z[, identity_markers, drop = FALSE]
  if (ncol(zid) == 1L) {
    rotation <- matrix(1, nrow = 1L, ncol = 1L,
      dimnames = list(identity_markers, "PC1")
    )
    pc1_center <- mean(zid[, 1L])
    pc1 <- zid[, 1L] - pc1_center
    pc1[!is.finite(pc1)] <- 0
  } else {
    p <- stats::prcomp(zid, center = TRUE, scale. = FALSE,
      rank. = min(ncol(zid), nrow(zid) - 1L)
    )
    p <- .gk_canonicalize_pca(p)
    pc1 <- p$x[, 1L]
    rotation <- p$rotation[, 1L, drop = FALSE]
    pc1_center <- p$center
  }
  design <- cbind(intercept = 1, identity_pc1 = pc1)
  resid <- matrix(NA_real_, nrow(x), ncol(x), dimnames = dimnames(x))
  coefficients <- vector("list", ncol(x))
  names(coefficients) <- colnames(x)
  for (j in seq_len(ncol(x))) {
    ok <- is.finite(z[, j]) & is.finite(pc1)
    if (sum(ok) < 2L) {
      next
    }
    fit <- stats::lm.fit(design[ok, , drop = FALSE], z[ok, j])
    resid[ok, j] <- fit$residuals
    coefficients[[j]] <- unname(fit$coefficients)
  }
  second_common <- rowMeans(resid[, identity_markers, drop = FALSE], na.rm = TRUE)
  if (isTRUE(row_center)) {
    for (j in seq_len(ncol(resid))) {
      ok <- is.finite(resid[, j]) & is.finite(second_common)
      resid[ok, j] <- resid[ok, j] - second_common[ok]
    }
  }
  center <- vapply(seq_len(ncol(resid)), function(j) {
    mean(resid[, j], na.rm = TRUE)
  }, numeric(1))
  scale <- vapply(seq_len(ncol(resid)), function(j) {
    stats::sd(resid[, j], na.rm = TRUE)
  }, numeric(1))
  center[!is.finite(center)] <- 0
  scale[!is.finite(scale) | scale <= 0] <- 1
  matrix <- sweep(sweep(resid, 2L, center, "-"), 2L, scale, "/")
  dimnames(matrix) <- dimnames(x)
  list(
    matrix = matrix, robust_z = z, pc1 = pc1,
    pc1_center = pc1_center, pc1_rotation = rotation, coefficients = coefficients,
    center = center, scale = scale, median = robust$median,
    mad = robust$mad, mad_fallback = robust$mad_fallback,
    identity_markers = identity_markers, row_center = isTRUE(row_center)
  )
}

.gk_correction_model <- function(method, input_markers, callable_markers,
                                  noncallable_markers, row_center, fit) {
  structure(
    c(
      list(
        method = method, input_markers = input_markers,
        callable_markers = callable_markers,
        noncallable_markers = noncallable_markers,
        row_center = isTRUE(row_center)
      ),
      fit
    ),
    class = "gk_correction_model"
  )
}

.gk_correction_result <- function(prepared, matrix, model) {
  structure(
    list(
      matrix = matrix, model = model,
      config_sha256 = prepared$config_sha256,
      source_sha256 = prepared$source_sha256
    ),
    class = "gk_corrected"
  )
}

#' Correct prepared marker scores
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Applies a deterministic correction to transformed marker scores. Markers
#' that fail the raw support checks are excluded from fitting and are `NA` in
#' the corrected matrix, so correction cannot create signal in an absent
#' channel. The fitted parameters are returned in a
#' `gk_correction_model` and can be applied again to the same prepared data.
#'
#' @param prepared A [gk_prepare()] result.
#' @param method One of `"none"`, `"robust_z"`, `"common_score_residual"`
#'   or `"pc1_panel_residual"`.
#' @param markers Character vector of markers to correct. `NULL` selects
#'   identity and conditional identity markers.
#' @param row_center Whether to subtract each cell's residual mean. This
#'   changes the meaning of per-cell values and is `FALSE` by default.
#'
#' @return A `gk_corrected` list with `matrix`, `model`, `config_sha256` and
#'   `source_sha256`. The model has class `gk_correction_model` and stores all
#'   fitted centres, scales, rotations and coefficients.
#'
#' @examples
#' prep <- gk_prepare(gk_example_path("example-slide"), gk_example_config(), quiet = TRUE)
#' corrected <- gk_correct(prep, method = "robust_z")
#' corrected$model
#'
#' @family corrections
#' @export
gk_correct <- function(prepared,
                       method = c("none", "robust_z", "common_score_residual",
                                   "pc1_panel_residual"),
                       markers = NULL, row_center = FALSE) {
  .gk_check_class(prepared, "gk_prepared")
  .gk_check_flag(row_center)
  pm <- prepared$config$panel$markers
  default <- pm$marker[pm$role %in% .gk_gating_roles]
  if (inherits(method, "gk_correction_model")) {
    if (!is.null(markers)) {
      .gk_check_character(markers, min_length = 1L, unique = TRUE)
    }
    return(.gk_reapply_correction(prepared, method, markers = markers))
  }
  method <- rlang::arg_match(method, .gk_correction_methods)
  markers <- markers %||% default
  .gk_check_character(markers, min_length = 1L, unique = TRUE)
  unknown <- setdiff(markers, colnames(prepared$score))
  if (length(unknown) > 0L) {
    .gk_abort("Unknown marker{?s} {.val {unknown}} in {.arg markers}.", class = "input")
  }
  callable <- .gk_correction_callable(prepared, markers)
  fit_markers <- markers[callable]
  bad_markers <- markers[!callable]
  out <- prepared$score
  if (length(bad_markers) > 0L) {
    out[, bad_markers] <- NA_real_
  }
  if (length(fit_markers) == 0L) {
    fit <- list()
  } else {
    x <- prepared$score[, fit_markers, drop = FALSE]
    if (any(!is.finite(x))) {
      for (j in seq_len(ncol(x))) {
        x[!is.finite(x[, j]), j] <- stats::median(x[, j], na.rm = TRUE)
      }
    }
    fit <- switch(method,
      none = list(matrix = x),
      robust_z = {
        s <- .gk_correction_stats(x)
        list(
          matrix = .gk_apply_robust_z(x, s$median, s$mad),
          median = s$median, mad = s$mad, mad_fallback = s$mad_fallback
        )
      },
      common_score_residual = .gk_fit_common_score(x, row_center),
      pc1_panel_residual = {
        identity <- intersect(
          pm$marker[pm$role %in% .gk_gating_roles], fit_markers
        )
        if (length(identity) == 0L) identity <- fit_markers
        .gk_fit_pc1_panel(x, identity, row_center)
      }
    )
    out[, fit_markers] <- fit$matrix
  }
  model <- .gk_correction_model(
    method, markers, fit_markers, bad_markers, row_center, fit
  )
  model$config_sha256 <- prepared$config_sha256
  model$source_sha256 <- prepared$source_sha256
  .gk_correction_result(prepared, out, model)
}

.gk_reapply_correction <- function(prepared, model, markers = NULL) {
  .gk_check_class(model, "gk_correction_model", arg = "method")
  if (!identical(model$source_sha256, prepared$source_sha256) ||
    !identical(model$config_sha256, prepared$config_sha256)) {
    .gk_abort(
      c(
        "The correction model was fitted to different prepared data.",
        "i" = "Fit a new model or provide the original {.cls gk_prepared} object."
      ),
      class = "state"
    )
  }
  selected <- markers %||% model$input_markers
  .gk_check_character(selected, min_length = 1L, unique = TRUE)
  if (!all(selected %in% model$input_markers)) {
    .gk_abort("The stored correction model does not contain {.arg markers}.", class = "input")
  }
  out <- prepared$score
  if (length(model$noncallable_markers) > 0L) {
    out[, model$noncallable_markers] <- NA_real_
  }
  fit_markers <- model$callable_markers
  if (length(fit_markers) > 0L) {
    x <- prepared$score[, fit_markers, drop = FALSE]
    if (!is.matrix(model$matrix) || !identical(colnames(model$matrix), fit_markers) ||
      nrow(model$matrix) != nrow(x) || any(!is.finite(model$matrix))) {
      .gk_abort("The stored correction model has invalid fitted values.", class = "state")
    }
    out[, fit_markers] <- model$matrix
  }
  .gk_correction_result(prepared, out, model)
}

#' @export
print.gk_correction_model <- function(x, ...) {
  cli::cli_text(
    "{.cls gk_correction_model}: {.val {x$method}} for ",
    "{length(x$input_markers)} marker{?s}"
  )
  cli::cli_bullets(c(
    "*" = "Fitted markers: {.val {x$callable_markers}}",
    "*" = "Excluded markers: {.val {x$noncallable_markers}}",
    "*" = "Row centring: {.val {x$row_center}}"
  ))
  invisible(x)
}
