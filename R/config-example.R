#' Example configuration for a generic tumour-immune panel
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A study-neutral configuration used by examples, tests, vignettes and the
#' app, matching the data produced by [gk_simulate()]. It declares twelve
#' markers:
#'
#' * identity: `PanCK`, `CD45`, `CD3e`, `CD4`, `CD8`, `CD20`, `CD68`, `CD31`;
#' * conditional identity: `CD21` (optional; absent in the simulated slide);
#' * context: `SMA` (displayed only);
#' * state: `FOXP3` (nuclear, within CD4 T cells and tumour cells) and `Ki67`
#'   (nuclear, within tumour and immune cells), both with a nucleus/cytoplasm
#'   localisation rule.
#'
#' The hierarchy contains a structure-review rule for PanCK-positive cells
#' (they stay "Unreviewed epithelial cells" until a tumour/benign decision), a
#' mixed-contact flag with policy `unresolved`, and two FOXP3 refinements.
#' It is not a validated panel for any study.
#'
#' @return A [gk_config()] object.
#'
#' @examples
#' cfg <- gk_example_config()
#' cfg$panel
#' cfg$hierarchy
#'
#' @family example data
#' @export
gk_example_config <- function() {
  markers <- c(
    "PanCK", "CD45", "CD3e", "CD4", "CD8", "CD20", "CD68", "CD31",
    "CD21", "SMA", "FOXP3", "Ki67"
  )
  policy <- gk_signal_policy(
    marker = markers,
    compartment = c(
      "cytoplasm", "cell", "cell", "cell", "cell", "cell", "cytoplasm", "cell",
      "cell", "cell", "nucleus", "nucleus"
    ),
    fallback_compartment = c(
      "cell", NA, NA, NA, NA, NA, "cell", NA, NA, NA, NA, NA
    )
  )
  nuclear <- list(numerator = "nucleus", denominator = "cytoplasm", min_ratio = 1.5)
  panel <- gk_panel(
    marker = markers,
    role = c(rep("identity", 8L), "conditional_identity", "context", "state", "state"),
    threshold_method = c(rep("mixture", 9L), "mixture", "parent_crossing", "tail"),
    parents = list(FOXP3 = c("CD4 T cells", "Tumor"), Ki67 = c("Tumor", "Immune")),
    localization = list(FOXP3 = nuclear, Ki67 = nuclear),
    optional = markers == "CD21",
    min_support = list(FOXP3 = gk_min_support(min_auc = 0.6))
  )
  rules <- list(
    gk_rule("R010", "Epithelial cells",
      all_of = "PanCK", review = "structure",
      pending_label = "Unreviewed epithelial cells",
      decisions = c(
        Tumor = "Tumor cells", Benign = "Benign epithelial cells",
        Unresolved = "Unresolved epithelial cells"
      )
    ),
    gk_rule("R020", "CD8 T cells", all_of = c("CD45", "CD3e", "CD8"), none_of = "CD4"),
    gk_rule("R030", "CD4 T cells", all_of = c("CD45", "CD3e", "CD4"), none_of = "CD8"),
    gk_rule("R040", "Other T cells", all_of = c("CD45", "CD3e")),
    gk_rule("R050", "B cells", all_of = c("CD45", "CD20"), none_of = "CD3e"),
    gk_rule("R060", "Macrophages", all_of = c("CD45", "CD68"), none_of = c("CD3e", "CD20")),
    gk_rule("R070", "Other immune cells", all_of = "CD45"),
    gk_rule("R080", "Endothelial cells", all_of = "CD31", none_of = c("CD45", "PanCK")),
    gk_rule("R090", "FDC-like cells", all_of = "CD21", none_of = c("CD45", "PanCK", "CD20"))
  )
  hierarchy <- gk_hierarchy(
    rules = rules,
    flags = list(mixed_contact = gk_flag(all_of = "PanCK", any_of = c("CD45", "CD3e"))),
    flag_policy = list(mixed_contact = "unresolved"),
    unresolved_label = "Unresolved epithelial-immune contact",
    version = "1.0.0",
    rationale = paste(
      "Generic example hierarchy. PanCK-positive cells await a structure",
      "decision before counting as tumour; epithelial-immune co-positive",
      "objects are unresolved rather than silently assigned."
    )
  )
  parent_sets <- list(
    "CD4 T cells" = "CD4 T cells",
    "Tumor" = "Tumor cells",
    "Immune" = c(
      "CD8 T cells", "CD4 T cells", "Treg cells", "Other T cells", "B cells",
      "Macrophages", "Other immune cells"
    )
  )
  refinements <- list(
    gk_refinement("RF10", "FOXP3", "CD4 T cells", "CD4 T cells", "Treg cells"),
    gk_refinement("RF20", "FOXP3", "Tumor", "Tumor cells", "FOXP3+ tumor cells")
  )
  gk_config(
    signal_policy = policy, panel = panel, parent_sets = parent_sets,
    hierarchy = hierarchy, refinements = refinements
  )
}

#' Paths to bundled example data
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Returns the path of a file or directory shipped in `inst/extdata`:
#'
#' * `"example-slide"`: a cellspec directory from `gk_simulate(seed = 1)`;
#' * `"example-config.json"`: [gk_example_config()] written as JSON;
#' * `"example-review"`: a saved review working directory;
#' * `"example-export"`: a locked, verified export of that review.
#'
#' @param name Which example to locate.
#'
#' @return A single path.
#'
#' @examples
#' gk_example_path("example-config.json")
#'
#' @family example data
#' @export
gk_example_path <- function(name = c(
                              "example-slide", "example-config.json",
                              "example-review", "example-export"
                            )) {
  name <- rlang::arg_match(name)
  path <- system.file("extdata", name, package = "gatekeepR")
  if (!nzchar(path)) {
    .gk_abort(
      c(
        "Example {.val {name}} is not installed.",
        "i" = "Reinstall gatekeepR, or rebuild the data with {.path data-raw/example-data.R}."
      ),
      class = "input"
    )
  }
  path
}
