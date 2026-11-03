gk_structure_fixture <- function(reverse = FALSE) {
  cfg <- gk_config(gk_signal_policy("A"),
    gk_panel("A", role = "identity", transform = "none", threshold_method = "manual",
      threshold_args = list(value = 0), min_support = gk_min_support(min_cells = 2L)),
    hierarchy = gk_hierarchy(list(gk_rule("A", "A cells", all_of = "A", review = "structure",
      pending_label = "Pending", decisions = c(Tumor = "Tumor", Benign = "Benign",
        Unresolved = "Unresolved"))), version = "test"))
  x <- c(-1.3, -1.2, -1.1, -1, -.9, -.7, 0, .7, .9, 1, 1.1, 1.2, 1.3)
  slide <- gk_test_cellspec(list(A = seq_along(x)), x = x, y = rep(0, length(x)))
  if (reverse) {
    index <- rev(seq_along(x))
    slide <- gk_cellspec(slide$cells[index, ], slide$measurements[index, , drop = FALSE])
  }
  prep <- gk_prepare(slide, cfg, quiet = TRUE)
  list(prepared = prep, classification = gk_classify(prep, gk_thresholds(prep, cfg), cfg))
}

test_that("structures bind full classifications and reject invalid numeric boundaries", {
  skip_if_not_installed("dbscan")
  fixture <- gk_structure_fixture()
  p <- fixture$prepared
  cl <- fixture$classification
  altered <- cl
  altered$cells$pending_review[1] <- FALSE
  expect_error(gk_structures(altered, p), class = "gatekeepr_error_state")
  altered <- cl
  altered$cells <- altered$cells[13:1, ]
  expect_error(gk_structures(altered, p), class = "gatekeepr_error_state")
  for (args in list(list(eps_min = -1), list(eps_max = Inf), list(eps_max = 1),
    list(min_pts = 1), list(min_pts = 2^31), list(min_cells = 0), list(min_cells = 2^31))) {
    expect_error(do.call(gk_structures, c(list(cl, p), args)), class = "gatekeepr_error_input")
  }
  expect_s3_class(gk_structures(cl, p, eps_min = 0, eps_max = 0, min_pts = 2L), "gk_structures")
  th <- gk_thresholds(p, p$config)
  th$estimate <- 14
  no_pending <- gk_classify(p, th, p$config)
  empty <- gk_structures(no_pending, p)
  expect_equal(nrow(empty$structures), 0L)
  expect_true(all(is.na(empty$cell_structure$structure_id)))
})

test_that("ambiguous DBSCAN border cells have stable assignments under permutation", {
  skip_if_not_installed("dbscan")
  a <- gk_structure_fixture()
  b <- gk_structure_fixture(reverse = TRUE)
  first <- gk_structures(a$classification, a$prepared,
    eps_min = .75, eps_max = .75, min_pts = 6L, min_cells = 2L)
  second <- gk_structures(b$classification, b$prepared,
    eps_min = .75, eps_max = .75, min_pts = 6L, min_cells = 2L)
  expect_equal(nrow(first$structures), 2L)
  matched <- match(.gk_cell_key(first$cell_structure), .gk_cell_key(second$cell_structure))
  expect_identical(first$cell_structure$structure_id, second$cell_structure$structure_id[matched])
  expect_identical(first$structures, second$structures)
  expect_identical(first$cell_structure$structure_id[7], first$cell_structure$structure_id[1])
})
