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
