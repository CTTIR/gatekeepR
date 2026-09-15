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
