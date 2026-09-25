# Frozen numerical residual spaces. Raw selection and biological decisions are
# caller policies; applying a model never estimates new parameters.

.gk_residual_scores <- function(scores, identity_markers = NULL) {
  if (!is.matrix(scores) || !is.numeric(scores) || is.null(colnames(scores)) ||
      anyNA(colnames(scores)) || any(!nzchar(colnames(scores))) ||
      anyDuplicated(colnames(scores)) || any(is.infinite(scores)) || any(is.nan(scores))) {
    .gk_abort("Scores must be a numeric matrix with unique named columns and finite values or NA.",
               class = "input")
  }
  if (!is.null(identity_markers) &&
      (!all(identity_markers %in% colnames(scores)) ||
       any(!is.finite(scores[, identity_markers, drop = FALSE])))) {
    .gk_abort("Every identity projection input must be present and finite; no imputation is allowed.",
               class = "input")
  }
  invisible(scores)
}

# Encode shape, types and names explicitly before canonical JSON hashing.
# Unlike flat numeric JSON, this detects swapped dimnames and matrix shapes.
.gk_residual_hash_payload <- function(x) {
  if (is.null(x)) return(NULL)
  if (is.data.frame(x)) {
    return(list(type = "data.frame", class = class(x), nrow = nrow(x), row_names = rownames(x), columns = names(x),
                data = lapply(x, .gk_residual_hash_payload)))
  }
  if (is.list(x)) {
    return(list(type = "list", class = class(x), names = names(x),
                data = unname(lapply(x, .gk_residual_hash_payload))))
  }
  if ((!is.object(x) || inherits(x, "AsIs")) &&
      (is.numeric(x) || is.logical(x) || is.character(x))) {
    if (is.numeric(x) && (any(is.infinite(x)) || any(is.nan(x)))) {
      .gk_abort("Model metadata may contain NA but not NaN or infinity.", class = "input")
    }
    return(list(type = typeof(x), class = class(x), names = names(x), dim = dim(x),
                dimnames = dimnames(x), values = unname(as.vector(x))))
  }
  .gk_abort("Model bindings must contain lists, data frames or plain/AsIs numeric, logical and character values.",
             class = "input")
}

.gk_residual_hash <- function(x) {
  .gk_sha256_object(.gk_residual_hash_payload(x))
}

.gk_residual_robust <- function(scores) {
  center <- apply(scores, 2L, stats::median, na.rm = TRUE)
  scale <- apply(scores, 2L, stats::mad, constant = 1.4826, na.rm = TRUE)
  fallback <- !is.finite(scale) | scale <= 0
  scale[fallback] <- 1
  list(center = center, scale = scale, fallback = fallback, clip = c(-5, 5))
}

.gk_residual_standardize <- function(scores, fit) {
  out <- sweep(sweep(scores, 2L, fit$center, "-"), 2L, fit$scale, "/")
  out <- pmin(pmax(out, fit$clip[[1L]]), fit$clip[[2L]])
  dimnames(out) <- dimnames(scores)
  out
}

.gk_residual_regression <- function(design, response) {
  fit <- stats::lm.fit(design, response)
  if (fit$rank != ncol(design) || any(!is.finite(fit$coefficients))) {
    .gk_abort("Residual fitting requires a full-rank finite regression design.", class = "state")
  }
  if (is.matrix(response)) {
    fit$residuals <- matrix(fit$residuals, nrow(response), ncol(response),
                            dimnames = dimnames(response))
    fit$coefficients <- matrix(fit$coefficients, ncol(design), ncol(response),
                               dimnames = list(colnames(design), colnames(response)))
  }
  fit
}

