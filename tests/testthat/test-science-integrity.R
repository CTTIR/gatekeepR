gk_science_state_config <- function(method = "manual", args = list(value = 0),
                                    min_cells = 20L, identity_cut = 50,
                                    localization = NULL) {
  gk_config(
    gk_signal_policy(c("A", "S")),
    gk_panel(c("A", "S"), role = c("identity", "state"), transform = "none",
      threshold_method = c("manual", method),
      threshold_args = list(A = list(value = identity_cut), S = args),
      parents = list(S = "P"), localization = localization,
      min_support = gk_min_support(min_cells = min_cells)),
    hierarchy = gk_hierarchy(list(gk_rule("R1", "A cells", all_of = "A")),
      version = "test"), parent_sets = list(P = "A cells")
  )
}

gk_science_states <- function(prepared) {
  cfg <- prepared$config
  th <- gk_thresholds(prepared, cfg)
  cl <- gk_classify(prepared, th, cfg)
  gk_state_calls(prepared, th, cl, cfg)
}

test_that("corrections preserve unavailable cells and support on other images", {
  cfg <- gk_test_config(c("A", "B"), method = "manual", transform = "none",
    threshold_args = list(value = 0))
  vals <- list(A = c(NA, 1:99, rep(0, 100)), B = seq_len(200))
  prep <- gk_prepare(gk_test_cellspec(vals,
    image_id = rep(c("supported", "absent"), each = 100)), cfg, quiet = TRUE)
  for (method in c("none", "robust_z", "common_score_residual", "pc1_panel_residual")) {
    corrected <- gk_correct(prep, method)
    expect_true(is.na(corrected$matrix[1, "A"]), info = method)
    expect_true(all(is.finite(corrected$matrix[2:100, "A"])), info = method)
    expect_true(all(is.na(corrected$matrix[101:200, "A"])), info = method)
    expect_identical(gk_correct(prep, corrected$model)$matrix, corrected$matrix)
    th <- gk_thresholds(prep, cfg, correction = corrected)
    cl <- suppressWarnings(gk_classify(prep, th, cfg, correction = corrected))
    expect_false(cl$calls[1, "A"])
    expect_true(all(is.na(cl$calls[101:200, "A"])))
  }
  z <- gk_correct(prep, "robust_z")
  # Independent robust-z oracle uses only the 99 observed supported values.
  expect_equal(unname(z$matrix[2:100, "A"]), (1:99 - 50) / stats::mad(1:99))
  none <- gk_correct(prep, "none")
  expect_identical(none$matrix[2:100, "A"], prep$score[2:100, "A"])
})

test_that("manual identity cuts cannot bypass raw support", {
  cfg <- gk_test_config("A", method = "manual", transform = "none",
    threshold_args = list(value = 0))
  prep <- gk_prepare(gk_test_cellspec(list(A = rep(0, 100))), cfg, quiet = TRUE)
  th <- gk_thresholds(prep, cfg)
  th$status <- "MANUAL"
  th$estimate <- 0
  cl <- suppressWarnings(gk_classify(prep, th, cfg))
  expect_true(all(is.na(cl$calls)))
  expect_equal(nrow(cl$disabled_rules), 1L)
})

test_that("reapplying a correction respects a requested marker subset", {
  cfg <- gk_test_config(c("A", "B"), method = "manual", transform = "none",
    threshold_args = list(value = 0))
  prep <- gk_prepare(gk_test_cellspec(list(A = 1:100, B = 101:200)), cfg, quiet = TRUE)
  full <- gk_correct(prep, "robust_z")
  subset <- gk_correct(prep, full$model, markers = "A")
  expect_identical(subset$matrix[, "A"], full$matrix[, "A"])
  expect_identical(subset$matrix[, "B"], prep$score[, "B"])
  expect_identical(gk_correct(prep, subset$model)$matrix, subset$matrix)
  damaged <- full$model
  damaged$matrix[1, "A"] <- 999
  expect_error(gk_correct(prep, damaged), class = "gatekeepr_error_state")
  legacy <- full$model
  legacy$data_hash_version <- NULL
  expect_error(gk_correct(prep, legacy), "regenerate")
})

test_that("absent state channels and nonfinite localization cannot become positive", {
  cfg <- gk_science_state_config()
  prep <- gk_prepare(gk_test_cellspec(list(A = 1:100, S = rep(0, 100))), cfg, quiet = TRUE)
  states <- gk_science_states(prep)
  expect_identical(states$state_thresholds$status, "NOT_CALLABLE_ABSENT")
  expect_false(any(states$calls$positive))
  expect_false(any(states$calls$evaluable))

  cfg <- gk_science_state_config(localization = list(S = list(
    numerator = "nucleus", denominator = "cytoplasm", min_ratio = 1.5)))
  prep <- gk_prepare(gk_test_cellspec(list(A = 1:100, S = 1:100,
    "nucleus:S" = 1:100, "cytoplasm:S" = rep(-1e-9, 100))), cfg, quiet = TRUE)
  expect_true(all(is.na(prep$localization$S$ratio)))
  expect_false(any(prep$localization$S$evaluable))
  states <- gk_science_states(prep)
  expect_false(any(states$calls$positive))
  expect_false(any(states$calls$evaluable))
})

