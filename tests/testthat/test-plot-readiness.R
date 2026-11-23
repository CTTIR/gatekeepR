test_that("dotplots aggregate observed scores per image and cell type", {
  skip_if_not_installed("ggplot2")
  cfg <- gk_test_config(c("A", "B"), method = "manual", transform = "none",
    threshold_args = list(value = 50))
  values <- list(A = rep(1:100, 2), B = c(NA, 2:200))
  prep <- gk_prepare(gk_test_cellspec(values, image_id = rep(c("first", "second"), each = 100)), cfg, quiet = TRUE)
  th <- gk_thresholds(prep, cfg)
  cl <- gk_classify(prep, th, cfg)
  dat <- gk_plot_dotplot(prep, cl, th)$data
  expect_equal(nrow(dat), 8L)
  first <- dat$image_id == "first" & dat$marker == "B" & dat$cell_type == cfg$hierarchy$undefined_label
  expect_equal(dat$n_observed[first], 48L)
  expect_equal(dat$score[first], mean(2:49))
  expect_equal(sum(dat$n_observed[dat$marker == "A"]), 200L)
  reordered <- cl
  reordered$cells <- reordered$cells[nrow(cl$cells):1, ]
  expect_error(gk_plot_dotplot(prep, reordered, th), class = "gatekeepr_error_state")
  changed <- th
  changed$estimate[1] <- 12
  expect_error(gk_plot_dotplot(prep, cl, changed), class = "gatekeepr_error_state")
  corrected <- gk_correct(prep, "robust_z")
  ct <- gk_thresholds(prep, cfg, correction = corrected)
  cc <- gk_classify(prep, ct, cfg, correction = corrected)
  cd <- gk_plot_dotplot(prep, cc, ct)$data
  expected <- mean(corrected$matrix[1:100, "A"])
  expect_equal(cd$score[cd$image_id == "first" & cd$marker == "A"], expected)
  expect_error(gk_plot_dotplot(prep, cc, th), class = "gatekeepr_error_state")
})

test_that("density plots show retained crossing pools and explain absent evidence", {
  skip_if_not_installed("ggplot2")
  cfg <- gk_test_config("A", method = "manual", transform = "none", threshold_args = list(value = 50))
  prep <- gk_prepare(gk_test_cellspec(list(A = 1:100)), cfg, quiet = TRUE)
  th <- gk_thresholds(prep, cfg)
  expect_equal(nrow(gk_plot_density(th, "A", "img-1")$data), 0L)
  th$evidence_ref <- "pools"
  attr(th, "evidence") <- list(pools = list(positive_values = 61:100, negative_values = 1:40))
  dat <- gk_plot_density(th, "A", "img-1")$data
  expect_setequal(unique(dat$pool), c("Positive pool", "Negative pool"))
  expect_true(all(is.finite(dat$density)))
  expect_gt(nrow(dat), 100L)
})

test_that("documented bundled example names exist", {
  expect_true(dir.exists(gk_example_path("example-slide")))
  expect_true(file.exists(gk_example_path("example-config.json")))
  expect_error(gk_example_path("example-review"), "must be one of")
  expect_error(gk_example_path("example-export"), "must be one of")
})

test_that("map and embedding colours use image plus cell identity", {
  skip_if_not_installed("ggplot2")
  cfg <- gk_test_config("A", method = "manual", transform = "none", threshold_args = list(value = 50))
  cells <- data.frame(image_id = rep(c("first", "second"), each = 100),
    cell_id = rep(sprintf("c%04d", 1:100), 2), x = 1:200, y = 1)
  measurements <- matrix(c(1:100, 100:1), ncol = 1, dimnames = list(NULL, "cell:A:mean"))
  prep <- gk_prepare(gk_cellspec(cells, measurements), cfg, quiet = TRUE)
  th <- gk_thresholds(prep, cfg)
  cl <- gk_classify(prep, th, cfg)
  map <- gk_plot_map(cl, "second")$data
  expect_identical(map$cell_type, cl$cells$cell_type[101:200])
  expect_equal(sum(map$cell_type == "A cells"), 51L)
  emb <- structure(list(umap = cbind(UMAP1 = 1:200, UMAP2 = 1),
    population = rep("p", 200), cell_keys = cells[, c("image_id", "cell_id")],
    source_sha256 = prep$source_sha256, config_sha256 = prep$config_sha256), class = "gk_embedding")
  rownames(emb$umap) <- cells$cell_id
  out <- gk_plot_embedding(emb, cl, "cell_type")$data
  expect_identical(out$colour, cl$cells$cell_type)
  emb$cell_keys$image_id[1] <- "unknown-image"
  expect_error(gk_plot_embedding(emb, cl, "cell_type"), class = "gatekeepr_error_state")
})

