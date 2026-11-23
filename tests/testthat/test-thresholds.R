test_that("thresholds record callable results and evidence", {
  prep <- gk_example_prepared()
  thresholds <- gk_thresholds(prep, gk_example_config(), seed = 1L)
  expect_s3_class(thresholds, "gk_thresholds")
  expect_equal(nrow(thresholds), 9L)
  expect_identical(thresholds$status[thresholds$marker == "CD21"],
    "NOT_CALLABLE_ABSENT")
  callable <- thresholds$status == "CALLABLE"
  expect_true(all(is.finite(thresholds$estimate[callable])))
  evidence <- attr(thresholds, "evidence")
  expect_length(evidence, sum(!is.na(thresholds$evidence_ref)))
  expect_true(all(names(evidence) == thresholds$evidence_ref[!is.na(thresholds$evidence_ref)]))
})

test_that("threshold estimators return explicit no-separation statuses", {
  args <- .gk_method_args("valley", list(min_n = 10L))
  flat <- rep(1, 20)
  result <- .gk_estimate_valley(flat, args)
  expect_true(grepl("^NOT_CALLABLE", result$status))
  result <- .gk_estimate_mixture(rep(NA_real_, 20),
    .gk_method_args("mixture", list(min_n = 10L)))
  expect_true(grepl("^NOT_CALLABLE", result$status))
})

test_that("mixture refuses a component collapsed onto clipped scores", {
  args <- .gk_method_registry()$mixture$args
  x <- withr::with_seed(11, c(stats::rnorm(900), stats::rnorm(100, mean = 8, sd = 1.5)))
  free <- .gk_estimate_mixture(x, args)
  expect_identical(free$status, "CALLABLE")
  clipped <- pmin(pmax(x, -5), 5)
  expect_gt(sum(clipped == 5), 90L)
  collapsed <- .gk_estimate_mixture(clipped, args)
  expect_identical(collapsed$status, "NOT_CALLABLE_NO_SEPARATION")
  expect_true(is.na(collapsed$estimate))
  expect_match(collapsed$details, "tied scores at the bound")
  mirrored <- .gk_estimate_mixture(-clipped, args)
  expect_identical(mirrored$status, "NOT_CALLABLE_NO_SEPARATION")
  # A clipped tail alone does not block a sound fit.
  y <- withr::with_seed(12, c(stats::rnorm(900), stats::rnorm(100, mean = 4.5, sd = 0.6)))
  mild <- .gk_estimate_mixture(pmin(y, 5), args)
  expect_gt(sum(pmin(y, 5) == 5), 5L)
  expect_identical(mild$status, "CALLABLE")
  # Tied scores at a floor or at saturation keep a cut between the modes.
  floored <- withr::with_seed(13, asinh(c(stats::rpois(700, 0.05), stats::rpois(300, 30))))
  expect_gt(mean(floored[floored < 2] == 0), 0.9)
  kept <- .gk_estimate_mixture(floored, args)
  expect_identical(kept$status, "CALLABLE")
  expect_identical(sum((floored > kept$estimate) != rep(c(FALSE, TRUE), c(700L, 300L))), 0L)
  saturated <- withr::with_seed(14,
    pmin(c(stats::rnorm(800, 20, 5), stats::rnorm(200, 300, 30)), 255))
  expect_gt(mean(saturated[saturated > 100] == 255), 0.9)
  expect_identical(.gk_estimate_mixture(saturated, args)$status, "CALLABLE")
  # A cut that hugs a floor is refused like one that hugs a clip.
  hugging <- withr::with_seed(15,
    c(rep(0, 600), abs(stats::rnorm(100, 0, 0.2)), stats::rnorm(300, 3, 0.5)))
  expect_identical(.gk_estimate_mixture(hugging, args)$status, "NOT_CALLABLE_NO_SEPARATION")
  expect_true(.gk_collapsed_at_bound(c(rep(5, 9), 4.99), 5, cut = 4.98, other_mean = 0))
  expect_false(.gk_collapsed_at_bound(c(rep(5, 9), 4), 5, cut = 2.5, other_mean = 0))
  expect_false(.gk_collapsed_at_bound(c(4, 4.5, 5), 5, cut = 4.98, other_mean = 0))
  expect_false(.gk_mostly_tied(numeric(), 1))
  expect_true(.gk_mostly_tied(c(rep(5, 9), 4), 5))
  expect_false(.gk_mostly_tied(c(rep(5, 8), 4, 4), 5))
})

test_that("clipped robust z-scores no longer yield mixture cuts next to the clip", {
  cfg <- gk_example_config()
  prep <- gk_prepare(gk_example_path("example-slide"), cfg, quiet = TRUE)
  th <- as.data.frame(gk_thresholds(prep, cfg, correction = gk_correct(prep, method = "robust_z")))
  expect_false(any(is.finite(th$estimate) & th$estimate > 4.9))
  expect_true(all(c("PanCK", "CD45", "CD3e", "CD4") %in% th$marker[th$status == "CALLABLE"]))
  raw <- as.data.frame(gk_thresholds(prep, cfg))
  expect_identical(sum(raw$status == "CALLABLE"), 8L)
})
