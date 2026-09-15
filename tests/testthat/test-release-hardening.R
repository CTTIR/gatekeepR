test_that("threshold estimators cover separated and rejected pools", {
  withr::local_seed(19L)
  bimodal <- c(stats::rnorm(120, 0, 0.25), stats::rnorm(120, 4, 0.25))
  valley_args <- .gk_method_args("valley", list(min_n = 20L, grid_n = 256L))
  tail_args <- .gk_method_args("tail", list(min_n = 20L, grid_n = 256L))
  mixture_args <- .gk_method_args("mixture", list(min_n = 20L, max_iter = 100L))

  expect_identical(.gk_finite_values(rep(1, 20), 10L), NULL)
  expect_identical(.gk_finite_values(c(NA_real_, 1), 3L), NULL)
  expect_true(is.null(.gk_density(c(1, 1), valley_args)))
  density <- stats::density(bimodal, n = 256L)
  expect_true(length(.gk_density_modes(density, 0.01)) >= 2L)
  expect_true(is.na(.gk_auc_rank(numeric(), bimodal)))
  expect_true(is.finite(.gk_auc_rank(bimodal[1:20], bimodal[121:140])))

  valley <- .gk_estimate_valley(bimodal, valley_args)
  tail <- .gk_estimate_tail(c(stats::rnorm(300, 0, 0.3), stats::rexp(100) + 1), tail_args)
  mixture <- .gk_estimate_mixture(bimodal, mixture_args)
  expect_true(is.list(.gk_density(bimodal, valley_args)))
  expect_true(grepl("NOT_CALLABLE", .gk_estimate_valley(
    stats::rnorm(200), modifyList(valley_args, list(min_depth = 0.99))
  )$status))
  expect_true(grepl("NOT_CALLABLE", .gk_estimate_tail(
    stats::rnorm(200), modifyList(tail_args, list(min_tail_excess = 100))
  )$status))
  expect_true(grepl("UNDERPOWERED", .gk_estimate_population_crossing(
    c(1, 2), c("negative", "positive"), .gk_method_args("population_crossing", list()),
    0.5, 1L
  )$status))
  expect_true(is.na(.gk_crossing(c(1, 1), c(1, 1))))
  expect_identical(valley$status, "CALLABLE")
  expect_identical(tail$status, "CALLABLE")
  expect_identical(mixture$status, "CALLABLE")
  expect_identical(.gk_no_separation()$n_positive_pool, 0L)
  expect_true(grepl("NOT_CALLABLE", .gk_estimate_tail(rep(1, 20), tail_args)$status))
})

test_that("threshold wrappers cover configured method branches", {
  values <- c(stats::rnorm(100, 2, 0.2), stats::rnorm(100, 6, 0.2))
  for (method in c("valley", "tail", "mixture")) {
    cfg <- gk_test_config(markers = "A", method = method)
    prep <- gk_prepare(gk_test_cellspec(list(A = values)), cfg, quiet = TRUE)
    out <- gk_thresholds(prep, cfg, seed = 1L)
    expect_identical(out$method, method)
  }
  cfg <- gk_test_config(markers = "A", method = "population_crossing")
  prep <- gk_prepare(gk_test_cellspec(list(A = values)), cfg, quiet = TRUE)
  embedding <- structure(
    list(population = rep(c("negative", "positive"), each = 100)),
    class = "gk_embedding"
  )
  out <- gk_thresholds(prep, cfg, embedding = embedding, seed = 1L)
  expect_identical(out$status, "CALLABLE")
  expect_true(all(c("manual", "parent_crossing") %in% gk_threshold_methods()$method))
})

