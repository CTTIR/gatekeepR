write_bound_dir <- function(dir, files = c("a.txt", "sub/b.txt")) {
  stage <- .gk_stage_dir(dir)
  for (f in files) {
    dir.create(dirname(file.path(stage, f)), showWarnings = FALSE, recursive = TRUE)
    writeLines(f, file.path(stage, f))
  }
  .gk_write_manifest(stage, files, done = list(review_id = "gk-test"))
  .gk_publish_dir(stage, dir)
}

test_that("manifest-bound directories verify and expose DONE fields", {
  dir <- file.path(withr::local_tempdir(), "bound dir")
  write_bound_dir(dir)
  checks <- .gk_manifest_checks(dir, allow_extra = FALSE)
  expect_true(all(checks$ok))
  expect_identical(.gk_read_done(dir)$fields[["review_id"]], "gk-test")
  expect_identical(.gk_list_files(dir), c("DONE", "MANIFEST.sha256", "a.txt", "sub/b.txt"))
})

test_that("changed, missing, unlisted and unsafe entries are reported", {
  dir <- file.path(withr::local_tempdir(), "d")
  write_bound_dir(dir)
  writeLines("changed", file.path(dir, "a.txt"))
  writeLines("stray", file.path(dir, ".DS_Store"))
  checks <- .gk_manifest_checks(dir, allow_extra = FALSE)
  expect_false(checks$ok[checks$check == "file_hashes_match"])
  expect_false(checks$ok[checks$check == "no_unlisted_files"])
  expect_match(checks$details[checks$check == "no_unlisted_files"], ".DS_Store", fixed = TRUE)
  expect_snapshot(
    .gk_verify_manifest(dir, class = "verify", allow_extra = FALSE),
    error = TRUE,
    transform = function(x) gsub(dir, "<review-dir>", x, fixed = TRUE)
  )
  unlink(file.path(dir, "sub"), recursive = TRUE)
  checks <- .gk_manifest_checks(dir)
  expect_false(checks$ok[checks$check == "listed_files_present"])

  dir2 <- file.path(withr::local_tempdir(), "d2")
  write_bound_dir(dir2)
  man <- readLines(file.path(dir2, "MANIFEST.sha256"))
  writeLines(c(man, paste0(strrep("0", 64), "  ../escape.txt"), "garbage"), file.path(dir2, "MANIFEST.sha256"))
  checks <- .gk_manifest_checks(dir2)
  expect_false(checks$ok[checks$check == "done_matches_manifest"])
  expect_false(checks$ok[checks$check == "manifest_well_formed"])
  expect_false(checks$ok[checks$check == "manifest_paths_safe"])

  dir3 <- file.path(withr::local_tempdir(), "d3")
  dir.create(dir3)
  checks <- .gk_manifest_checks(dir3)
  expect_identical(checks$ok, c(FALSE, FALSE))
})

test_that("staging refuses to overwrite unless asked and cleans up", {
  root <- withr::local_tempdir()
  dir <- file.path(root, "out")
  write_bound_dir(dir)
  expect_error(.gk_stage_dir(dir), class = "gatekeepr_error_input")
  stage <- .gk_stage_dir(dir, overwrite = TRUE)
  writeLines("new", file.path(stage, "a.txt"))
  .gk_write_manifest(stage, "a.txt")
  expect_error(.gk_publish_dir(stage, dir), class = "gatekeepr_error_input")
  .gk_publish_dir(stage, dir, overwrite = TRUE)
  expect_identical(readLines(file.path(dir, "a.txt")), "new")
  expect_identical(list.files(root), "out")
  nested <- file.path(root, "deep", "er", "x")
  stage <- .gk_stage_dir(nested)
  expect_true(dir.exists(stage))
  stale <- .gk_stage_dir(nested)
  expect_identical(stale, stage)
})
