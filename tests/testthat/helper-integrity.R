# Small, fully controlled review exercises real preparation and classification.
gk_integrity_review <- function(state_values = rep(seq_len(12), 2), duplicate_keys = FALSE) {
  markers <- c("A", "S")
  config <- gk_config(
    signal_policy = gk_signal_policy(markers),
    panel = gk_panel(markers, role = c("identity", "state"), transform = "none",
      threshold_method = "manual", threshold_args = list(A = list(value = 6.5), S = list(value = 6.5)),
      parents = list(S = "A population"), min_support = gk_min_support(min_cells = 2L)),
    hierarchy = gk_hierarchy(list(gk_rule("A", "A cells", all_of = "A",
      review = "structure", pending_label = "Awaiting review",
      decisions = c(Tumor = "Tumor", Benign = "Benign", Unresolved = "Unresolved"))), version = "integrity-test"),
    parent_sets = list("A population" = c("Awaiting review", "Tumor", "Benign", "Unresolved")),
    refinements = list(gk_refinement("S-refine", "S", "A population", "Tumor", "State-positive Tumor")))
  cellspec <- gk_test_cellspec(list(A = rep(seq_len(12), 2), S = state_values))
  if (duplicate_keys) {
    cells <- cellspec$cells
    cells$cell_id <- rep(sprintf("c%04d", seq_len(12)), 2)
    cells$image_id <- rep(c("img-1", "img-2"), each = 12)
    cells$x <- c(seq_len(12), 100 + seq_len(12))
    cellspec <- gk_cellspec(cells, cellspec$measurements)
  }
  prepared <- gk_prepare(cellspec, config, quiet = TRUE)
  thresholds <- gk_thresholds(prepared, config)
  classification <- gk_classify(prepared, thresholds, config)
  states <- gk_state_calls(prepared, thresholds, classification, config)
  structures <- gk_structures(classification, prepared, min_cells = 2L, min_pts = 2L)
  gk_review(classification, states, structures, thresholds, prepared)
}