test_that("state methods use parent data and honor method arguments", {
  for (method in c("valley", "tail", "mixture")) {
    cfg <- gk_science_state_config(method, list(min_n = 1000L))
    prep <- gk_prepare(gk_test_cellspec(list(A = 1:100, S = 1:100)), cfg, quiet = TRUE)
    states <- gk_science_states(prep)
    expect_identical(states$state_thresholds$status, "NOT_CALLABLE_UNDERPOWERED", info = method)
    expect_true(is.na(states$state_thresholds$estimate))
    expect_false(any(states$calls$positive))
  }
  withr::local_seed(9)
  vals <- c(stats::rnorm(120, 2, .15), stats::rnorm(120, 8, .15),
    stats::rnorm(120, 15, .15))
  cfg <- gk_science_state_config("valley", list(min_n = 100L), identity_cut = 121)
  # The parent is the first 240 cells; the outside high mode must not fit it.
  prep <- gk_prepare(gk_test_cellspec(list(A = 360:1, S = vals)), cfg, quiet = TRUE)
  states <- gk_science_states(prep)
  expect_identical(states$state_thresholds$rule, "valley")
  expect_identical(states$state_thresholds$status, "CALLABLE")
  expect_gt(states$state_thresholds$estimate, 3)
  expect_lt(states$state_thresholds$estimate, 7)
  expect_equal(sum(states$calls$positive), 120L)
})

test_that("minimum pool support is enforced for identity and state estimates", {
  withr::local_seed(23)
  values <- c(stats::rnorm(920, 2, .15), stats::rnorm(80, 8, .15))
  for (method in c("mixture", "valley", "tail")) {
    cfg <- gk_test_config("A", method = method, transform = "none",
      min_support = gk_min_support(min_cells = 100L))
    prep <- gk_prepare(gk_test_cellspec(list(A = values)), cfg, quiet = TRUE)
    th <- gk_thresholds(prep, cfg)
    expect_identical(th$status, "NOT_CALLABLE_UNDERPOWERED", info = method)
    expect_lt(th$n_positive_pool, 100L)
    expect_true(is.na(th$estimate))
  }
  cfg <- gk_science_state_config("parent_crossing", list(), min_cells = 50L, identity_cut = 99)
  prep <- gk_prepare(gk_test_cellspec(list(A = 1:100, S = 1:100)), cfg, quiet = TRUE)
  states <- gk_science_states(prep)
  expect_identical(states$state_thresholds$status, "NOT_CALLABLE_UNDERPOWERED")
  expect_equal(states$state_thresholds$n_positive_pool, 2L)
  expect_false(any(states$calls$positive))
})

test_that("mixture overlap is measured at the reported decision boundary", {
  withr::local_seed(42)
  values <- c(stats::rnorm(8000), stats::rnorm(8000, 1.7))
  args <- .gk_method_args("mixture", list(max_overlap = .3))
  fit <- .gk_estimate_mixture(values, args)
  expect_identical(fit$status, "CALLABLE")
  ev <- fit$evidence
  expected <- c(stats::pnorm(fit$estimate, ev$means[1], ev$sds[1], lower.tail = FALSE),
    stats::pnorm(fit$estimate, ev$means[2], ev$sds[2]))[which.min(ev$weights)]
  expect_equal(ev$overlap, expected)
  expect_gt(expected, .2)
  expect_identical(.gk_estimate_mixture(values, modifyList(args, list(max_overlap = .2)))$status,
    "NOT_CALLABLE_NO_SEPARATION")
})

