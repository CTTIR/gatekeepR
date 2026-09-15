# Audit limitation "hard-coded sample special cases": package code and bundled
# data must be study-neutral. Study names, private sample identifiers and
# study-specific overrides live in study configurations, never in gatekeepR.

test_that("no study-specific names occur in package code or bundled files", {
  pkg_root <- testthat::test_path("..", "..")
  r_dir <- file.path(pkg_root, "R")
  skip_if_not(dir.exists(r_dir), "package sources not available (installed test run)")
  files <- c(
    list.files(r_dir, pattern = "\\.R$", full.names = TRUE),
    list.files(file.path(pkg_root, "inst"), recursive = TRUE, full.names = TRUE,
      pattern = "\\.(json|R|md|txt)$|README"
    )
  )
  pattern <- "(?i)lcnec|scan[0-9]|_ER\\b|akoya_pipeline"
  hits <- unlist(lapply(files, function(f) {
    lines <- readLines(f, warn = FALSE, encoding = "UTF-8")
    which_hit <- grep(pattern, lines, perl = TRUE)
    if (length(which_hit)) paste0(basename(f), ":", which_hit) else character()
  }), use.names = FALSE)
  if (is.null(hits)) hits <- character()
  expect_identical(hits, character())
})
