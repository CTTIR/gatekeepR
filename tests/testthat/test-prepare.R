test_that("gk_prepare() selects, transforms and records signals", {
  prep <- gk_example_prepared()
  expect_s3_class(prep, "gk_prepared")
  cfg <- gk_example_config()
  expect_identical(colnames(prep$score), cfg$panel$markers$marker)
  expect_identical(prep$transforms$transform, rep("asinh", 12))
  expect_equal(prep$score[, "CD3e"], asinh(prep$signal_raw[, "CD3e"] / 5))
  expect_identical(prep$config_sha256, gk_config_hash(cfg))
  expect_match(prep$source_sha256, "^[0-9a-f]{64}$")
  expect_match(prep$source_manifest_sha256, "^[0-9a-f]{64}$")
  expect_snapshot(print(prep), transform = function(x) gsub('"[0-9a-f]{12}"', '"<hash>"', x))
})

test_that("transforms asinh, log1p and none are applied per marker", {
  x <- gk_test_cellspec(list(A = c(0, 5, 50), B = c(0, 1, 9), C = c(1, 2, 3)))
  cfg <- gk_config(
    gk_signal_policy(c("A", "B", "C")),
    gk_panel(c("A", "B", "C"), role = "identity", transform = c("asinh", "log1p", "none"), cofactor = c(5, 1, 1)),
    hierarchy = gk_hierarchy(list(gk_rule("R1", "a", all_of = "A")), version = "t")
  )
  prep <- gk_prepare(x, cfg, quiet = TRUE)
  expect_equal(unname(prep$score[, "A"]), asinh(c(0, 5, 50) / 5))
  expect_equal(unname(prep$score[, "B"]), log1p(c(0, 1, 9)))
  expect_equal(unname(prep$score[, "C"]), c(1, 2, 3))
})

test_that("F1 precondition: a constant-zero marker is NOT_CALLABLE_ABSENT before any correction", {
  withr::local_seed(11)
  n <- 500
  x <- gk_test_cellspec(list(
    A = exp(stats::rnorm(n, 3)), B = exp(stats::rnorm(n, 3)), CD21 = rep(0, n)
  ))
  cfg <- gk_test_config(c("A", "B", "CD21"))
  prep <- gk_prepare(x, cfg, quiet = TRUE)
  cb <- gk_callability(prep)
  expect_identical(cb$status[cb$marker == "CD21"], "NOT_CALLABLE_ABSENT")
  expect_identical(cb$support[cb$marker == "CD21"], "constant")
  expect_identical(cb$status[cb$marker == "A"], "PENDING_THRESHOLD")
})

test_that("near-constant, unavailable and underpowered markers get their status", {
  withr::local_seed(12)
  n <- 200
  near <- c(rep(3, 199), 50)
  unavailable <- c(rep(NA, 60), exp(stats::rnorm(140, 3)))
  few <- c(exp(stats::rnorm(15, 3)), rep(-1, 185))
  x <- gk_test_cellspec(list(A = exp(stats::rnorm(n, 3)), N = near, U = unavailable, F = few))
  cfg <- gk_config(
    gk_signal_policy(c("A", "N", "U", "F")),
    gk_panel(c("A", "N", "U", "F"), role = "identity",
      min_support = list(F = gk_min_support(max_unavailable = 0.99))
    ),
    hierarchy = gk_hierarchy(list(gk_rule("R1", "a", all_of = "A")), version = "t")
  )
  cb <- gk_callability(gk_prepare(x, cfg, quiet = TRUE))
  status <- stats::setNames(cb$status, cb$marker)
  expect_identical(status[["N"]], "NOT_CALLABLE_ABSENT")
  expect_identical(cb$support[cb$marker == "N"], "near_constant")
  expect_identical(status[["U"]], "NOT_CALLABLE_UNAVAILABLE")
  expect_identical(status[["F"]], "NOT_CALLABLE_UNDERPOWERED")
  expect_snapshot(cb[, c("marker", "status", "support", "details")])
})

