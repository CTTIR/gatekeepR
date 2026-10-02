.gk_candidate_assert <- function(ok, message) {
  if (!isTRUE(ok)) .gk_abort(message, class = "input")
}

#' Import externally frozen residual parameters without fitting
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Validates a numerical parameter bundle and authenticates its external source
#' file. The caller maps the external format into the documented parameter
#' fields; the source hash authenticates bytes, not mapping correctness or
#' scientific approval. No coefficient is estimated or changed.
#'
#' @param parameters Named list containing `panel`, `identity_markers`,
#'   `identity_robust`, `identity_regression`, `identity_center`, `identity_scale`,
#'   `panel_robust`, `pc_center`, `pc1_rotation`, `panel_regression`, `panel_center`,
#'   `panel_scale` and `n_training`, with the same shapes as a fitted model.
#' @param source_file Existing file from which the parameters were obtained.
#' @param source_sha256 Expected lowercase SHA-256 of that file.
#' @param provenance Named list of caller source and transformation metadata.
#' @param bindings Named list of immutable caller policies or thresholds.
#' @return A hash-bound `gk_frozen_residual_model`. The training-score hash is
#'   unavailable; the authenticated source-file hash is stored in provenance.
#' @family corrections
#' @export
#' @examples
#' x <- cbind(A = seq_len(30), B = sin(seq_len(30)))
#' fitted <- gk_fit_residual_model(x, c("A", "B"))
#' fields <- c("panel", "identity_markers", "identity_robust",
#'   "identity_regression", "identity_center", "identity_scale", "panel_robust",
#'   "pc_center", "pc1_rotation", "panel_regression", "panel_center",
#'   "panel_scale", "n_training")
#' path <- tempfile(fileext = ".rds")
#' saveRDS(fitted, path)
#' imported <- gk_import_residual_model(unclass(fitted)[fields], path,
#'   digest::digest(file = path, algo = "sha256"))
#' gk_apply_residual_model(x, imported)$identity
#' unlink(path)
gk_import_residual_model <- function(parameters, source_file, source_sha256,
                                     provenance = list(), bindings = list()) {
  ok <- .gk_candidate_assert
  ok(is.character(source_file) && length(source_file) == 1L &&
    !is.na(source_file) && file.exists(source_file), "Source file is missing.")
  ok(is.character(source_sha256) && length(source_sha256) == 1L &&
    !is.na(source_sha256) && grepl("^[a-f0-9]{64}$", source_sha256) &&
    identical(digest::digest(file = source_file, algo = "sha256"), source_sha256),
    "External parameter source hash differs.")
  fields <- c("panel", "identity_markers", "identity_robust",
    "identity_regression", "identity_center", "identity_scale", "panel_robust",
    "pc_center", "pc1_rotation", "panel_regression", "panel_center",
    "panel_scale", "n_training")
  ok(is.list(parameters) && !anyDuplicated(names(parameters)) &&
    setequal(names(parameters), fields), "Incomplete or unexpected parameter fields.")
  panel <- parameters$panel
  ids <- parameters$identity_markers
  .gk_check_character(panel, min_length = 1L, unique = TRUE)
  .gk_check_character(ids, min_length = 1L, unique = TRUE)
  ok(all(ids %in% panel), "Identity markers are outside the panel.")
  vector_ok <- function(x, dictionary, missing = FALSE, positive = FALSE) {
    is.numeric(x) && is.null(dim(x)) && identical(names(x), dictionary) &&
      all(if (missing) is.na(x) | is.finite(x) else is.finite(x)) &&
      (!positive || all(x > 0))
  }
  for (prefix in c("identity", "panel")) {
    dictionary <- if (prefix == "identity") ids else panel
    robust <- parameters[[paste0(prefix, "_robust")]]
    ok(is.list(robust) && vector_ok(robust$center, dictionary, prefix == "panel") &&
      vector_ok(robust$scale, dictionary, positive = TRUE) &&
      is.logical(robust$fallback) && is.null(dim(robust$fallback)) &&
      identical(names(robust$fallback), dictionary) &&
      !anyNA(robust$fallback) && is.numeric(robust$clip) && is.null(dim(robust$clip)) &&
      length(robust$clip) == 2L && all(is.finite(robust$clip)) &&
      robust$clip[1L] < robust$clip[2L], "Invalid robust normalization parameters.")
    coefficients <- parameters[[paste0(prefix, "_regression")]]
    ok(is.matrix(coefficients) && is.numeric(coefficients) &&
      identical(dim(coefficients), c(2L, length(dictionary))) &&
      identical(colnames(coefficients), dictionary) &&
      all(if (prefix == "identity") is.finite(coefficients) else
        is.na(coefficients) | is.finite(coefficients)), "Invalid regression parameters.")
    ok(vector_ok(parameters[[paste0(prefix, "_center")]], dictionary,
      prefix == "panel") && vector_ok(parameters[[paste0(prefix, "_scale")]],
      dictionary, positive = TRUE), "Invalid final normalization parameters.")
  }
  ok(vector_ok(parameters$pc_center, ids) && vector_ok(parameters$pc1_rotation, ids),
    "Invalid projection parameter dictionary.")
  ok(is.numeric(parameters$n_training) && length(parameters$n_training) == 1L &&
    is.finite(parameters$n_training) && parameters$n_training >= 20 &&
    parameters$n_training == floor(parameters$n_training), "Invalid training count.")
  for (value in list(provenance, bindings)) {
    ok(is.list(value) && (!length(value) || (!is.null(names(value)) &&
      !anyNA(names(value)) && all(nzchar(names(value))) && !anyDuplicated(names(value)))),
      "Provenance and bindings must be named lists.")
    .gk_residual_hash_payload(value)
  }
  provenance$external_source_sha256 <- source_sha256
  model <- c(list(schema = "gk_frozen_residual_1.0.0"), parameters[fields],
    list(source_scores_sha256 = NA_character_, provenance = provenance, bindings = bindings))
  model$model_sha256 <- .gk_residual_hash(model)
  structure(model, class = "gk_frozen_residual_model")
}

