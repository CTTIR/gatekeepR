test_that("gk_signal_policy() recycles and validates", {
  pol <- gk_signal_policy(c("A", "B"), compartment = c("cell", "nucleus"), fallback_compartment = c(NA, "cell"))
  expect_s3_class(pol, c("gk_signal_policy", "cs_signal_policy", "data.frame"))
  expect_identical(pol$statistic, c("mean", "mean"))
  expect_snapshot(print(pol))
  expect_error(gk_signal_policy(c("A", "B"), compartment = c("cell", "cell", "cell")), class = "gatekeepr_error_config")
  expect_error(gk_signal_policy("A:B"), class = "gatekeepr_error_config")
  expect_error(gk_signal_policy(" A"), class = "gatekeepr_error_config")
  expect_error(gk_signal_policy("A", compartment = "membranes"), class = "gatekeepr_error_config")
  expect_error(gk_signal_policy("A", fallback_compartment = "cell"), class = "gatekeepr_error_config")
  expect_error(gk_signal_policy("A", statistic = ""), class = "gatekeepr_error_config")
  expect_error(gk_signal_policy("A", min_value = Inf), class = "gatekeepr_error_config")
  expect_error(gk_signal_policy(c("A", "A")), class = "gatekeepr_error_input")
  expect_error(.gk_validate_signal_policy(data.frame(marker = "A")), class = "gatekeepr_error_config")
  dup <- data.frame(
    marker = c("A", "A"), compartment = "cell", statistic = "mean",
    fallback_compartment = NA, min_value = 0
  )
  expect_error(.gk_validate_signal_policy(dup), class = "gatekeepr_error_config")
})

test_that("gk_cellspec() builds a spec-conformant object", {
  x <- gk_test_cellspec(list(A = c(1, 2, 3), "nucleus:A" = c(3, 2, 1)))
  expect_s3_class(x, "cellspec")
  expect_identical(x$spec_version, "1.0.0")
  expect_identical(x$cells$sample_id, rep("img-1", 3))
  expect_identical(x$dictionary$compartment, c("cell", "nucleus"))
  expect_identical(x$channels$marker, "A")
  expect_snapshot(print(x))
})

test_that("gk_cellspec() rejects structurally invalid input", {
  cells <- data.frame(cell_id = c("a", "b"), image_id = "i", x = c(1, 2), y = c(1, 2))
  m <- cbind("cell:A:mean" = c(1, 2))
  expect_error(gk_cellspec(list(), m), class = "gatekeepr_error_structure")
  expect_error(gk_cellspec(cells[, -1], m), class = "gatekeepr_error_structure")
  expect_error(gk_cellspec(cells, data.frame(m)), class = "gatekeepr_error_structure")
  expect_error(gk_cellspec(cells, cbind(A = c(1, 2))), class = "gatekeepr_error_structure")
  expect_error(gk_cellspec(cells, unname(m)), class = "gatekeepr_error_structure")
  bad <- cells
  bad$cell_id <- c("a", "a")
  expect_snapshot(gk_cellspec(bad, m), error = TRUE)
  bad <- cells
  bad$x[1] <- NA
  expect_error(gk_cellspec(bad, m), class = "gatekeepr_error_structure")
  expect_error(gk_cellspec(cells, cbind("cell:A:mean" = 1)), class = "gatekeepr_error_structure")
  two <- cbind("cell:A:mean" = c(1, 2), "cell:A:mean" = c(1, 2))
  expect_error(gk_cellspec(cells, two), class = "gatekeepr_error_structure")
})

test_that(".gk_validate_cellspec() checks every required element", {
  x <- gk_test_cellspec(list(A = c(1, 2)))
  expect_error(.gk_validate_cellspec(list()), class = "gatekeepr_error_input")
  y <- x
  y$images <- NULL
  expect_error(.gk_validate_cellspec(y), class = "gatekeepr_error_structure")
  y <- x
  y$spec_version <- "2.0.0"
  expect_error(.gk_validate_cellspec(y), "unsupported", class = "gatekeepr_error_structure")
  y <- x
  y$cells$sample_id <- NULL
  expect_error(.gk_validate_cellspec(y), class = "gatekeepr_error_structure")
  y <- x
  y$cells$cell_id <- c(1, 2)
  expect_error(.gk_validate_cellspec(y), class = "gatekeepr_error_structure")
  y <- x
  y$dictionary$statistic <- NULL
  expect_error(.gk_validate_cellspec(y), class = "gatekeepr_error_structure")
  y <- x
  y$dictionary$marker <- "A:B"
  expect_error(.gk_validate_cellspec(y), class = "gatekeepr_error_structure")
  y <- x
  y$images$image_id <- "other"
  expect_error(.gk_validate_cellspec(y), class = "gatekeepr_error_structure")
})

