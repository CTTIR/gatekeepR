test_that("classification uses ordered rules and records disabled rules", {
  prep <- gk_example_prepared()
  cfg <- gk_example_config()
  th <- gk_thresholds(prep, cfg, seed = 1L)
  expect_warning(
    cl <- gk_classify(prep, th, cfg),
    class = "gatekeepr_warning_disabled_rules"
  )
  expect_s3_class(cl, "gk_classification")
  expect_identical(nrow(cl$cells), nrow(prep$cells))
  expect_true(any(cl$cells$pending_review))
  expect_true(all(cl$cells$cell_type[cl$cells$pending_review] ==
    "Unreviewed epithelial cells"))
  expect_true(any(cl$disabled_rules$rule_id == "R090"))
  expect_true(all(is.na(cl$calls[, "CD21"])))
  expect_true(all(c("image_id", "cell_type", "n", "proportion") %in%
    names(summary(cl))))
})

test_that("state calls are long and disabled until reviewed", {
  prep <- gk_example_prepared()
  cfg <- gk_example_config()
  th <- gk_thresholds(prep, cfg, seed = 1L)
  cl <- suppressWarnings(gk_classify(prep, th, cfg))
  states <- gk_state_calls(prep, th, cl, cfg)
  expect_s3_class(states, "gk_state_calls")
  expect_equal(nrow(states$calls), nrow(prep$cells) * 2L * 2L)
  expect_true(all(!states$calls$enabled))
  expect_true(all(c("marker", "parent", "in_parent", "evaluable",
    "localization_ratio", "positive", "enabled") %in% names(states$calls)))
  expect_equal(nrow(states$state_thresholds), 4L)
})

test_that("structure IDs are deterministic and cells outside clusters stay unmapped", {
  skip_if_not_installed("dbscan")
  prep <- gk_example_prepared()
  cfg <- gk_example_config()
  th <- gk_thresholds(prep, cfg, seed = 1L)
  cl <- suppressWarnings(gk_classify(prep, th, cfg))
  structures <- gk_structures(cl, prep, min_cells = 20L)
  expect_s3_class(structures, "gk_structures")
  expect_true(all(grepl("^E[0-9]{2}$", structures$structures$structure_id)))
  expect_true(all(!duplicated(structures$structures$structure_id)))
  expect_true(any(is.na(structures$cell_structure$structure_id)))
})
