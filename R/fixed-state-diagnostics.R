#' Apply fixed score thresholds without raw-support assessment
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' This numerical diagnostic does not establish raw measurement support or
#' scientific eligibility. Disabled, missing or nonfinite scores and thresholds
#' produce UNAVAILABLE. Equality to a finite cutoff produces HIGH.
#' @param scores Keyed numeric score matrix.
#' @param cutoffs Named numeric vector in exact column order.
#' @param enabled Named logical vector in exact column order, without missingness.
#' @return Keyed character matrix containing HIGH, LOW or UNAVAILABLE.
#' @export
#' @examples
#' x <- matrix(c(1, NA), 2, 1, dimnames = list(c("a", "b"), "signal"))
#' gk_fixed_threshold_calls(x, c(signal = 1), c(signal = TRUE))
gk_fixed_threshold_calls <- function(scores, cutoffs, enabled) {
  ok <- .gk_candidate_assert
  ok(.gk_candidate_matrix(scores), "Scores require unique named matrix keys.")
  .gk_state_vector(cutoffs, colnames(scores), "numeric")
  .gk_state_vector(enabled, colnames(scores), "logical")
  ok(!anyNA(enabled), "Enablement must not be missing.")
  out <- matrix("UNAVAILABLE", nrow(scores), ncol(scores), dimnames = dimnames(scores))
  for (j in seq_len(ncol(scores))) {
    usable <- is.finite(scores[, j]) & is.finite(cutoffs[j]) & enabled[j]
    out[usable, j] <- ifelse(scores[usable, j] >= cutoffs[j], "HIGH", "LOW")
  }
  out
}

.gk_state_vector <- function(x, dictionary, mode) {
  .gk_candidate_assert(is.null(dim(x)) && identical(names(x), dictionary) &&
    (if (mode == "numeric") is.numeric(x) else is.logical(x)),
    "State parameter dictionary or type differs.")
}

#' Diagnose fixed state thresholds with explicit parent and localization scope
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Each column is an independent state test. Parent eligibility is supplied by
#' the caller and is not scientific authorization. Optional localization uses
#' `(numerator + offset) / (denominator + offset) >= minimum`; both measurements
#' and their offset-adjusted operands must be finite. Nonfinite ratios cannot be positive. `audit_missing` explicitly
#' selects whether nonfinite or unavailable measurements produce FALSE or NA in the
#' legacy audit flag. The separate nullable positive flag is NA whenever the
#' measurement, threshold or parent is unavailable or ineligible. Missingness
#' status takes precedence over threshold availability, then parent eligibility.
#' No model, threshold or authorization is inferred.
#' @param values Keyed numeric matrix of state measurements in threshold units.
#' @param cutoffs Named numeric vector in exact state-column order.
#' @param parent Keyed logical matrix matching values; NA means unknown eligibility.
#' @param localization_numerator,localization_denominator Optional keyed numeric
#'   matrices matching values, in caller-specified common units.
#' @param localization_minimum Named numeric vector matching columns. NA disables
#'   localization for that column; finite values enable it.
#' @param localization_offset Finite nonnegative scalar added to both operands.
#' @param audit_missing Named character vector of `false` or `propagate` per state.
#' @return Long data frame with cell_id, state, audit_positive, measurement_evaluable,
#'   parent_eligible, threshold_available, diagnostic_status, nullable_positive,
#'   review_authorized and production_eligible. Authorization is always FALSE.
#' @export
#' @examples
#' x <- matrix(c(1, NA), 2, 1, dimnames = list(c("a", "b"), "state"))
#' parent <- matrix(TRUE, 2, 1, dimnames = dimnames(x))
#' gk_fixed_state_diagnostics(x, c(state = 1), parent,
#'   audit_missing = c(state = "propagate"))
gk_fixed_state_diagnostics <- function(values, cutoffs, parent,
                                      localization_numerator = NULL,
                                      localization_denominator = NULL,
                                      localization_minimum = NULL,
                                      localization_offset = 1e-9,
                                      audit_missing) {
  ok <- .gk_candidate_assert
  ok(.gk_candidate_matrix(values) && ncol(values) > 0L, "State values require unique named matrix keys.")
  dictionary <- colnames(values)
  .gk_state_vector(cutoffs, dictionary, "numeric")
  same <- function(x) is.matrix(x) && identical(dim(x), dim(values)) &&
    identical(dimnames(x), dimnames(values))
  ok(same(parent) && is.logical(parent), "Parent eligibility keys or type differ.")
  ok(is.character(audit_missing) && is.null(dim(audit_missing)) &&
    identical(names(audit_missing), dictionary) &&
    all(audit_missing %in% c("false", "propagate")), "Invalid audit missingness policy.")
  if (is.null(localization_minimum)) {
    localization_minimum <- stats::setNames(rep(NA_real_, ncol(values)), dictionary)
  }
  .gk_state_vector(localization_minimum, dictionary, "numeric")
  ok(all(is.na(localization_minimum) | is.finite(localization_minimum)),
    "Localization minima must be finite or missing.")
  ok(is.numeric(localization_offset) && is.null(dim(localization_offset)) &&
    length(localization_offset) == 1L && is.finite(localization_offset) &&
    localization_offset >= 0, "Invalid localization offset.")
  if (any(is.finite(localization_minimum))) {
    ok(same(localization_numerator) && is.numeric(localization_numerator) &&
      same(localization_denominator) && is.numeric(localization_denominator),
      "Localization keys or type differ.")
  } else {
    ok(is.null(localization_numerator) && is.null(localization_denominator),
      "Localization operands supplied without enabled localization.")
  }
  out <- vector("list", ncol(values))
  for (j in seq_len(ncol(values))) {
    measured <- is.finite(values[, j])
    positive <- values[, j] >= cutoffs[j]
    if (is.finite(localization_minimum[j])) {
      numerator <- localization_numerator[, j] + localization_offset
      denominator <- localization_denominator[, j] + localization_offset
      ratio <- numerator / denominator
      measured <- measured & is.finite(localization_numerator[, j]) &
        is.finite(localization_denominator[, j]) & is.finite(numerator) &
        is.finite(denominator) & denominator != 0 & is.finite(ratio)
      positive <- positive & measured & ratio >= localization_minimum[j]
    }
    positive[!measured] <- if (audit_missing[j] == "false") FALSE else NA
    threshold <- is.finite(cutoffs[j])
    positive <- positive & parent[, j] & threshold
    evaluable <- measured & parent[, j] %in% TRUE & threshold
    status <- rep("EVALUABLE_RULE_ONLY", nrow(values))
    status[!parent[, j] %in% TRUE] <- "PARENT_INELIGIBLE_OR_UNKNOWN"
    status[rep(!threshold, nrow(values))] <- "UNAVAILABLE_THRESHOLD"
    status[!measured] <- "UNAVAILABLE_MEASUREMENT_OR_LOCALIZATION"
    out[[j]] <- data.frame(cell_id = as.character(rownames(values)), state = rep(dictionary[j], nrow(values)),
      audit_positive = positive, measurement_evaluable = measured,
      parent_eligible = parent[, j], threshold_available = rep(threshold, nrow(values)),
      diagnostic_status = status, nullable_positive = ifelse(evaluable, positive, NA),
      review_authorized = rep(FALSE, nrow(values)),
      production_eligible = rep(FALSE, nrow(values)), stringsAsFactors = FALSE)
  }
  do.call(rbind, out)
}
