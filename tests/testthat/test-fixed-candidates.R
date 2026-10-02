parameter_fixture <- function() {
  robust <- function(markers) list(
    center = stats::setNames(rep(0, length(markers)), markers),
    scale = stats::setNames(rep(1, length(markers)), markers),
    fallback = stats::setNames(rep(FALSE, length(markers)), markers), clip = c(-5, 5))
  list(panel = c("A", "B", "C"), identity_markers = c("A", "B"),
    identity_robust = robust(c("A", "B")),
    identity_regression = matrix(0, 2, 2, dimnames = list(NULL, c("A", "B"))),
    identity_center = c(A = 0, B = 0), identity_scale = c(A = 1, B = 1),
    panel_robust = robust(c("A", "B", "C")), pc_center = c(A = 0, B = 0),
    pc1_rotation = c(A = 1, B = 0),
    panel_regression = matrix(0, 2, 3, dimnames = list(NULL, c("A", "B", "C"))),
    panel_center = c(A = 0, B = 0, C = 0), panel_scale = c(A = 1, B = 1, C = 1),
    n_training = 20L)
}

test_that("external frozen parameters authenticate source and reproduce literal arithmetic", {
  path <- withr::local_tempfile()
  writeLines("synthetic external authority", path)
  hash <- digest::digest(file = path, algo = "sha256")
  params <- parameter_fixture()
  model <- gk_import_residual_model(params, path, hash)
  x <- matrix(c(2, 4, 5, 1, 3, NA), 2, 3, byrow = TRUE,
    dimnames = list(c("one", "two"), c("A", "B", "C")))
  value <- gk_apply_residual_model(x, model)
  expect_equal(unname(value$identity), matrix(c(-1, 1, -1, 1), 2, byrow = TRUE))
  expect_equal(unname(value$gate), matrix(c(-1, 1, 2, -1, 1, NA), 2, byrow = TRUE))
  expect_identical(gk_apply_residual_model(x[2:1, ], model)$gate[2:1, ], value$gate)
  expect_error(gk_import_residual_model(params, path, strrep("0", 64)))
  bad <- params
  bad$identity_scale[1] <- 0
  expect_error(gk_import_residual_model(bad, path, hash))
  bad <- params
  bad$pc_center <- rev(bad$pc_center)
  expect_error(gk_import_residual_model(bad, path, hash))
  model$panel_center[1] <- 1
  expect_error(gk_apply_residual_model(x, model))
})

test_that("fixed signal calls preserve unavailable scores and source support", {
  ids <- paste0("c", 1:4)
  selected <- cbind(A = c(1, 2, 3, 4), B = rep(10, 4))
  rownames(selected) <- ids
  sources <- matrix(rep(c("fa", "fb"), each = 4), 4,
    dimnames = dimnames(selected))
  raw <- selected
  colnames(raw) <- c("fa", "fb")
  scores <- matrix(c(-1, 0, 1, NA, 1, -1), 3, 2,
    dimnames = list(ids[1:3], c("A", "B")))
  calls <- gk_fixed_signal_calls(scores, selected, sources, raw,
    cutoffs = c(A = 0, B = 0), enabled = c(A = TRUE, B = TRUE), min_finite = 2L)
  expect_identical(unname(calls$calls[, "A"]), c("LOW", "HIGH", "HIGH"))
  expect_true(all(calls$calls[, "B"] == "UNAVAILABLE"))
  scores[1, "A"] <- NA_real_
  calls <- gk_fixed_signal_calls(scores, selected, sources, raw,
    c(A = 0, B = 0), c(A = TRUE, B = TRUE), min_finite = 2L)
  expect_identical(calls$calls[1, "A"], "UNAVAILABLE")
  sources[1, "A"] <- "foreign"
  expect_error(gk_fixed_signal_calls(scores, selected, sources, raw,
    c(A = 0, B = 0), c(A = TRUE, B = TRUE), min_finite = 2L))
})

test_that("declarative ternary rules use explicit allowed states and last-match precedence", {
  calls <- matrix(c("HIGH", "LOW", "HIGH", "HIGH", "UNAVAILABLE", "LOW",
    "LOW", "UNAVAILABLE"), 4, byrow = TRUE,
    dimnames = list(letters[1:4], c("A", "B")))
  rules <- list(
    list(id = "first", label = "a", all = list(A = "HIGH")),
    list(id = "second", label = "b", any = list(B = "HIGH")),
    list(id = "missing", label = "unknown", all = list(A = "UNAVAILABLE")))
  value <- gk_apply_candidate_rules(calls, rules, "default")
  expect_identical(value$label, c("a", "b", "unknown", "default"))
  expect_false(any(value$production_eligible))
  expect_false(any(value$review_authorized))
  bad <- rules
  bad[[1]]$all <- list(foreign = "HIGH")
  expect_error(gk_apply_candidate_rules(calls, bad, "default"))
  bad <- rules
  bad[[1]]$all <- list(A = "MISSING")
  expect_error(gk_apply_candidate_rules(calls, bad, "default"))
  expect_equal(nrow(gk_apply_candidate_rules(calls[FALSE, ], rules, "default")), 0)
})

