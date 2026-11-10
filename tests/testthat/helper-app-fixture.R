gk_app_test_review <- function(n = 100L) {
  testthat::skip_if_not_installed("dbscan")
  cfg <- gk_config(gk_signal_policy(c("A", "S")),
    gk_panel(c("A", "S"), role = c("identity", "state"), transform = "none",
      threshold_method = "manual", threshold_args = list(A = list(value = 50), S = list(value = 75)),
      parents = list(S = "Tumor"), min_support = gk_min_support(min_cells = 5L)),
    hierarchy = gk_hierarchy(list(gk_rule("R1", "Epithelial", all_of = "A", review = "structure",
      pending_label = "Pending", decisions = c(Tumor = "Tumor", Benign = "Benign", Unresolved = "Unresolved"))), version = "test"),
    parent_sets = list(Tumor = c("Pending", "Tumor")))
  prep <- gk_prepare(gk_test_cellspec(list(A = seq_len(n), S = seq_len(n))), cfg, quiet = TRUE)
  th <- gk_thresholds(prep, cfg)
  cl <- gk_classify(prep, th, cfg)
  gk_review(cl, gk_state_calls(prep, th, cl, cfg),
    gk_structures(cl, prep), th, prep)
}
