# Registry of threshold methods: which roles may use them, which arguments
# they accept (with defaults) and what they do. Configuration validation and
# gk_thresholds() both read this registry, so a method cannot be configured
# with an argument its estimator does not understand.

.gk_method_registry <- function() {
  gated <- c("identity", "conditional_identity", "state")
  list(
    manual = list(
      roles = gated,
      args = list(value = NULL),
      required = "value",
      description = paste(
        "Fixed cut from the configuration (`value`). Used as given; the",
        "status records that no estimate was made."
      )
    ),
    valley = list(
      roles = gated,
      args = list(
        min_relative_height = 0.03, grid_n = 4096L, lower_quantile = 0.001,
        upper_quantile = 0.999, min_depth = 0.1, min_n = 100L
      ),
      required = character(),
      description = paste(
        "Lowest density point between the two highest density modes",
        "(modes at least `min_relative_height` of the maximum; density on the",
        "`lower_quantile`-`upper_quantile` range). The valley must lie at least",
        "`min_depth` below the lower mode, otherwise the marker has no separation."
      )
    ),
    tail = list(
      roles = gated,
      args = list(
        peak_fraction = 0.10, grid_n = 4096L, fallback_quantile = 0.99,
        min_tail_excess = 2, min_n = 100L
      ),
      required = character(),
      description = paste(
        "First grid point after the main density peak with density at most",
        "`peak_fraction` of the peak height (fallback: `fallback_quantile`).",
        "The right tail above the cut must hold at least `min_tail_excess` times",
        "the mass of the mirrored left tail, so a symmetric unimodal",
        "distribution is not called."
      )
    ),
    mixture = list(
      roles = gated,
      args = list(max_overlap = 0.2, max_iter = 500L, tol = 1e-8, min_n = 100L),
      required = character(),
      description = paste(
        "Two-component Gaussian mixture fitted by EM; the cut is where the",
        "posterior probability of the upper component is 0.5. Not callable when",
        "one component fits better (BIC) or when the components overlap by more",
        "than `max_overlap` (misclassified share of the smaller component)."
      )
    ),
    population_crossing = list(
      roles = c("identity", "conditional_identity"),
      args = list(
        rule = "max_crossing_q99", positive_z = 0.5, negative_z = 0,
        max_per_population = 1000L, n_grid = 2048L, negative_quantile = 0.99
      ),
      required = character(),
      description = paste(
        "Populations from gk_embed(). Populations whose mean score is more than",
        "`positive_z` SD above the population average form the positive pool,",
        "below `negative_z` the negative pool; up to `max_per_population` cells",
        "per population are sampled. Cut: first density crossing after the",
        "negative-pool peak (`rule = \"crossing\"`) or the larger of that",
        "crossing and the negative-pool quantile (`\"max_crossing_q99\"`).",
        "Requires an AUC of at least `min_auc`; the AUC describes the separation",
        "of internally selected pools and is not an accuracy."
      )
    ),
    parent_crossing = list(
      roles = "state",
      args = list(reference = "rest", n_grid = 2048L),
      required = character(),
      description = paste(
        "State markers: positive pool = cells of the parent set, reference pool",
        "= `reference` (\"rest\": analysed cells outside the parent set, or a",
        "named parent set). Cut: first density crossing after the reference",
        "peak. Requires AUC >= `min_auc` and a parent median above the",
        "reference median."
      )
    )
  )
}

# Arguments every state-marker method accepts in addition to its own.
.gk_state_common_args <- list(pooled = FALSE)

#' Threshold methods available in gatekeepR
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Lists the threshold estimation methods, the marker roles allowed to use
#' them, their arguments with defaults, and a description. Set a marker's
#' method with `threshold_method` and its arguments with `threshold_args` in
#' [gk_panel()].
#'
#' State markers also accept `pooled` (default `FALSE`): with `pooled = TRUE`
#' one estimate is made over the union of the marker's parent sets and used
#' for every parent, and the threshold table records this.
#'
#' @return A data frame with columns `method`, `role_allowed` (roles joined by
#'   `", "`), `arguments` (`name = default` pairs) and `description`.
#'
#' @examples
#' gk_threshold_methods()[, c("method", "role_allowed")]
#'
#' @family thresholds
#' @export
gk_threshold_methods <- function() {
  reg <- .gk_method_registry()
  fmt_args <- function(a) {
    if (length(a) == 0L) {
      return("")
    }
    vals <- vapply(a, function(v) {
      if (is.null(v)) "<required>" else paste(format(v), collapse = ", ")
    }, character(1))
    paste(paste(names(a), vals, sep = " = "), collapse = "; ")
  }
  data.frame(
    method = names(reg),
    role_allowed = vapply(reg, function(m) paste(m$roles, collapse = ", "), character(1)),
    arguments = vapply(reg, function(m) fmt_args(m$args), character(1)),
    description = vapply(reg, `[[`, character(1), "description"),
    stringsAsFactors = FALSE,
    row.names = NULL
  )
}

# Complete a marker's threshold arguments with the registry defaults.
.gk_method_args <- function(method, args, role = "identity") {
  reg <- .gk_method_registry()[[method]]
  defaults <- reg$args
  if (identical(role, "state")) {
    defaults <- c(defaults, .gk_state_common_args)
  }
  out <- defaults
  for (nm in names(args)) {
    out[[nm]] <- args[[nm]]
  }
  out
}