.gk_candidate_matrix <- function(x, numeric = TRUE) {
  is.matrix(x) && (if (numeric) is.numeric(x) else is.character(x)) &&
    (nrow(x) == 0L || !is.null(rownames(x))) && !is.null(colnames(x)) &&
    !anyNA(dimnames(x)[[1L]]) && !anyNA(dimnames(x)[[2L]]) &&
    !anyDuplicated(rownames(x)) && !anyDuplicated(colnames(x)) &&
    all(nzchar(rownames(x))) && all(nzchar(colnames(x)))
}

#' Apply fixed cutoffs with explicit raw-support availability
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Selected signals and underlying features are assessed over the full supplied
#' image scope. A score can be HIGH or LOW only when enabled, finite, supported
#' by at least `min_finite` nonnegative selected values with distinct values,
#' and its selected source feature has at least `min_finite` finite values with
#' distinct values. The named source value must also be finite at that cell;
#' finite selected values cannot substitute for missing source measurements.
#' All other calls remain UNAVAILABLE. No threshold is fitted.
#'
#' @param scores Keyed numeric score matrix; its rows may be a subset of selected.
#' @param selected Keyed numeric selected-signal matrix for the full image scope.
#' @param selected_features Character matrix matching selected, naming each
#'   underlying raw feature. NA denotes an unavailable selected source.
#' @param raw_features Keyed numeric raw-feature matrix with the same row order
#'   as selected. Source-feature support counts all finite values.
#' @param cutoffs Named numeric vector in exact score-column order.
#' @param enabled Named logical vector in exact score-column order.
#' @param min_finite Minimum finite count, an integer of at least two.
#' @return List with ternary `calls`, selected-marker and source-feature support.
#' @family classification
#' @export
#' @examples
#' x <- matrix(1:4, 4, 1, dimnames = list(letters[1:4], "A"))
#' f <- x
#' colnames(f) <- "raw_a"
#' sources <- matrix("raw_a", 4, 1, dimnames = dimnames(x))
#' gk_fixed_signal_calls(x, x, sources, f, c(A = 2), c(A = TRUE), 2)$calls
gk_fixed_signal_calls <- function(scores, selected, selected_features, raw_features,
                                  cutoffs, enabled, min_finite = 20L) {
  ok <- .gk_candidate_assert
  ok(.gk_candidate_matrix(scores) && .gk_candidate_matrix(selected) &&
    .gk_candidate_matrix(raw_features), "Signals require unique named matrix keys.")
  ok(is.matrix(selected_features) && is.character(selected_features) &&
    identical(dimnames(selected_features), dimnames(selected)) &&
    identical(dim(selected_features), dim(selected)) &&
    identical(rownames(raw_features), rownames(selected)) &&
    all(colnames(scores) %in% colnames(selected)) &&
    all(rownames(scores) %in% rownames(selected)), "Signal/source keys differ.")
  ok(all(is.na(selected_features) | selected_features %in% colnames(raw_features)),
    "Selected source feature is unknown.")
  ok(is.numeric(cutoffs) && is.null(dim(cutoffs)) &&
    identical(names(cutoffs), colnames(scores)) &&
    is.logical(enabled) && is.null(dim(enabled)) &&
    identical(names(enabled), colnames(scores)) &&
    !anyNA(enabled), "Cutoff or enablement dictionary differs.")
  ok(is.numeric(min_finite) && length(min_finite) == 1L && is.finite(min_finite) &&
    min_finite >= 2 && min_finite == floor(min_finite), "Invalid support minimum.")
  supported <- function(v, nonnegative) {
    good <- is.finite(v) & (!nonnegative | v >= 0)
    sum(good) >= min_finite && length(unique(v[good])) > 1L
  }
  source_support <- vapply(seq_len(ncol(raw_features)), function(j)
    supported(raw_features[, j], FALSE), logical(1))
  names(source_support) <- colnames(raw_features)
  marker_support <- vapply(seq_len(ncol(selected)), function(j)
    supported(selected[, j], TRUE), logical(1))
  names(marker_support) <- colnames(selected)
  calls <- matrix("UNAVAILABLE", nrow(scores), ncol(scores), dimnames = dimnames(scores))
  index <- match(rownames(scores), rownames(selected))
  for (marker in colnames(scores)) {
    source <- selected_features[index, marker]
    source_values <- raw_features[cbind(index, match(source, colnames(raw_features)))]
    usable <- is.finite(source_values) & is.finite(scores[, marker]) &
      is.finite(selected[index, marker]) &
      selected[index, marker] >= 0 & !is.na(source) & source_support[source] %in% TRUE
    if (enabled[[marker]] && is.finite(cutoffs[[marker]]) && marker_support[[marker]]) {
      calls[usable, marker] <- ifelse(scores[usable, marker] >= cutoffs[[marker]], "HIGH", "LOW")
    }
  }
  list(calls = calls, marker_support = marker_support, source_support = source_support)
}