test_that("a missing panel measurement is a structural error; an absent optional marker is not", {
  x <- gk_test_cellspec(list(A = c(1, 2, 3), B = c(3, 4, 5)))
  cfg <- gk_test_config(c("A", "B", "C"))
  expect_snapshot(gk_prepare(x, cfg, quiet = TRUE), error = TRUE)
  x2 <- gk_test_cellspec(list(A = c(1, 20, 3), B = c(3, 40, 5), C = c(0, 0, 0)))
  cfg2 <- gk_test_config(c("A", "B", "C"), optional = c(FALSE, FALSE, TRUE))
  expect_no_error(prep <- gk_prepare(x2, cfg2, quiet = TRUE))
  expect_identical(gk_callability(prep)$status[[3]], "NOT_CALLABLE_ABSENT")
})

test_that("localisation measurements are resolved by dictionary lookup", {
  x <- gk_test_cellspec(list(
    A = c(10, 20, 30, 40),
    S = c(5, 5, 5, 5),
    "nucleus:S" = c(9, 2, NA, 0),
    "cytoplasm:S" = c(3, 4, 1, 0)
  ))
  cfg <- gk_config(
    gk_signal_policy(c("A", "S"), compartment = c("cell", "nucleus")),
    gk_panel(c("A", "S"),
      role = c("identity", "state"), threshold_method = c("mixture", "tail"),
      parents = "P",
      localization = list(S = list(numerator = "nucleus", denominator = "cytoplasm", min_ratio = 1.5))
    ),
    parent_sets = list(P = "a"),
    hierarchy = gk_hierarchy(list(gk_rule("R1", "a", all_of = "A")), version = "t")
  )
  prep <- gk_prepare(x, cfg, quiet = TRUE)
  loc <- prep$localization$S
  expect_identical(loc$evaluable, c(TRUE, TRUE, FALSE, TRUE))
  expect_equal(loc$ratio[1:2], c((9 + 1e-9) / (3 + 1e-9), (2 + 1e-9) / (4 + 1e-9)))
  expect_equal(loc$ratio[[4]], 1)
  expect_true(is.na(loc$ratio[[3]]))
  expect_identical(unname(prep$signal_raw[, "S"]), c(9, 2, NA, 0))
  expect_identical(unname(prep$source[, "S"]), c(1L, 1L, 0L, 1L))
  cfg_bad <- cfg
  cfg_bad$panel$localization$S$denominator <- "membrane"
  expect_error(gk_prepare(x, cfg_bad, quiet = TRUE), "membrane", class = "gatekeepr_error_structure")
})

test_that("image selection, paths and messages", {
  a <- gk_simulate(n_cells = 300, seed = 4, image_id = "a")
  b <- gk_simulate(n_cells = 300, seed = 5, image_id = "b")
  both <- gk_cellspec(
    rbind(a$cells, b$cells), rbind(a$measurements, b$measurements),
    dictionary = a$dictionary, images = rbind(a$images, b$images)
  )
  cfg <- gk_example_config()
  prep <- gk_prepare(both, cfg, quiet = TRUE)
  expect_identical(unique(prep$callability$image_id), c("a", "b"))
  prep_b <- gk_prepare(both, cfg, image_id = "b", quiet = TRUE)
  expect_identical(unique(prep_b$cells$image_id), "b")
  expect_error(gk_prepare(both, cfg, image_id = "z"), class = "gatekeepr_error_input")
  expect_error(gk_prepare(both, list()), class = "gatekeepr_error_input")
  expect_snapshot(invisible(gk_prepare(a, cfg)))
  path <- gk_example_path("example-slide")
  expect_identical(gk_prepare(path, cfg, quiet = TRUE)$source_sha256, gk_example_prepared()$source_sha256)
  expect_error(gk_callability(list()), class = "gatekeepr_error_input")
})

test_that("gk_example_path() finds bundled data and explains missing entries", {
  expect_true(dir.exists(gk_example_path("example-slide")))
  expect_true(file.exists(gk_example_path("example-config.json")))
  expect_error(gk_example_path("nonsense"))
  cfg <- gk_read_config(gk_example_path("example-config.json"))
  expect_identical(gk_config_hash(cfg), gk_config_hash(gk_example_config()))
})
