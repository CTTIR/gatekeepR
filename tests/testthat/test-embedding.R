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
