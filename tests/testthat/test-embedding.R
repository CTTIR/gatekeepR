test_that("embedding is reproducible and keeps basin uncertainty explicit", {
  skip_if_not_installed("uwot")
  prep <- gk_example_prepared()
  a <- gk_embed(prep, n_pcs = 3L, n_neighbors = 10L, grid = 30L,
    min_abs = 20L, min_frac = 0.01, small_basins = "uncertain", seed = 7L)
  b <- gk_embed(prep, n_pcs = 3L, n_neighbors = 10L, grid = 30L,
    min_abs = 20L, min_frac = 0.01, small_basins = "uncertain", seed = 7L)
  expect_s3_class(a, "gk_embedding")
  expect_identical(a$umap, b$umap)
  expect_identical(a$population, b$population)
  expect_equal(length(a$population), nrow(prep$cells))
  expect_true(all(is.na(a$population[a$small_basin_cells])))
  expect_true(all(is.finite(a$population[!is.na(a$population)])))
})

test_that("optional EBImage basins separate density peaks and preserve background", {
  skip_if_not_installed("EBImage")
  density <- matrix(0, 15L, 15L)
  peak <- matrix(c(.2, .4, .2, .4, 1, .4, .2, .4, .2), 3L)
  density[3:5, 3:5] <- peak
  density[11:13, 11:13] <- peak * .8
  basins <- .gk_watershed_basins(list(density = density), "ebimage", .03)
  expect_identical(dim(basins$labels), dim(density))
  expect_true(all(basins$labels[density == 0] == 0))
  expect_gt(basins$labels[4, 4], 0)
  expect_gt(basins$labels[12, 12], 0)
  expect_false(basins$labels[4, 4] == basins$labels[12, 12])
  assigned <- .gk_assign_basins(rbind(c(4, 4), c(12, 12), c(1, 1)),
    list(x = 1:15, y = 1:15), basins, "uncertain", min_abs = 1L, min_frac = 0)
  expect_false(assigned$population[1] == assigned$population[2])
  expect_true(is.na(assigned$population[3]))
})

test_that("optional EBImage embedding integrates with bound threshold estimation", {
  skip_if_not_installed("uwot")
  skip_if_not_installed("EBImage")
  cfg <- gk_test_config(c("A", "B"), method = "population_crossing", transform = "none")
  prep <- gk_prepare(gk_test_cellspec(list(A = c(1:100, 201:300), B = c(201:300, 1:100))),
    cfg, quiet = TRUE)
  correction <- gk_correct(prep, "robust_z")
  run <- function() gk_embed(prep, correction = correction, basin_method = "ebimage",
    n_pcs = 2L, n_neighbors = 10L, grid = 25L, min_abs = 5L, seed = 7L)
  a <- run()
  b <- run()
  expect_identical(a$population, b$population)
  expect_identical(a$umap, b$umap)
  th <- gk_thresholds(prep, cfg, embedding = a, correction = correction)
  cl <- suppressWarnings(gk_classify(prep, th, cfg, correction = correction))
  expect_s3_class(cl, "gk_classification")
  expect_equal(nrow(cl$cells), 200L)
})