#' Freeze and apply a fitted residual score space
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Fits two numerical spaces from already transformed marker scores: an
#' identity common-score residual and a panel residual against the first
#' identity principal component. Robust centring uses medians and MAD with
#' constant 1.4826, with nonpositive MAD replaced by 1; standardized inputs
#' are clipped to `[-5, 5]`. Identity residuals are row-centred, then centred
#' and scaled per marker. Panel residuals subtract the row mean of identity
#' residuals before final per-marker centring and scaling. The first principal
#' component has a deterministic sign (largest absolute loading positive).
#'
#' At least 20 training rows are required. Panel regressions require 20 finite
#' observations per marker; insufficient optional markers remain unavailable.
#' Final nonpositive or nonfinite standard deviations use 1. Missing identity
#' inputs and rank-deficient regression fits fail; they are never imputed.
#'
#' Application uses only stored parameters, so deleting, reordering or changing
#' another row cannot refit the scores of an unchanged row. The exact ordered
#' marker dictionary is required. Optional marker NA values remain NA.
#' The model contains no fitted per-cell matrix and can be saved with [base::saveRDS()].
#' Its content hash binds parameters, dimensions, names, provenance and bindings.
#'
#' This is a numerical fit/apply contract, not raw-channel callability, gate
#' estimation or biological validation. The caller owns raw measurement
#' selection, any asinh cofactor, image-specific training scope and downstream
#' decisions. Constant raw channels may retain historical residual artifacts;
#' downstream callers must enforce raw support independently. Reusing a fitted
#' model on a different image or cohort requires separate scientific qualification.
#'
#' @param scores Numeric matrix of already transformed scores with unique,
#'   ordered marker column names. Identity columns must be finite. Other columns
#'   may contain NA, but neither NaN nor infinity is accepted.
#' @param identity_markers Unique ordered identity-marker names in `scores`.
#' @param provenance Named list recording the caller's training source,
#'   transformation and fit scope. Stored without interpretation.
#' @param bindings Named list of immutable configuration or threshold records
#'   to bind to this score space. No gate interpretation or transfer is performed.
#' @param model A `gk_frozen_residual_model` from `gk_fit_residual_model()`.
#'
#' @return Fit returns a `gk_frozen_residual_model` with schema version,
#'   parameters, source-score SHA-256, provenance, bindings and model SHA-256.
#'   Apply returns a list with `identity` and `gate` matrices and `model_sha256`.
#' @family corrections
#' @export
#' @examples
#' scores <- cbind(A = seq_len(40), B = sin(seq_len(40)), C = cos(seq_len(40)))
#' model <- gk_fit_residual_model(scores, c("A", "B"),
#'   provenance = list(fit_scope = "synthetic input image", transform = "none"))
#' result <- gk_apply_residual_model(scores, model)
#' dim(result$gate)
gk_fit_residual_model <- function(scores, identity_markers,
                                  provenance = list(), bindings = list()) {
  .gk_check_character(identity_markers, min_length = 1L, unique = TRUE)
  .gk_residual_scores(scores, identity_markers)
  if (nrow(scores) < 20L) {
    .gk_abort("Residual fitting requires at least 20 training rows.", class = "input")
  }
  for (value in list(provenance, bindings)) {
    if (!is.list(value) || (length(value) &&
        (is.null(names(value)) || anyNA(names(value)) ||
         any(!nzchar(names(value))) || anyDuplicated(names(value))))) {
      .gk_abort("Provenance and bindings must be named lists.", class = "input")
    }
    .gk_residual_hash_payload(value)
  }
  id_raw <- scores[, identity_markers, drop = FALSE]
  id_robust <- .gk_residual_robust(id_raw)
  iz <- .gk_residual_standardize(id_raw, id_robust)
  id_fit <- .gk_residual_regression(cbind(1, rowMeans(iz)), iz)
  ir <- sweep(id_fit$residuals, 1L, rowMeans(id_fit$residuals), "-")
  id_center <- colMeans(ir)
  id_scale <- apply(ir, 2L, stats::sd)
  id_scale[!is.finite(id_scale) | id_scale <= 0] <- 1

  robust <- .gk_residual_robust(scores)
  z <- .gk_residual_standardize(scores, robust)
  pca <- stats::prcomp(z[, identity_markers, drop = FALSE], center = TRUE,
                       scale. = FALSE, rank. = length(identity_markers))
  pca <- .gk_canonicalize_pca(pca)
  rotation <- pca$rotation[, 1L]
  design <- cbind(1, pca$x[, 1L])
  coefficients <- matrix(NA_real_, 2L, ncol(scores),
    dimnames = list(c("intercept", "identity_pc1"), colnames(scores)))
  residuals <- matrix(NA_real_, nrow(z), ncol(z), dimnames = dimnames(z))
  for (j in seq_len(ncol(z))) {
    ok <- is.finite(z[, j])
    if (sum(ok) < 20L) next
    fit <- .gk_residual_regression(design[ok, , drop = FALSE], z[ok, j])
    coefficients[, j] <- fit$coefficients
    residuals[ok, j] <- fit$residuals
  }
  residuals <- sweep(residuals, 1L,
    rowMeans(residuals[, identity_markers, drop = FALSE]), "-")
  center <- apply(residuals, 2L, mean, na.rm = TRUE)
  center[!is.finite(center)] <- NA_real_
  scale <- apply(residuals, 2L, stats::sd, na.rm = TRUE)
  scale[!is.finite(scale) | scale <= 0] <- 1
  model <- list(
    schema = "gk_frozen_residual_1.0.0", panel = colnames(scores),
    identity_markers = identity_markers, identity_robust = id_robust,
    identity_regression = id_fit$coefficients, identity_center = id_center,
    identity_scale = id_scale, panel_robust = robust, pc_center = pca$center,
    pc1_rotation = rotation, panel_regression = coefficients,
    panel_center = center, panel_scale = scale, n_training = nrow(scores),
    source_scores_sha256 = .gk_residual_hash(scores),
    provenance = provenance, bindings = bindings
  )
  model$model_sha256 <- .gk_residual_hash(model)
  structure(model, class = "gk_frozen_residual_model")
}