test_that("state and embedding helpers cover reference, localization and basin paths", {
  cfg <- gk_example_config()
  prep <- gk_example_prepared()
  args <- .gk_method_args("parent_crossing", list(n_grid = 128L), role = "state")
  labels <- c(rep("CD4 T cells", 60), rep("Other immune cells", 60))
  values <- c(stats::rnorm(60, 4, 0.2), stats::rnorm(60, 0, 0.2))
  estimate <- .gk_state_estimate(
    values, labels == "CD4 T cells", labels, cfg, "FOXP3", "CD4 T cells",
    "parent_crossing", args, 0.5
  )
  expect_identical(estimate$status, "CALLABLE")
  args$reference <- "Immune"
  expect_true(is.character(.gk_state_reference_labels(cfg, "FOXP3", "CD4 T cells", args)))
  expect_identical(.gk_state_localization(prep, "CD4")$min_ratio, 0)
  embedding_input <- .gk_embedding_matrix(prep, NULL)
  expect_true(length(embedding_input$markers) > 0L)
  expect_true(is.matrix(.gk_embedding_matrix(prep, list(matrix = prep$score))$matrix))
  expect_error(.gk_embedding_matrix(prep, list()), class = "gatekeepr_error_input")
  expect_true(is.matrix(.gk_embedding_kde(matrix(rnorm(40), ncol = 2), 10L, 0.03)$density))
  expect_length(.gk_grid_neighbours(1L, 3L, 3L), 4L)
  hill <- .gk_hillclimb_basins(matrix(c(0, 1, 0, 1, 2, 1, 0, 1, 0), 3L, 3L))
  expect_true(is.matrix(hill$labels))
  kde <- list(x = 1:3, y = 1:3, density = matrix(1, 3L, 3L))
  basins <- list(labels = matrix(c(1L, 1L, 2L, 1L, 1L, 2L, 2L, 2L, 2L), 3L, 3L))
  points <- matrix(c(1, 1, 2, 2, 3, 3, 2, 1), ncol = 2L, byrow = TRUE)
  uncertain <- .gk_assign_basins(points, kde, basins, "uncertain", 10L, 1)
  merged <- .gk_assign_basins(points, kde, basins, "merge", 10L, 1)
  expect_true(all(is.na(uncertain$population) | is.finite(uncertain$population)))
  expect_true(any(is.finite(merged$population)))
})

test_that("review actions cover bbox, state, and inverse ledger paths", {
  review <- gk_example_review()
  image_id <- unique(review$prepared$cells$image_id)
  cell_id <- review$prepared$cells$cell_id[[1L]]
  bbox <- range(review$prepared$cells$x)
  y_range <- range(review$prepared$cells$y)
  box <- c(bbox[[1L]], bbox[[2L]], y_range[[1L]], y_range[[2L]])

  boxed <- gk_decide_structure(review, image_id, bbox = box, decision = "Unresolved",
    reviewer = "reviewer-01", reason = "bbox review")
  boxed <- gk_dispose(boxed, image_id, bbox = box, disposition = "DELETE",
    reviewer = "reviewer-01", reason = "bbox exclusion")
  boxed <- gk_set_state(boxed, image_id, "FOXP3", "CD4 T cells", action = "ENABLE",
    reviewer = "reviewer-01", reason = "state review")
  boxed <- gk_set_state(boxed, image_id, "FOXP3", "CD4 T cells", action = "SET_CUT",
    estimate = 0.2, reviewer = "reviewer-01", reason = "state cut")
  replayed <- gk_replay(boxed)
  expect_true(any(replayed$cells$disposition_effective == "DELETE"))
  cut_state <- gk_set_state(review, image_id, "FOXP3", "CD4 T cells", action = "SET_CUT",
    estimate = 0.2, reviewer = "reviewer-01", reason = "state cut")
  expect_true(any(gk_replay(cut_state)$state_calls$estimate == 0.2))
  enabled_state <- gk_set_state(review, image_id, "FOXP3", "CD4 T cells", action = "ENABLE",
    reviewer = "reviewer-01", reason = "state enable")
  expect_true(any(gk_replay(enabled_state)$state_calls$enabled))

  cut <- gk_set_cut(review, image_id, "PanCK", estimate = 0.2,
    reviewer = "reviewer-01", reason = "cut")
  expect_equal(nrow(gk_ledgers(gk_revert_last(cut, "reviewer-01", "undo cut"))$cut_log), 2L)
  structure <- gk_decide_structure(review, image_id,
    structure_id = review$structures$structures$structure_id[[1L]], decision = "Tumor",
    reviewer = "reviewer-01", reason = "structure")
  expect_equal(nrow(gk_ledgers(gk_revert_last(structure, "reviewer-01", "undo structure"))$structure_log), 2L)
  disposition <- gk_dispose(review, image_id, cell_id = cell_id, disposition = "DELETE",
    reviewer = "reviewer-01", reason = "delete")
  expect_equal(nrow(gk_ledgers(gk_revert_last(disposition, "reviewer-01", "undo delete"))$disposition_log), 2L)
  state <- gk_set_state(review, image_id, "FOXP3", "CD4 T cells", action = "ENABLE",
    reviewer = "reviewer-01", reason = "enable")
  expect_equal(nrow(gk_ledgers(gk_revert_last(state, "reviewer-01", "undo enable"))$state_log), 2L)
  expect_error(gk_revert_last(review, "reviewer-01", "nothing"), class = "gatekeepr_error_ledger")
})

