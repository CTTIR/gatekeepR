test_that("doubles are formatted in shortest exact form", {
  x <- c(0.1, 1 / 3, 0.1 + 0.2, 1e-300, -2.5, NA, Inf, -Inf, NaN, 123456789012)
  s <- .gk_format_double(x)
  expect_identical(s[[1L]], "0.1")
  expect_identical(s[[3L]], "0.30000000000000004")
  expect_identical(s[6:8], c("NA", "Inf", "-Inf"))
  expect_identical(as.double(s[c(1:5, 10)]), x[c(1:5, 10)])
})

test_that("TSV files round-trip doubles exactly, including gzip", {
  withr::local_seed(1)
  df <- data.frame(
    id = c("a", "b\tc", "d"),
    v = c(stats::rnorm(2), 1 / 3),
    n = 1:3,
    flag = c(TRUE, NA, FALSE),
    f = factor(c("x", "y", "x")),
    stringsAsFactors = FALSE
  )
  for (ext in c(".tsv", ".tsv.gz")) {
    path <- withr::local_tempfile(fileext = ext)
    .gk_write_tsv(df, path)
    back <- .gk_read_tsv(path, types = c(v = "double", n = "integer", flag = "logical"))
    expect_identical(back$v, df$v)
    expect_identical(back$id, df$id)
    expect_identical(back$n, df$n)
    expect_identical(back$flag, df$flag)
    expect_identical(back$f, c("x", "y", "x"))
  }
})

test_that("TSV reading tolerates CRLF line endings", {
  path <- withr::local_tempfile(fileext = ".tsv")
  writeBin(charToRaw("a\tb\r\n1.5\tx\r\n2\ty\r\n"), path)
  back <- .gk_read_tsv(path, types = c(a = "double"))
  expect_identical(back$a, c(1.5, 2))
  expect_identical(back$b, c("x", "y"))
})

test_that("atomic JSON writes and reads", {
  dir <- withr::local_tempdir()
  path <- file.path(dir, "x.json")
  .gk_write_json(list(a = 1, b = I("z")), path)
  expect_identical(.gk_read_json(path), list(a = 1L, b = list("z")))
  expect_length(list.files(dir, all.files = TRUE, no.. = TRUE), 1L)
  bad <- file.path(dir, "bad.json")
  writeLines("{not json", bad)
  expect_error(.gk_read_json(bad), class = "gatekeepr_error_input")
  expect_error(.gk_read_json(file.path(dir, "missing.json")), class = "gatekeepr_error_input")
})

test_that("local seeds are reproducible and restore the caller's RNG state", {
  set.seed(99)
  before <- .Random.seed
  a <- .gk_with_seed(7, stats::runif(3))
  expect_identical(.Random.seed, before)
  b <- .gk_with_seed(7, stats::runif(3))
  expect_identical(a, b)
  withr::with_preserve_seed({
    suppressWarnings(RNGkind(sample.kind = "Rounding"))
    c1 <- .gk_with_seed(7, sample.int(100, 5))
    expect_identical(RNGkind()[[3L]], "Rounding")
    RNGkind(sample.kind = "Rejection")
  })
  c2 <- .gk_with_seed(7, sample.int(100, 5))
  expect_identical(c1, c2)
  rm_seed <- function() {
    if (exists(".Random.seed", envir = globalenv())) rm(".Random.seed", envir = globalenv())
  }
  withr::with_preserve_seed({
    rm_seed()
    .gk_with_seed(1, stats::runif(1))
    expect_false(exists(".Random.seed", envir = globalenv()))
  })
})

test_that("timestamps are UTC ISO-8601 seconds", {
  expect_match(.gk_utc_now(), "^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z$")
  expect_true(is.na(.gk_package_version("gatekeepR.not.installed")))
})
