test_that("gk_min_support() validates and prints", {
  ms <- gk_min_support(min_cells = 30, min_auc = 0.7)
  expect_s3_class(ms, "gk_min_support")
  expect_identical(ms$min_cells, 30L)
  expect_snapshot(print(ms))
  expect_error(gk_min_support(max_unavailable = 2), class = "gatekeepr_error_input")
  expect_identical(.gk_as_min_support(list(min_auc = 0.5))$min_auc, 0.5)
  expect_error(.gk_as_min_support(list(bogus = 1)), class = "gatekeepr_error_config")
  expect_error(.gk_as_min_support(list(min_auc = 5)), class = "gatekeepr_error_config")
})

test_that("gk_panel() expands shared and per-marker arguments", {
  p <- gk_panel(
    c("A", "B", "S"),
    role = c("identity", "identity", "state"),
    threshold_method = c("valley", "mixture", "tail"),
    threshold_args = list(A = list(min_depth = 0.2)),
    parents = "Parents",
    localization = list(S = list(numerator = "nucleus", denominator = "cytoplasm", min_ratio = 2)),
    min_support = list(B = gk_min_support(min_auc = 0.6))
  )
  expect_s3_class(p, "gk_panel")
  expect_identical(p$threshold_args$A, list(min_depth = 0.2))
  expect_identical(p$threshold_args$B, list())
  expect_identical(p$parents, list(S = "Parents"))
  expect_identical(p$localization$S$statistic, "mean")
  expect_null(p$localization$A)
  expect_identical(p$min_support$B$min_auc, 0.6)
  expect_identical(p$min_support$A$min_auc, 0.65)
  shared <- gk_panel(c("A", "B"), role = "identity", threshold_method = "valley", threshold_args = list(min_depth = 0.3))
  expect_identical(shared$threshold_args$B, list(min_depth = 0.3))
  expect_snapshot(print(p))
})

test_that("gk_panel() rejects invalid panels with specific messages", {
  expect_snapshot(gk_panel("S", role = "state", threshold_method = "tail"), error = TRUE)
  expect_snapshot(gk_panel("A", role = "lineage"), error = TRUE)
  expect_snapshot(gk_panel("A", role = "identity", threshold_method = "otsu"), error = TRUE)
  expect_snapshot(gk_panel("A", role = "identity", threshold_method = "parent_crossing"), error = TRUE)
  expect_snapshot(gk_panel("A", role = "identity", threshold_args = list(A = list(bogus = 1))), error = TRUE)
  expect_error(gk_panel(c("A", "B"), role = c("identity", "identity", "identity")), class = "gatekeepr_error_config")
  expect_error(gk_panel("A", role = "identity", transform = "sqrt"), class = "gatekeepr_error_config")
  expect_error(gk_panel("A", role = "identity", cofactor = 0), class = "gatekeepr_error_config")
  expect_error(gk_panel("A", role = "identity", optional = NA), class = "gatekeepr_error_config")
  expect_error(gk_panel("A", role = "identity", threshold_method = "manual"), "requires", class = "gatekeepr_error_config")
  expect_error(gk_panel("A", role = "identity", threshold_method = "manual", threshold_args = list(value = "x")),
    class = "gatekeepr_error_config"
  )
  expect_error(
    gk_panel("A", role = "identity", threshold_method = "population_crossing", threshold_args = list(rule = "q95")),
    class = "gatekeepr_error_config"
  )
  expect_error(gk_panel("A", role = "identity", threshold_args = "x"), class = "gatekeepr_error_config")
  expect_error(gk_panel("A", role = "identity", threshold_args = list(1)), class = "gatekeepr_error_config")
  expect_error(gk_panel("A", role = "identity", parents = list(A = "P")), "not a state marker", class = "gatekeepr_error_config")
  expect_error(gk_panel("S", role = "state", parents = list(S = 1)), class = "gatekeepr_error_config")
  expect_error(gk_panel("A", role = "identity", localization = list(B = list())), class = "gatekeepr_error_config")
  expect_error(
    gk_panel("A", role = "identity", localization = list(A = list(numerator = "nucleus", denominator = "nucleus", min_ratio = 1))),
    "localisation", class = "gatekeepr_error_config"
  )
  expect_error(gk_panel("A", role = "identity", min_support = list(B = gk_min_support())), class = "gatekeepr_error_config")
  expect_silent(gk_panel("C", role = "context", threshold_method = "anything-ignored"))
})

test_that("panels combine with c() and refuse duplicate markers", {
  a <- gk_panel("A", role = "identity")
  b <- gk_panel("S", role = "state", parents = "P", threshold_method = "tail")
  ab <- c(a, b)
  expect_identical(ab$markers$marker, c("A", "S"))
  expect_identical(ab$parents, list(S = "P"))
  expect_error(c(a, a), class = "gatekeepr_error_config")
  expect_error(c(a, list()), class = "gatekeepr_error_config")
})