test_that("plot aesthetics build into drawable layers", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("dbscan")
  rv <- gk_app_test_review()
  img <- "img-1"
  emb <- structure(list(umap = cbind(UMAP1 = 1:100, UMAP2 = 1),
    population = rep("p", 100), cell_keys = .gk_cell_keys(rv$prepared$cells),
    source_sha256 = rv$source_sha256, config_sha256 = rv$config_sha256), class = "gk_embedding")
  rownames(emb$umap) <- rv$prepared$cells$cell_id
  plots <- list(gk_plot_density(rv$thresholds, "A", img),
    gk_plot_dotplot(rv$prepared, rv$classification, rv$thresholds),
    gk_plot_embedding(emb, rv$classification, "cell_type"),
    gk_plot_map(gk_replay(rv), img), gk_plot_thresholds(rv$thresholds, img),
    gk_plot_states(rv$state_calls, img))
  for (p in plots) expect_s3_class(ggplot2::ggplot_build(p), "ggplot_built")
})

test_that("unmeasured marker groups have no visible dot", {
  skip_if_not_installed("ggplot2")
  cfg <- gk_test_config(c("A", "B"), method = "manual", transform = "none",
    threshold_args = list(value = 50))
  prep <- gk_prepare(gk_test_cellspec(list(A = 1:100, B = rep(NA_real_, 100))), cfg, quiet = TRUE)
  th <- gk_thresholds(prep, cfg)
  plot <- gk_plot_dotplot(prep, gk_classify(prep, th, cfg), th)
  absent <- plot$data$marker == "B"
  expect_true(all(is.na(plot$data$score[absent])))
  expect_true(all(plot$data$n_observed[absent] == 0L))
  drawn <- ggplot2::ggplot_build(plot)$data[[1]]
  expect_true(all(drawn$size[absent] == 0))
  expect_true(all(drawn$size[!absent] > 0))
})

gk_plot_test_objects <- function() {
  cfg <- gk_example_config()
  prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), cfg, quiet = TRUE)
  th <- gk_thresholds(prep, cfg, seed = 7L)
  cl <- suppressWarnings(gk_classify(prep, th, cfg))
  list(prep = prep, th = th, cl = cl, st = gk_state_calls(prep, th, cl, cfg))
}

test_that("qualitative plot colours are named, distinct and Okabe-Ito up to nine classes", {
  few <- .gk_plot_discrete_colours(c("b", "a", NA, "c", "a"))
  expect_named(few, c("a", "b", "c"))
  expect_true(all(few %in% grDevices::palette.colors(9L, "Okabe-Ito")))
  nine <- .gk_plot_discrete_colours(letters[1:9])
  expect_setequal(unname(nine), unname(grDevices::palette.colors(9L, "Okabe-Ito")))
  for (n in c(10L, 11L, 36L, 40L)) {
    many <- .gk_plot_discrete_colours(sprintf("class-%02d", seq_len(n)))
    expect_length(many, n)
    expect_identical(anyDuplicated(unname(many)), 0L)
  }
  sparse <- factor(c("x", "y"), levels = c("y", "x", "z"))
  expect_named(.gk_plot_discrete_colours(sparse), c("y", "x"))
  expect_identical(.gk_plot_label("cell_type"), "Cell type")
})

