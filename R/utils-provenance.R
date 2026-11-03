# Bind analytical objects to their ordered cells and the numerical score space.
# Source hashes alone cannot distinguish a raw threshold from a corrected one.
.gk_cell_keys <- function(cells) {
  out <- cells[, c("image_id", "cell_id"), drop = FALSE]
  rownames(out) <- NULL
  out
}

# Length prefixes keep keys unambiguous even when IDs contain separators.
.gk_cell_key <- function(cells) {
  if (nrow(cells) == 0L) return(character())
  image <- enc2utf8(as.character(cells$image_id))
  cell <- enc2utf8(as.character(cells$cell_id))
  paste0(nchar(image, type = "bytes"), ":", image,
    nchar(cell, type = "bytes"), ":", cell)
}

.gk_score_hash <- function(prepared, score) {
  .gk_sha256_data(.gk_cell_key(prepared$cells),
    rownames(score), score)
}

.gk_check_source <- function(prepared, object, arg) {
  if (!identical(object$source_sha256, prepared$source_sha256) ||
    !identical(object$config_sha256, prepared$config_sha256)) {
    .gk_abort("{.arg {arg}} does not match the prepared source and configuration.", class = "state")
  }
}

.gk_score_matrix <- function(prepared, correction = NULL) {
  if (is.null(correction)) return(prepared$score)
  .gk_check_class(correction, "gk_corrected")
  .gk_check_source(prepared, correction, "correction")
  score <- correction$matrix
  if (!is.matrix(score) || !is.numeric(score) ||
    !identical(dim(score), dim(prepared$score)) ||
    !identical(dimnames(score), dimnames(prepared$score)) ||
    !identical(correction$cell_keys, .gk_cell_keys(prepared$cells)) ||
    !identical(correction$score_sha256, .gk_score_hash(prepared, score))) {
    .gk_abort("The correction has invalid values, marker names or ordered cell keys.", class = "state")
  }
  score
}

.gk_validate_thresholds <- function(prepared, thresholds, correction = NULL) {
  .gk_check_class(thresholds, "gk_thresholds")
  score <- .gk_score_matrix(prepared, correction)
  if (!identical(attr(thresholds, "source_sha256"), prepared$source_sha256) ||
    !identical(attr(thresholds, "config_sha256"), prepared$config_sha256) ||
    !identical(attr(thresholds, "cell_keys"), .gk_cell_keys(prepared$cells)) ||
    !identical(attr(thresholds, "score_sha256"), .gk_score_hash(prepared, score))) {
    .gk_abort("Thresholds do not match the prepared source, ordered cells or score space.", class = "state")
  }
  pm <- prepared$config$panel$markers
  markers <- pm$marker[pm$role %in% .gk_gating_roles]
  expected <- expand.grid(image_id = unique(prepared$cells$image_id),
    marker = markers, stringsAsFactors = FALSE)
  required <- c("image_id", "marker", "parent", "status", "estimate")
  valid <- all(required %in% names(thresholds)) && nrow(thresholds) == nrow(expected)
  if (valid) {
    observed <- thresholds[, c("image_id", "marker"), drop = FALSE]
    valid <- !anyNA(observed) && !anyDuplicated(observed) &&
      all(is.na(thresholds$parent)) &&
      nrow(merge(expected, observed, by = c("image_id", "marker"))) == nrow(expected) &&
      is.numeric(thresholds$estimate) && !anyNA(thresholds$status) &&
      all(thresholds$status %in% .gk_status_levels) &&
      all(is.finite(thresholds$estimate[.gk_is_callable_status(thresholds$status)]))
  }
  if (!isTRUE(valid)) {
    .gk_abort("Thresholds must contain exactly one valid result per image and identity marker.", class = "state")
  }
  invisible(score)
}

.gk_classification_hash <- function(classification) {
  do.call(.gk_sha256_data, c(unname(classification$cells), list(
    names(classification$cells), classification$calls,
    classification$source_sha256, classification$config_sha256,
    classification$score_sha256, classification$thresholds_sha256)))
}

.gk_validate_classification <- function(prepared, classification, thresholds = NULL) {
  .gk_check_class(classification, "gk_classification")
  .gk_check_source(prepared, classification, "classification")
  stored <- classification$thresholds
  score <- .gk_validate_thresholds(prepared, stored, classification$correction)
  pm <- prepared$config$panel$markers
  markers <- pm$marker[pm$role %in% .gk_gating_roles]
  if (!is.data.frame(classification$cells) ||
    !all(c("image_id", "cell_id") %in% names(classification$cells)) ||
    !identical(.gk_cell_keys(classification$cells), .gk_cell_keys(prepared$cells)) ||
    !is.matrix(classification$calls) || !is.logical(classification$calls) ||
    !identical(dimnames(classification$calls), list(prepared$cells$cell_id, markers)) ||
    !identical(classification$score_sha256, .gk_score_hash(prepared, score)) ||
    !identical(classification$thresholds_sha256, .gk_thresholds_hash(stored)) ||
    !identical(classification$classification_sha256, .gk_classification_hash(classification))) {
    .gk_abort("Classification values, thresholds or ordered cell keys are inconsistent.", class = "state")
  }
  if (!is.null(thresholds)) {
    .gk_validate_thresholds(prepared, thresholds, classification$correction)
    if (!identical(.gk_thresholds_hash(thresholds), classification$thresholds_sha256)) {
      .gk_abort("Classification was made with different thresholds.", class = "state")
    }
  }
  invisible(TRUE)
}

.gk_raw_supported <- function(prepared, image_id, marker) {
  cb <- prepared$callability
  status <- cb$status[cb$image_id == image_id & cb$marker == marker]
  length(status) == 1L && !is.na(status) && !grepl("^NOT_CALLABLE", status)
}

.gk_score_available <- function(prepared, markers) {
  available <- is.finite(prepared$score[, markers, drop = FALSE]) &
    prepared$source[, markers, drop = FALSE] > 0L
  for (img in unique(prepared$cells$image_id)) {
    idx <- which(prepared$cells$image_id == img)
    for (mk in markers) {
      if (!.gk_raw_supported(prepared, img, mk)) available[idx, mk] <- FALSE
    }
  }
  available
}