test_that("public print and plot dispatch paths remain callable", {
  review <- gk_example_review()
  snapshot <- gk_lock(review, reviewer = "reviewer-01")
  expect_invisible(print(review))
  expect_invisible(print(snapshot))
  expect_invisible(print(gk_replay(review)))
  expect_invisible(print(review$thresholds))
  expect_invisible(print(review$state_calls))
  skip_if_not_installed("ggplot2")
  expect_s3_class(plot(review), "ggplot")
  expect_s3_class(plot(snapshot), "ggplot")
})

test_that("classification helpers and correction models cover alternate contracts", {
  prep <- gk_example_prepared()
  cfg <- gk_example_config()
  thresholds <- gk_thresholds(prep, cfg, seed = 1L)
  fixed <- gk_correct(prep, method = "robust_z")
  classified <- suppressWarnings(gk_classify(prep, thresholds, cfg, correction = fixed))
  expect_s3_class(classified, "gk_classification")
  expect_identical(gk_callability(classified), thresholds)
  expect_identical(gk_callability(thresholds), thresholds)
  expect_identical(gk_callability(gk_example_review()$state_calls),
    gk_example_review()$state_calls$state_thresholds)
  expect_error(gk_callability(list()), class = "gatekeepr_error_input")
  expect_identical(.gk_threshold_lookup(thresholds, "missing", "PanCK")$status,
    "NOT_CALLABLE_UNAVAILABLE")
  calls <- data.frame(a = c(TRUE, NA, FALSE), b = c(FALSE, TRUE, NA))
  expect_identical(.gk_expr_match(calls, none_of = "a"), c(FALSE, TRUE, TRUE))
  expect_identical(.gk_expr_match(calls, none_of = "a", none_na_negative = FALSE),
    c(FALSE, NA, TRUE))
  rule <- gk_rule("R1", "a", all_of = "a", none_of = "b")
  expect_false(.gk_rule_disabled(rule, c(a = TRUE, b = TRUE))$disabled)
  expect_true(.gk_rule_disabled(rule, c(a = FALSE, b = TRUE))$disabled)
  expect_invisible(print(classified))
  expect_true(nrow(summary(classified)) > 0L)

  stats <- .gk_correction_stats(matrix(c(1, 1, 2, 2), ncol = 2L))
  expect_true(any(stats$mad_fallback))
  expect_true(all(is.finite(.gk_apply_robust_z(matrix(c(1, 2), ncol = 1L), 1, 1))))
  one <- .gk_fit_pc1_panel(
    matrix(c(1, 2, 3, 4), ncol = 1L, dimnames = list(NULL, "A")), "A", FALSE
  )
  two <- .gk_fit_pc1_panel(
    matrix(c(1, 2, 3, 4, 2, 3, 4, 5), ncol = 2L,
      dimnames = list(NULL, c("A", "B"))), c("A", "B"), TRUE
  )
  expect_true(is.matrix(one$pc1_rotation))
  expect_true(is.matrix(two$pc1_rotation))
  only_absent <- gk_correct(prep, method = "robust_z", markers = "CD21")
  expect_true(all(is.na(only_absent$matrix[, "CD21"])))
  expect_identical(.gk_threshold_correction(prep, fixed$model), fixed$matrix)
  expect_error(.gk_threshold_correction(prep, list()), class = "gatekeepr_error_input")
  expect_invisible(print(fixed$model))
})