test_that("plots carry readable axis and legend titles", {
  skip_if_not_installed("ggplot2")
  o <- gk_plot_test_objects()
  map <- gk_plot_map(o$cl, "sim-01")
  expect_identical(map$labels$colour, "Cell type")
  expect_identical(map$labels$x, "Centroid x")
  th <- gk_plot_thresholds(o$th, "sim-01")
  expect_identical(th$labels$colour, "Status")
  expect_match(th$labels$y, "Threshold estimate")
  dens <- gk_plot_density(o$th, "CD3e", "sim-01")
  expect_identical(dens$labels$x, "CD3e score")
  expect_match(dens$labels$subtitle, "threshold [0-9.]+$")
  numeric_map <- gk_plot_map(o$prep, "sim-01", colour_by = "x")
  expect_s3_class(ggplot2::ggplot_build(numeric_map), "ggplot_built")
  review <- gk_review(o$cl, o$st, gk_structures(o$cl, o$prep), o$th, o$prep)
  logical_map <- gk_plot_map(gk_replay(review), "sim-01", colour_by = "analysed")
  expect_s3_class(ggplot2::ggplot_build(logical_map), "ggplot_built")
})

test_that("threshold plot names the status of markers without an estimate", {
  skip_if_not_installed("ggplot2")
  o <- gk_plot_test_objects()
  expected <- o$th$marker[!is.finite(o$th$estimate)]
  expect_gt(length(expected), 0L)
  built <- ggplot2::ggplot_build(gk_plot_thresholds(o$th, "sim-01"))
  labels <- built$data[[2L]]
  expect_identical(nrow(labels), length(expected))
  expect_true(all(grepl("^NOT_CALLABLE", labels$label)))
  cfg <- gk_test_config("A", method = "manual", transform = "none",
    threshold_args = list(value = 50))
  prep <- gk_prepare(gk_test_cellspec(list(A = rep(NA_real_, 100))), cfg, quiet = TRUE)
  none <- gk_plot_thresholds(gk_thresholds(prep, cfg), prep$cells$image_id[[1L]])
  expect_s3_class(ggplot2::ggplot_build(none), "ggplot_built")
})

test_that("state plot shows parent cells only and separates uncalled cells", {
  skip_if_not_installed("ggplot2")
  o <- gk_plot_test_objects()
  dat <- gk_plot_states(o$st, "sim-01")$data
  calls <- o$st$calls
  expect_identical(nrow(dat), sum(calls$in_parent))
  expect_true(all(dat$in_parent))
  expect_identical(sum(dat$call == "Positive"), sum(calls$positive))
  expect_true(all(dat$call[!is.finite(dat$estimate)] == "Not called"))
  expect_false(any(dat$call[is.finite(dat$estimate) & dat$evaluable] == "Not called"))
  outside <- o$st
  outside$calls$in_parent <- FALSE
  expect_s3_class(ggplot2::ggplot_build(gk_plot_states(outside, "sim-01")), "ggplot_built")
})

test_that("plots reject an image that is not in the object", {
  skip_if_not_installed("ggplot2")
  o <- gk_plot_test_objects()
  expect_error(gk_plot_map(o$cl, "no-such-image"), class = "gatekeepr_error_input")
  expect_error(gk_plot_thresholds(o$th, "no-such-image"), class = "gatekeepr_error_input")
  expect_error(gk_plot_states(o$st, "no-such-image"), class = "gatekeepr_error_input")
  expect_error(gk_plot_map(o$cl, "sim-01", colour_by = NA_character_),
    class = "gatekeepr_error_input")
})

test_that("overview pairs the map with class counts in matching colours", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("patchwork")
  o <- gk_plot_test_objects()
  overview <- gk_plot_overview(o$cl, "sim-01")
  expect_s3_class(overview, "patchwork")
  expect_length(overview$patches$plots, 1L)
  counts <- overview$data
  expect_identical(sum(counts$n), 300L)
  expect_setequal(as.character(counts$class), unique(o$cl$cells$cell_type))
})
