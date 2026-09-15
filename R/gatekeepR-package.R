#' gatekeepR: Reviewable Marker Gating and Phenotyping for Multiplexed Imaging
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' gatekeepR turns per-cell marker measurements from multiplexed tissue images
#' into cell types that a person has reviewed. It declares the marker panel
#' and the phenotype hierarchy as data, decides per image which markers can be
#' called at all, estimates thresholds with documented methods, classifies
#' cells with one classifier shared by batch code and the review app, keeps
#' reviewer decisions in append-only ledgers, and locks a review into a
#' verifiable export.
#'
#' @section Main functions:
#' * Configuration: [gk_signal_policy()], [gk_panel()], [gk_min_support()],
#'   [gk_rule()], [gk_flag()], [gk_hierarchy()], [gk_refinement()],
#'   [gk_override()], [gk_config()], [gk_validate_config()],
#'   [gk_read_config()], [gk_write_config()], [gk_config_hash()],
#'   [gk_example_config()].
#' * Cell tables: [gk_cellspec()], [gk_read_cellspec()],
#'   [gk_write_cellspec()].
#' * Preparation and callability: [gk_prepare()], [gk_callability()].
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom lifecycle deprecated
## usethis namespace: end
NULL
