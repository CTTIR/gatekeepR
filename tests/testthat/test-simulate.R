test_that("gk_simulate() is deterministic under a seed and leaves the RNG alone", {
  set.seed(123)
  before <- .Random.seed
  a <- gk_simulate(n_cells = 600, seed = 9)
  expect_identical(.Random.seed, before)
  b <- gk_simulate(n_cells = 600, seed = 9)
  expect_identical(a, b)
  c <- gk_simulate(n_cells = 600, seed = 10)
  expect_false(identical(a$measurements, c$measurements))
})

test_that("simulated slides carry the documented controls", {
  x <- gk_simulate(n_cells = 5000, seed = 1)
  expect_s3_class(x, "cellspec")
  expect_identical(nrow(x$cells), 5000L)
  pops <- table(x$cells$sim_population)
  expect_identical(unname(pops[["rare_dp_t"]]), 15L)
  expect_true(all(x$measurements[, grepl(":CD21:", colnames(x$measurements), fixed = TRUE)] == 0))
  epi <- x$cells$sim_population == "epithelial"
  expect_gt(mean(!is.na(x$cells$sim_structure[epi])), 0.85)
  expect_true(all(is.na(x$cells$sim_structure[!epi])))
  expect_setequal(
    unique(x$dictionary$compartment[x$dictionary$marker == "FOXP3"]),
    c("cell", "nucleus", "cytoplasm")
  )
  cd3 <- x$measurements[, "cell:CD3e:mean"]
  t_cells <- x$cells$sim_population %in% c("cd4_t", "cd8_t")
  expect_gt(stats::median(cd3[t_cells]), 5 * stats::median(cd3[!t_cells]))
  sma <- x$measurements[, "cell:SMA:mean"]
  stromal <- x$cells$sim_population == "stromal"
  expect_lt(abs(log(stats::median(sma[stromal]) / stats::median(sma[!stromal]))), 0.5)
})

test_that("gk_simulate() validates its arguments", {
  expect_error(gk_simulate(n_cells = 10), class = "gatekeepr_error_input")
  expect_error(gk_simulate(markers = "CD99"), class = "gatekeepr_error_input")
  expect_error(gk_simulate(rare_fraction = 0.5), class = "gatekeepr_error_input")
  sub <- gk_simulate(n_cells = 300, markers = c("CD45", "FOXP3"), absent = character(), shuffled = character())
  expect_setequal(unique(sub$dictionary$marker), c("CD45", "FOXP3"))
  weak <- gk_simulate(n_cells = 300, separation = 0.3, seed = 2)
  expect_s3_class(weak, "cellspec")
})
