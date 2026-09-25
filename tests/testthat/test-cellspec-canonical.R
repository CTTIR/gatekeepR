canonical_fixture <- function() {
  x <- cellspecR::cs_example()
  x$cells$all_missing_integer <- rep(NA_integer_, nrow(x$cells))
  x$cells$all_missing_character <- rep(NA_character_, nrow(x$cells))
  x$cells$selected <- seq_len(nrow(x$cells)) %% 2L == 0L
  x$measurements[1, 1] <- 1 + .Machine$double.eps
  x$images$extra_metadata <- "synthetic calibration"
  x$dictionary$marker_source <- x$dictionary$marker
  x$adjacency <- data.frame(
    image_id = x$cells$image_id[[1]],
    cell_id_a = x$cells$cell_id[[1]], cell_id_b = x$cells$cell_id[[2]],
    shared_boundary = 0.25, method = "mask_touching"
  )
  cellspecR::cs_assert_valid(x)
  x
}

test_that("canonical Parquet and TSV cross-read without losing typed data", {
  skip_if_not_installed("cellspecR")
  x <- canonical_fixture()
  for (format in c("parquet", "tsv.gz")) {
    dir <- file.path(withr::local_tempdir(), paste0("space ü ", format))
    cellspecR::cs_write(x, dir, format = format)
    y <- gk_read_cellspec(dir)
    for (name in c("cells", "measurements", "dictionary", "images", "channels", "adjacency")) {
      expect_identical(y[[name]], x[[name]], info = paste(format, name))
    }
    expect_match(y$provenance$manifest_sha256, "^[0-9a-f]{64}$")
    dir2 <- file.path(withr::local_tempdir(), format)
    expect_invisible(gk_write_cellspec(x, dir2, format = format))
    z <- cellspecR::cs_read_cellspec(dir2)
    for (name in c("cells", "measurements", "dictionary", "images", "channels", "adjacency", "provenance")) {
      expect_identical(z[[name]], x[[name]], info = paste(format, name))
    }
    gk_write_cellspec(x, dir2, overwrite = TRUE, format = format)
    expect_true(all(cellspecR::cs_verify(dir2)$ok))
  }
})

test_that("canonical empty tables preserve declared column types", {
  skip_if_not_installed("cellspecR")
  x <- canonical_fixture()
  x$cells <- x$cells[FALSE, , drop = FALSE]
  x$measurements <- x$measurements[FALSE, , drop = FALSE]
  x$adjacency <- x$adjacency[FALSE, , drop = FALSE]
  for (format in c("parquet", "tsv.gz")) {
    dir <- file.path(withr::local_tempdir(), format)
    gk_write_cellspec(x, dir, format = format)
    y <- gk_read_cellspec(dir)
    expect_identical(y$cells, x$cells)
    expect_identical(y$measurements, x$measurements)
    expect_identical(y$adjacency, x$adjacency)
  }
})

test_that("canonical writes require declared calibration", {
  skip_if_not_installed("cellspecR")
  x <- canonical_fixture()
  x$images$pixel_size <- NA_real_
  dir <- file.path(withr::local_tempdir(), "uncalibrated")
  expect_error(gk_write_cellspec(x, dir, format = "parquet"), class = "cellspec_error_invalid")
  expect_false(dir.exists(dir))
})

test_that("canonical dependency failures do not fall back to legacy", {
  skip_if_not_installed("cellspecR")
  x <- canonical_fixture()
  dir <- file.path(withr::local_tempdir(), "canonical")
  cellspecR::cs_write(x, dir)
  local_mocked_bindings(.gk_require = function(...) {
    .gk_abort("Missing canonical dependency.", class = "dependency")
  })
  expect_error(gk_read_cellspec(dir), class = "gatekeepr_error_dependency")
  expect_error(gk_write_cellspec(x, paste0(dir, "-new"), format = "tsv.gz"),
               class = "gatekeepr_error_dependency")
  expect_invisible(gk_write_cellspec(x, paste0(dir, "-legacy")))
  expect_s3_class(gk_read_cellspec(paste0(dir, "-legacy")), "cellspec")
})

test_that("canonical corruption and unsupported schema fail closed", {
  skip_if_not_installed("cellspecR")
  x <- canonical_fixture()
  dir <- file.path(withr::local_tempdir(), "canonical")
  cellspecR::cs_write(x, dir)
  cat("corruption", file = file.path(dir, "cells.parquet"), append = TRUE)
  expect_error(gk_read_cellspec(dir), class = "gatekeepr_error_structure")
  cellspecR::cs_write(x, dir, overwrite = TRUE)
  unlink(file.path(dir, "DONE"))
  expect_error(gk_read_cellspec(dir, verify = FALSE), class = "cellspec_error_integrity")
  cellspecR::cs_write(x, dir, overwrite = TRUE)
  meta <- jsonlite::fromJSON(file.path(dir, "cellspec.json"), simplifyVector = FALSE)
  meta$files$cells <- "unknown.bin"
  .gk_write_json(meta, file.path(dir, "cellspec.json"))
  expect_error(gk_read_cellspec(dir, verify = FALSE), "Unsupported", class = "gatekeepr_error_structure")
  meta$files$cells <- "cells.parquet"
  meta$cell_columns <- names(x$cells)
  .gk_write_json(meta, file.path(dir, "cellspec.json"))
  expect_error(gk_read_cellspec(dir, verify = FALSE), "ambiguous", class = "gatekeepr_error_structure")
  meta$cell_columns <- NULL
  meta$dictionary <- list(columns = list(), rows = list())
  .gk_write_json(meta, file.path(dir, "cellspec.json"))
  expect_error(gk_read_cellspec(dir, verify = FALSE), class = "cellspec_error")
})

test_that("undeclared legacy schemas fail instead of guessing columns", {
  dir <- file.path(withr::local_tempdir(), "legacy")
  gk_write_cellspec(gk_simulate(n_cells = 200), dir)
  meta <- jsonlite::fromJSON(file.path(dir, "cellspec.json"), simplifyVector = FALSE)
  meta$cell_columns <- NULL
  .gk_write_json(meta, file.path(dir, "cellspec.json"))
  expect_error(gk_read_cellspec(dir, verify = FALSE), "cell_columns",
               class = "gatekeepr_error_structure")
})
