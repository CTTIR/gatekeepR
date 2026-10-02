test_that("fixed thresholds distinguish equality, unavailable and disabled", {
  x <- matrix(c(-1, 0, NA, Inf), 4, 1, dimnames = list(letters[1:4], "A"))
  expect_identical(as.vector(gk_fixed_threshold_calls(x, c(A = 0), c(A = TRUE))),
    c("LOW", "HIGH", "UNAVAILABLE", "UNAVAILABLE"))
  expect_true(all(gk_fixed_threshold_calls(x, c(A = 0), c(A = FALSE)) == "UNAVAILABLE"))
  expect_error(gk_fixed_threshold_calls(x, c(B = 0), c(A = TRUE)), "dictionary")
  bad <- matrix(0, 1, 1); names(bad) <- "A"
  expect_error(gk_fixed_threshold_calls(x, bad, c(A = TRUE)), "dictionary")
})

test_that("state diagnostics preserve missingness, parents and boundary localization", {
  x <- matrix(c(2, 2, NA, 2, 2, 2), 6, 1, dimnames = list(letters[1:6], "S"))
  par <- matrix(c(TRUE, FALSE, TRUE, NA, TRUE, TRUE), 6, 1, dimnames = dimnames(x))
  a <- gk_fixed_state_diagnostics(x, c(S = 2), par, audit_missing = c(S = "propagate"))
  expect_identical(a$audit_positive, c(TRUE, FALSE, NA, NA, TRUE, TRUE))
  expect_identical(a$nullable_positive, c(TRUE, NA, NA, NA, TRUE, TRUE))
  expect_false(any(a$review_authorized | a$production_eligible))
  expect_identical(a$diagnostic_status[2:4], c("PARENT_INELIGIBLE_OR_UNKNOWN",
    "UNAVAILABLE_MEASUREMENT_OR_LOCALIZATION", "PARENT_INELIGIBLE_OR_UNKNOWN"))
  num <- matrix(c(3, 3, 3, 3, 2, 3), 6, 1, dimnames = dimnames(x))
  den <- matrix(c(2, 2, 2, 2, 2, NA), 6, 1, dimnames = dimnames(x))
  b <- gk_fixed_state_diagnostics(x, c(S = 2), par, num, den, c(S = 1.5), 0,
    c(S = "false"))
  expect_identical(b$audit_positive, c(TRUE, FALSE, FALSE, NA, FALSE, FALSE))
  expect_identical(b$nullable_positive, c(TRUE, NA, NA, NA, FALSE, NA))
  den[1, 1] <- 0
  c <- gk_fixed_state_diagnostics(x, c(S = NA_real_), par, num, den, c(S = 1.5), 0,
    c(S = "false"))
  expect_true(all(is.na(c$nullable_positive)))
  expect_identical(c$diagnostic_status[1], "UNAVAILABLE_MEASUREMENT_OR_LOCALIZATION")
  expect_identical(c$diagnostic_status[2], "UNAVAILABLE_THRESHOLD")
  expect_error(gk_fixed_state_diagnostics(x, c(S = 2), par[, 1],
    audit_missing = c(S = "false")), "Parent")
  expect_error(gk_fixed_state_diagnostics(x, c(S = 2), par,
    localization_minimum = c(S = 1.5), audit_missing = c(S = "false")), "Localization")
  expect_error(gk_fixed_state_diagnostics(x, c(S = 2), par,
    audit_missing = c(S = "invent")), "missingness")
})

test_that("empty state rows and invalid localization dictionaries are explicit", {
  x <- matrix(numeric(), 0, 1, dimnames = list(character(), "S"))
  p <- matrix(logical(), 0, 1, dimnames = dimnames(x))
  a <- gk_fixed_state_diagnostics(x, c(S = 1), p, audit_missing = c(S = "false"))
  expect_equal(nrow(a), 0)
  expect_equal(nrow(gk_fixed_state_diagnostics(x, c(S = NA_real_), p,
    audit_missing = c(S = "false"))), 0)
  expect_identical(names(a), c("cell_id", "state", "audit_positive", "measurement_evaluable",
    "parent_eligible", "threshold_available", "diagnostic_status", "nullable_positive",
    "review_authorized", "production_eligible"))
  expect_error(gk_fixed_state_diagnostics(x, c(S = 1), p,
    localization_minimum = c(S = Inf), audit_missing = c(S = "false")), "minima")
  expect_error(gk_fixed_state_diagnostics(x, c(S = 1), p,
    localization_offset = -1, audit_missing = c(S = "false")), "offset")
  expect_error(gk_fixed_state_diagnostics(x, c(S = 1), p,
    localization_numerator = x, audit_missing = c(S = "false")), "without")
})

test_that("offset overflow cannot become an evaluable negative", {
  x <- matrix(1, 1, 1, dimnames = list("a", "S"))
  p <- matrix(TRUE, 1, 1, dimnames = dimnames(x))
  a <- gk_fixed_state_diagnostics(x, c(S = 0), p, x, x * 1e308,
    c(S = .25), 1e308, c(S = "false"))
  expect_false(a$measurement_evaluable)
  expect_false(a$audit_positive)
  expect_identical(a$nullable_positive, NA)
  expect_identical(a$diagnostic_status, "UNAVAILABLE_MEASUREMENT_OR_LOCALIZATION")
  empty <- matrix(numeric(), 1, 0, dimnames = list("a", character()))
  ep <- matrix(logical(), 1, 0, dimnames = dimnames(empty))
  expect_error(gk_fixed_state_diagnostics(empty, setNames(numeric(), character()), ep,
    audit_missing = setNames(character(), character())), "matrix keys")
})

test_that("every nonfinite measurement obeys the audit missingness policy", {
  x <- matrix(c(Inf, -Inf, NaN, NA_real_), 4, 1,
    dimnames = list(letters[1:4], "S"))
  p <- matrix(TRUE, 4, 1, dimnames = dimnames(x))
  a <- gk_fixed_state_diagnostics(x, c(S = 0), p, audit_missing = c(S = "propagate"))
  b <- gk_fixed_state_diagnostics(x, c(S = 0), p, audit_missing = c(S = "false"))
  expect_identical(a$audit_positive, rep(NA, 4))
  expect_identical(b$audit_positive, rep(FALSE, 4))
  expect_identical(a$nullable_positive, rep(NA, 4))
  expect_false(any(a$measurement_evaluable))
  p[,] <- FALSE
  c <- gk_fixed_state_diagnostics(x, c(S = 0), p, audit_missing = c(S = "propagate"))
  expect_identical(c$audit_positive, rep(FALSE, 4))
  y <- x; y[,] <- 1
  p[,] <- TRUE
  d <- gk_fixed_state_diagnostics(y, c(S = 0), p, y, x, c(S = .5), 0,
    c(S = "propagate"))
  expect_identical(d$audit_positive, rep(NA, 4))
  expect_identical(d$nullable_positive, rep(NA, 4))
})