#' Evaluate declarative rules on ternary candidate calls
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Each rule has unique `id`, `label`, and optional named `all` and `any` lists.
#' List entries specify allowed states for a named marker. All `all` conditions
#' and at least one `any` condition must match; absent groups impose no condition.
#' Later matching rules overwrite earlier labels. No expression is evaluated,
#' and unavailable never implicitly means LOW. Labels are caller descriptions,
#' not scientific approvals; authorization flags are always false.
#'
#' @param calls Keyed character matrix containing HIGH, LOW or UNAVAILABLE.
#' @param rules Ordered list of declarative rules as described above.
#' @param default_label Nonempty label for rows matching no rule.
#' @return Data frame with cell_id, label, rule_id, review_authorized and
#'   production_eligible. Both authorization fields are always FALSE.
#' @family classification
#' @export
#' @examples
#' calls <- matrix(c("HIGH", "UNAVAILABLE"), 2, 1,
#'   dimnames = list(c("one", "two"), "A"))
#' rules <- list(list(id = "signal", label = "candidate", all = list(A = "HIGH")))
#' gk_apply_candidate_rules(calls, rules, "unresolved")
gk_apply_candidate_rules <- function(calls, rules, default_label) {
  ok <- .gk_candidate_assert
  states <- c("HIGH", "LOW", "UNAVAILABLE")
  ok(.gk_candidate_matrix(calls, FALSE) && all(calls %in% states),
    "Invalid ternary call matrix.")
  ok(is.character(default_label) && length(default_label) == 1L &&
    !is.na(default_label) && nzchar(default_label) && is.list(rules), "Invalid rule policy.")
  ids <- character()
  out <- data.frame(cell_id = as.character(rownames(calls)), label = rep(default_label, nrow(calls)),
    rule_id = rep(NA_character_, nrow(calls)), review_authorized = rep(FALSE, nrow(calls)),
    production_eligible = rep(FALSE, nrow(calls)), stringsAsFactors = FALSE)
  for (rule in rules) {
    ok(is.list(rule) && !anyDuplicated(names(rule)) &&
      all(names(rule) %in% c("id", "label", "all", "any")) &&
      is.character(rule$id) && length(rule$id) == 1L && !is.na(rule$id) &&
      nzchar(rule$id) && !rule$id %in% ids && is.character(rule$label) &&
      length(rule$label) == 1L && !is.na(rule$label) && nzchar(rule$label), "Invalid rule.")
    ids <- c(ids, rule$id)
    match_group <- function(group, any_group) {
      if (is.null(group) || !length(group)) return(rep(!any_group, nrow(calls)))
      ok(is.list(group) && !is.null(names(group)) && !anyNA(names(group)) &&
        !anyDuplicated(names(group)) && all(names(group) %in% colnames(calls)),
        "Rule marker dictionary differs.")
      matched <- matrix(FALSE, nrow(calls), length(group))
      for (j in seq_along(group)) {
        allowed <- group[[j]]
        ok(is.character(allowed) && length(allowed) > 0L && !anyNA(allowed) &&
          !anyDuplicated(allowed) && all(allowed %in% states), "Invalid allowed states.")
        matched[, j] <- calls[, names(group)[j]] %in% allowed
      }
      if (any_group) rowSums(matched) > 0L else rowSums(matched) == ncol(matched)
    }
    hit <- match_group(rule$all, FALSE)
    if (length(rule$any)) hit <- hit & match_group(rule$any, TRUE)
    out$label[hit] <- rule$label
    out$rule_id[hit] <- rule$id
  }
  out
}