#' @rdname gk_fit_residual_model
#' @export
gk_apply_residual_model <- function(scores, model) {
  .gk_check_class(model, "gk_frozen_residual_model")
  payload <- unclass(model)
  expected <- payload$model_sha256
  payload$model_sha256 <- NULL
  if (!identical(model$schema, "gk_frozen_residual_1.0.0") ||
      !is.character(expected) || length(expected) != 1L ||
      !identical(expected, .gk_residual_hash(payload))) {
    .gk_abort("Frozen residual model content or schema does not match its hash.", class = "state")
  }
  .gk_residual_scores(scores, model$identity_markers)
  if (!identical(colnames(scores), model$panel)) {
    .gk_abort("Frozen residual application requires the exact ordered marker dictionary.", class = "input")
  }
  iz <- .gk_residual_standardize(scores[, model$identity_markers, drop = FALSE],
                                model$identity_robust)
  ir <- iz - cbind(rep(1, nrow(iz)), rowMeans(iz)) %*% model$identity_regression
  ir <- sweep(ir, 1L, rowMeans(ir), "-")
  identity <- sweep(sweep(ir, 2L, model$identity_center, "-"), 2L,
                     model$identity_scale, "/")
  z <- .gk_residual_standardize(scores, model$panel_robust)
  pc1 <- as.vector(sweep(z[, model$identity_markers, drop = FALSE], 2L,
                         model$pc_center, "-") %*% model$pc1_rotation)
  residuals <- z - cbind(rep(1, nrow(z)), pc1) %*% model$panel_regression
  residuals <- sweep(residuals, 1L,
    rowMeans(residuals[, model$identity_markers, drop = FALSE]), "-")
  gate <- sweep(sweep(residuals, 2L, model$panel_center, "-"), 2L,
                 model$panel_scale, "/")
  dimnames(identity) <- dimnames(scores[, model$identity_markers, drop = FALSE])
  dimnames(gate) <- dimnames(scores)
  list(identity = identity, gate = gate, model_sha256 = expected)
}