test_that("signal selection follows the policy, fallback and min_value", {
  x <- gk_test_cellspec(list(
    "cytoplasm:P" = c(10, NA, -1, 5),
    P = c(1, 2, 3, NA),
    Q = c(0, 1, -2, NA)
  ))
  pol <- gk_signal_policy(c("P", "Q"), compartment = c("cytoplasm", "cell"), fallback_compartment = c("cell", NA))
  s <- .gk_signal_matrix(x, pol)
  expect_identical(unname(s$signal[, "P"]), c(10, 2, 3, 5))
  expect_identical(unname(s$source[, "P"]), c(1L, 2L, 2L, 1L))
  expect_identical(unname(s$signal[, "Q"]), c(0, 1, NA, NA))
  expect_identical(unname(s$source[, "Q"]), c(1L, 1L, 0L, 0L))
  expect_identical(s$labels$fallback, c("fallback:cell:mean", NA))
  missing <- gk_signal_policy("P", compartment = "membrane")
  expect_snapshot(.gk_signal_matrix(x, missing), error = TRUE)
})

test_that("cellspec directories round-trip exactly, also under spaces and non-ASCII paths", {
  x <- gk_simulate(n_cells = 400, seed = 2)
  root <- withr::local_tempdir()
  dir <- file.path(root, "a b", "ü slide")
  expect_invisible(gk_write_cellspec(x, dir))
  expect_setequal(list.files(dir), c("cells.tsv.gz", "cellspec.json", "MANIFEST.sha256", "DONE"))
  y <- gk_read_cellspec(dir)
  expect_identical(y$measurements, x$measurements)
  expect_identical(y$cells, x$cells)
  expect_identical(y$dictionary, x$dictionary)
  expect_match(y$provenance$manifest_sha256, "^[0-9a-f]{64}$")
  expect_error(gk_write_cellspec(x, dir), class = "gatekeepr_error_input")
  gk_write_cellspec(x, dir, overwrite = TRUE)
  expect_false(any(grepl("partial|old", list.files(dirname(dir)))))
})

test_that("reading a tampered or incomplete cellspec directory fails", {
  x <- gk_simulate(n_cells = 300, seed = 3)
  dir <- file.path(withr::local_tempdir(), "slide")
  gk_write_cellspec(x, dir)
  cat("extra\n", file = file.path(dir, "cellspec.json"), append = TRUE)
  expect_error(gk_read_cellspec(dir), class = "gatekeepr_error_structure")
  expect_s3_class(gk_read_cellspec(dir, verify = FALSE), "cellspec")
  unlink(file.path(dir, "DONE"))
  expect_error(gk_read_cellspec(dir), "DONE", class = "gatekeepr_error_structure")
  dir2 <- file.path(withr::local_tempdir(), "slide2")
  gk_write_cellspec(x, dir2)
  meta <- jsonlite::fromJSON(file.path(dir2, "cellspec.json"), simplifyVector = FALSE)
  meta$spec_version <- "9.0.0"
  .gk_write_json(meta, file.path(dir2, "cellspec.json"))
  expect_error(gk_read_cellspec(dir2, verify = FALSE), "Unsupported", class = "gatekeepr_error_structure")
  expect_error(gk_read_cellspec(file.path(dir2, "nope")), class = "gatekeepr_error_input")
})

test_that("JSON helpers convert rows and nested provenance", {
  expect_identical(.gk_rows_to_df(list()), data.frame())
  df <- .gk_rows_to_df(list(list(a = 1, b = "x"), list(a = 2, b = NULL)))
  expect_identical(df$b, c("x", NA))
  expect_null(.gk_json_ready(NULL))
  ready <- .gk_json_ready(list(a = 1:3, b = list(c = "d"), e = data.frame(z = 1)))
  expect_s3_class(ready$a, "AsIs")
  expect_identical(ready$b$c, "d")
  expect_s3_class(ready$e, "data.frame")
})