test_that("source support cannot be borrowed across features or row keys", {
  selected <- matrix(c(1, 2, 3, 4), 4, 1,
    dimnames = list(letters[1:4], "A"))
  raw <- cbind(variable = 1:4, constant = rep(2, 4))
  rownames(raw) <- letters[1:4]
  sources <- matrix(c("variable", "constant", NA, "variable"), 4, 1,
    dimnames = dimnames(selected))
  scores <- selected[c(4, 2, 1, 3), , drop = FALSE]
  run <- function(...) gk_fixed_signal_calls(scores, selected, sources, raw,
    c(A = 2), c(A = TRUE), ...)
  value <- run(min_finite = 2L)
  expect_identical(unname(value$calls[, 1]), c("HIGH", "UNAVAILABLE", "LOW", "UNAVAILABLE"))
  expect_true(all(run(min_finite = 5L)$calls == "UNAVAILABLE"))
  expect_error(run(min_finite = 1L))
  expect_error(run(min_finite = NA_real_))
  disabled <- gk_fixed_signal_calls(scores, selected, sources, raw,
    c(A = 2), c(A = FALSE), min_finite = 2L)
  expect_true(all(disabled$calls == "UNAVAILABLE"))
  unavailable_cut <- gk_fixed_signal_calls(scores, selected, sources, raw,
    c(A = NA_real_), c(A = TRUE), min_finite = 2L)
  expect_true(all(unavailable_cut$calls == "UNAVAILABLE"))
  rownames(raw) <- rev(rownames(raw))
  expect_error(run(min_finite = 2L))
})

test_that("ternary rules exhaustively preserve unknown rather than interpreting it as low", {
  states <- c("HIGH", "LOW", "UNAVAILABLE")
  grid <- expand.grid(A = states, B = states, stringsAsFactors = FALSE)
  calls <- as.matrix(grid)
  rownames(calls) <- paste0("r", seq_len(nrow(calls)))
  rules <- list(list(id = "both", label = "selected", all = list(A = "HIGH", B = "LOW")))
  out <- gk_apply_candidate_rules(calls, rules, "not_selected")
  expect_identical(which(out$label == "selected"), 4L)
  expect_identical(out$rule_id[4], "both")
  expect_true(all(is.na(out$rule_id[-4])))
  expect_error(gk_apply_candidate_rules(calls, c(rules, rules), "default"))
  rules[[1]]$unexpected <- TRUE
  expect_error(gk_apply_candidate_rules(calls, rules, "default"))
})

test_that("a finite selected value cannot turn missing source measurement into a call", {
  x <- matrix(1:4, 4, 1, dimnames = list(letters[1:4], "A"))
  raw <- x
  colnames(raw) <- "source"
  raw[1, 1] <- NA_real_
  sources <- matrix("source", 4, 1, dimnames = dimnames(x))
  result <- gk_fixed_signal_calls(x, x, sources, raw, c(A = 2), c(A = TRUE), 2L)
  expect_identical(unname(result$calls[, 1]), c("UNAVAILABLE", "HIGH", "HIGH", "HIGH"))
})

test_that("external vector parameters reject disguised arrays without changing coefficients", {
  path <- withr::local_tempfile()
  writeLines("synthetic source", path)
  hash <- digest::digest(file = path, algo = "sha256")
  for (field in c("identity_center", "identity_scale", "pc_center", "pc1_rotation",
                  "panel_center", "panel_scale")) {
    params <- parameter_fixture()
    v <- params[[field]]
    params[[field]] <- matrix(v, nrow = 1L)
    names(params[[field]]) <- names(v)
    expect_error(gk_import_residual_model(params, path, hash))
  }
  for (prefix in c("identity_robust", "panel_robust")) {
    for (field in c("center", "scale")) {
      params <- parameter_fixture()
      v <- params[[prefix]][[field]]
      params[[prefix]][[field]] <- matrix(v, nrow = 1L)
      names(params[[prefix]][[field]]) <- names(v)
      expect_error(gk_import_residual_model(params, path, hash))
    }
  }
})