test_that("state estimation and persistence cover manual, reference and lock paths", {
  cfg <- gk_example_config()
  prep <- gk_example_prepared()
  args <- .gk_method_args("parent_crossing", list(n_grid = 128L), role = "state")
  labels <- c(rep("CD4 T cells", 60), rep("Other immune cells", 60))
  values <- c(rep(4, 60), rep(0, 60))
  manual <- .gk_state_estimate(values, labels == "CD4 T cells", labels, cfg,
    "FOXP3", "CD4 T cells", "manual", list(value = 1), 0.5)
  weak <- .gk_state_estimate(values[1:3], rep(TRUE, 3), labels[1:3], cfg,
    "FOXP3", "CD4 T cells", "parent_crossing", args, 0.5)
  flat <- .gk_state_estimate(rep(1, 120), labels == "CD4 T cells", labels, cfg,
    "FOXP3", "CD4 T cells", "parent_crossing", args, 0.5)
  reference <- args
  reference$reference <- "Immune"
  ref <- .gk_state_estimate(values, labels == "CD4 T cells", labels, cfg,
    "FOXP3", "CD4 T cells", "parent_crossing", reference, 0.5)
  expect_identical(manual$status, "MANUAL")
  expect_identical(weak$status, "NOT_CALLABLE_UNDERPOWERED")
  expect_identical(flat$status, "NOT_CALLABLE_NO_SEPARATION")
  expect_identical(ref$status, "CALLABLE")
  expect_identical(.gk_state_score(prep, gk_example_review()$classification), prep$score)
  expect_identical(.gk_state_localization(prep, "CD4")$min_ratio, 0)

  review <- gk_example_review()
  dir <- file.path(withr::local_tempdir(), "review-lock")
  gk_save_review(review, dir)
  writeLines(c("pid 1", "host another-host", "time_utc stale"),
    file.path(dir, "review.lock"))
  expect_error(gk_load_review(dir), class = "gatekeepr_error_lockfile")
  loaded <- gk_load_review(dir, takeover = TRUE)
  expect_s3_class(loaded, "gk_review")
  gk_save_review(loaded, dir, overwrite = TRUE)
  expect_true(file.exists(file.path(dir, "checkpoint.prev")))
})

test_that("plot, structure and app wrappers cover optional branches", {
  skip_if_not_installed("ggplot2")
  prep <- gk_example_prepared()
  cfg <- gk_example_config()
  thresholds <- gk_thresholds(prep, cfg, seed = 1L)
  classified <- suppressWarnings(gk_classify(prep, thresholds, cfg))
  structures <- gk_structures(classified, prep, min_cells = 100000L)
  image_id <- unique(prep$cells$image_id)
  expect_true(is.list(structures$parameters))
  expect_invisible(print(structures))
  expect_s3_class(gk_plot_map(prep, image_id, colour_by = "unknown"), "ggplot")
  umap <- matrix(rnorm(20), ncol = 2L, dimnames = list(sprintf("c%02d", 1:10), c("UMAP1", "UMAP2")))
  expect_s3_class(gk_plot_embedding(
    structure(list(umap = umap, population = rep("p", 10L),
      config_sha256 = NA_character_, source_sha256 = NA_character_), class = "gk_embedding"),
    colour_by = "population"), "ggplot")
  expect_s3_class(gk_plot_overview(prep, image_id), c("patchwork", "ggplot"))
  expect_true(shiny::is.shiny.appobj(gk_app(review = gk_example_review())))
  saved <- file.path(withr::local_tempdir(), "app-review")
  gk_save_review(gk_example_review(), saved)
  expect_true(shiny::is.shiny.appobj(gk_app(workdir = saved)))
  export_dir <- file.path(withr::local_tempdir(), "app-export")
  gk_export(gk_lock(gk_example_review(), reviewer = "reviewer-01"), export_dir)
  expect_true(shiny::is.shiny.appobj(gk_app(export = export_dir)))
  expect_error(gk_app(cellspec = gk_example_slide()), class = "gatekeepr_error_input")
})