test_that("source, score-space and row alignment are bound through classification", {
  cfg <- gk_science_state_config()
  prep <- gk_prepare(gk_test_cellspec(list(A = 1:100, S = 1:100)), cfg, quiet = TRUE)
  other <- gk_prepare(gk_test_cellspec(list(A = 101:200, S = 1:100)), cfg, quiet = TRUE)
  th <- gk_thresholds(prep, cfg)
  co <- gk_correct(prep, "robust_z")
  expect_error(gk_thresholds(other, cfg, correction = co), class = "gatekeepr_error_state")
  expect_error(gk_classify(other, th, cfg), class = "gatekeepr_error_state")
  expect_error(gk_classify(prep, th, cfg, correction = co), "score space")
  corrected_th <- gk_thresholds(prep, cfg, correction = co)
  cl <- gk_classify(prep, corrected_th, cfg, correction = co)
  expect_s3_class(gk_state_calls(prep, corrected_th, cl, cfg), "gk_state_calls")
  altered <- co
  altered$matrix <- altered$matrix[100:1, , drop = FALSE]
  expect_error(gk_thresholds(prep, cfg, correction = altered), class = "gatekeepr_error_state")
  altered <- co
  colnames(altered$matrix) <- rev(colnames(altered$matrix))
  expect_error(gk_classify(prep, corrected_th, cfg, correction = altered), class = "gatekeepr_error_state")
  raw_cl <- gk_classify(prep, th, cfg)
  expect_error(gk_state_calls(other, th, raw_cl, cfg), class = "gatekeepr_error_state")
  altered_cl <- raw_cl
  altered_cl$cells$cell_type[1] <- "A cells"
  expect_error(gk_state_calls(prep, th, altered_cl, cfg), class = "gatekeepr_error_state")
  raw_cl$cells <- raw_cl$cells[100:1, ]
  expect_error(gk_state_calls(prep, th, raw_cl, cfg), class = "gatekeepr_error_state")
  duplicate <- th[c(1L, 1L), ]
  expect_error(gk_classify(prep, duplicate, cfg), class = "gatekeepr_error_state")
})

test_that("embedding populations require source and ordered score-space provenance", {
  cfg <- gk_test_config("A", method = "population_crossing", transform = "none")
  prep <- gk_prepare(gk_test_cellspec(list(A = 1:100)), cfg, quiet = TRUE)
  expect_error(.gk_embedding_matrix(prep, list(matrix = prep$score)), class = "gatekeepr_error_input")
  population <- stats::setNames(rep(c(1L, 2L), each = 50), prep$cells$cell_id)
  embedding <- structure(list(population = population,
    source_sha256 = prep$source_sha256, config_sha256 = prep$config_sha256,
    cell_keys = .gk_cell_keys(prep$cells), score_sha256 = .gk_score_hash(prep, prep$score),
    population_sha256 = .gk_sha256_object(population)), class = "gk_embedding")
  expect_s3_class(gk_thresholds(prep, cfg, embedding = embedding), "gk_thresholds")
  embedding$population <- rev(embedding$population)
  expect_error(gk_thresholds(prep, cfg, embedding = embedding), class = "gatekeepr_error_state")
})

test_that("sample metadata contributes to source identity and empty states stay typed", {
  cfg <- gk_test_config("A", method = "manual", threshold_args = list(value = 0))
  slide <- gk_test_cellspec(list(A = 1:100))
  prep <- gk_prepare(slide, cfg, quiet = TRUE)
  slide$cells$sample_id <- "another-sample"
  other <- gk_prepare(slide, cfg, quiet = TRUE)
  expect_false(identical(prep$source_sha256, other$source_sha256))
  th <- gk_thresholds(prep, cfg)
  cl <- gk_classify(prep, th, cfg)
  states <- gk_state_calls(prep, th, cl, cfg)
  expect_equal(nrow(states$calls), 0L)
  expect_named(states$calls, c("image_id", "cell_id", "marker", "parent", "in_parent",
    "evaluable", "score", "estimate", "localization_ratio", "positive", "enabled"))
  expect_equal(nrow(states$state_thresholds), 0L)
})

test_that("measurement dictionary semantics contribute to source identity", {
  cfg <- gk_test_config(c("A", "B"), method = "manual", transform = "none",
    threshold_args = list(value = 50))
  slide <- gk_test_cellspec(list(A = 1:100, B = 101:200))
  prep <- gk_prepare(slide, cfg, quiet = TRUE)
  # Keep identical feature IDs and measurement bytes but exchange their marker meaning.
  slide$dictionary$marker <- rev(slide$dictionary$marker)
  other <- gk_prepare(slide, cfg, quiet = TRUE)
  expect_false(identical(prep$score, other$score))
  expect_false(identical(prep$source_sha256, other$source_sha256))
  expect_error(gk_thresholds(other, cfg, correction = gk_correct(prep, "none")),
    class = "gatekeepr_error_state")
})

test_that("composite cell keys distinguish images and embedded separators", {
  cells <- data.frame(image_id = c("slide-1", "slide-2", "a:b", "a", "a\nb", "a"),
    cell_id = c("cell-1", "cell-1", "c", "b:c", "c", "b\nc"))
  expect_equal(length(unique(.gk_cell_key(cells))), nrow(cells))
  expect_identical(.gk_cell_key(cells[FALSE, ]), character())
})
