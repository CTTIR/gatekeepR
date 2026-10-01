test_that("saving cannot overwrite a review owned by another session", {
  dir <- file.path(withr::local_tempdir(), "review with spaces")
  review <- gk_example_review()
  gk_save_review(review, dir)
  writeLines(c("pid 1", "host other-session", "time_utc original"),
    file.path(dir, "review.lock"))
  prior <- readBin(file.path(dir, "review.rds"), "raw", file.info(file.path(dir, "review.rds"))$size)
  expect_error(gk_save_review(review, dir, overwrite = TRUE),
    class = "gatekeepr_error_lockfile")
  expect_identical(readLines(file.path(dir, "review.lock")),
    c("pid 1", "host other-session", "time_utc original"))
  expect_identical(readBin(file.path(dir, "review.rds"), "raw", length(prior)), prior)
})

test_that("saving preserves the current session ownership and prior checkpoint", {
  dir <- file.path(withr::local_tempdir(), "owned review")
  gk_save_review(gk_example_review(), dir)
  review <- gk_load_review(dir)
  ownership <- readLines(file.path(dir, "review.lock"))
  gk_save_review(review, dir, overwrite = TRUE)
  expect_identical(readLines(file.path(dir, "review.lock")), ownership)
  expect_true(file.exists(file.path(dir, "checkpoint.prev")))
  expect_identical(gk_replay(gk_load_review(dir))$cells, gk_replay(review)$cells)
})

test_that("malformed ownership is refused until explicit takeover", {
  dir <- file.path(withr::local_tempdir(), "malformed ownership")
  gk_save_review(gk_example_review(), dir)
  for (lines in list(character(), "", "host incomplete",
    c("pid 1", "pid 2", "host x", "time_utc x"),
    c(paste("pid", paste0(Sys.getpid(), ".5")),
      paste("host", Sys.info()[["nodename"]]), "time_utc "),
    c(paste("pid", Sys.getpid()), paste("host", Sys.info()[["nodename"]]), "time_utc "))) {
    writeLines(lines, file.path(dir, "review.lock"))
    expect_error(gk_load_review(dir), class = "gatekeepr_error_lockfile")
    expect_error(gk_save_review(gk_example_review(), dir, overwrite = TRUE),
      class = "gatekeepr_error_lockfile")
    expect_s3_class(gk_load_review(dir, takeover = TRUE), "gk_review")
  }
})

test_that("operation locks prevent another process from saving or loading", {
  skip_if_not_installed("callr")
  dir <- file.path(withr::local_tempdir(), "concurrent review")
  gk_save_review(gk_example_review(), dir)
  hold <- .gk_review_operation_lock(dir)
  withr::defer(filelock::unlock(hold))
  pkg <- system.file(package = "gatekeepR")
  aliases <- c(dir, paste0(dir, "/"), file.path(dir, "."))
  link <- file.path(dirname(dir), "review alias")
  if (suppressWarnings(file.symlink(dir, link))) aliases <- c(aliases, link)
  result <- callr::r(function(pkg, aliases, review) {
    if (file.exists(file.path(pkg, "Meta", "package.rds"))) {
      library(gatekeepR, lib.loc = dirname(pkg))
    } else {
      pkgload::load_all(pkg, quiet = TRUE)
    }
    capture <- function(expr) tryCatch({force(expr); "UNEXPECTED_SUCCESS"},
      error = function(e) {
        if (inherits(e, "gatekeepr_error_lockfile")) return(class(e)[[1L]])
        paste(class(e)[[1L]], conditionMessage(e))
      })
    unlist(lapply(aliases, function(dir) {
      c(save = capture(gk_save_review(review, dir, overwrite = TRUE)),
        load = capture(gk_load_review(dir, takeover = TRUE)))
    }), use.names = FALSE)
  }, args = list(pkg = pkg, aliases = aliases, review = gk_example_review()))
  expect_identical(result, rep("gatekeepr_error_lockfile", 2L * length(aliases)))
  filelock::unlock(hold)
  expect_no_error(gk_save_review(gk_example_review(), dir, overwrite = TRUE))
})

test_that("failed checkpoint publication releases its operation lock", {
  skip_if_not_installed("callr")
  dir <- file.path(withr::local_tempdir(), "publication failure")
  review <- gk_example_review()
  gk_save_review(review, dir)
  original <- readBin(file.path(dir, "review.rds"), "raw", file.info(file.path(dir, "review.rds"))$size)
  testthat::local_mocked_bindings(.gk_publish_dir = function(...) cli::cli_abort("publish interrupted"))
  expect_error(gk_save_review(review, dir, overwrite = TRUE), "publish interrupted")
  expect_identical(readBin(file.path(dir, "review.rds"), "raw", length(original)), original)
  path <- file.path(dirname(dir), paste0(".", basename(dir), ".gatekeepR.lock"))
  released <- callr::r(function(path) {
    hold <- filelock::lock(path, timeout = 0)
    if (is.null(hold)) return(FALSE)
    filelock::unlock(hold)
    TRUE
  }, args = list(path = path))
  expect_true(released)
})

test_that("review lock cannot create an invalid parent directory", {
  parent <- tempfile()
  writeLines("not a directory", parent)
  withr::defer(unlink(parent))
  expect_error(.gk_review_operation_lock(file.path(parent, "child")),
    class = "gatekeepr_error_input")
})


test_that("review identities are canonical without creating missing load parents", {
  parent <- withr::local_tempdir()
  nested <- file.path(parent, "new", "review")
  expect_error(gk_load_review(nested), class = "gatekeepr_error_input")
  expect_false(dir.exists(dirname(nested)))
  expect_identical(.gk_review_path(nested), file.path(normalizePath(parent, winslash = "/"), "new", "review"))
  expect_error(.gk_review_path("/"), class = "gatekeepr_error_input")
  expect_error(.gk_review_path("/."), class = "gatekeepr_error_input")
})
