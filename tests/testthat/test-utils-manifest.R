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
  expect_false(identical(stale, stage))
  expect_true(dir.exists(stage))
  expect_true(dir.exists(stale))
})


test_that("staging and rollback never erase pre-existing pid-named directories", {
  root <- withr::local_tempdir()
  dir <- file.path(root, "out")
  for (suffix in c(".partial-", ".old-")) {
    existing <- paste0(dir, suffix, Sys.getpid())
    dir.create(existing)
    writeLines("preserve", file.path(existing, "sentinel"))
  }
  write_bound_dir(dir)
  stage <- .gk_stage_dir(dir, overwrite = TRUE)
  writeLines("replacement", file.path(stage, "new.txt"))
  .gk_write_manifest(stage, "new.txt")
  .gk_publish_dir(stage, dir, overwrite = TRUE)
  for (suffix in c(".partial-", ".old-"))
    expect_identical(readLines(file.path(paste0(dir, suffix, Sys.getpid()), "sentinel")), "preserve")
})

test_that("failed publication restores existing content and retains staged data", {
  dir <- file.path(withr::local_tempdir(), "out")
  write_bound_dir(dir)
  stage <- .gk_stage_dir(dir, overwrite = TRUE)
  writeLines("replacement", file.path(stage, "new.txt"))
  testthat::local_mocked_bindings(.gk_rename_dir = function(from, to) {
    if (identical(from, stage)) return(FALSE)
    file.rename(from, to)
  })
  expect_error(.gk_publish_dir(stage, dir, overwrite = TRUE), "previous directory was preserved")
  expect_identical(readLines(file.path(dir, "a.txt")), "a.txt")
  expect_identical(readLines(file.path(stage, "new.txt")), "replacement")
})

test_that("failed rollback preserves the old directory at the reported recovery path", {
  root <- withr::local_tempdir()
  dir <- file.path(root, "out")
  write_bound_dir(dir)
  stage <- .gk_stage_dir(dir, overwrite = TRUE)
  writeLines("replacement", file.path(stage, "new.txt"))
  target <- normalizePath(dir, winslash = "/", mustWork = TRUE)
  testthat::local_mocked_bindings(.gk_rename_dir = function(from, to) {
    if (!identical(from, target)) return(FALSE)
    file.rename(from, to)
  })
  expect_error(.gk_publish_dir(stage, dir, overwrite = TRUE), "previous directory is preserved at")
  old <- list.dirs(root, recursive = FALSE, full.names = TRUE)
  old <- old[grepl("out.old-", basename(old), fixed = TRUE)]
  expect_length(old, 1L)
  expect_identical(readLines(file.path(old, "checkpoint", "a.txt")), "a.txt")
  expect_identical(readLines(file.path(stage, "new.txt")), "replacement")
})

test_that("duplicate, backslash and noncanonical manifest paths fail before reads", {
  dir <- file.path(withr::local_tempdir(), "out")
  write_bound_dir(dir)
  original <- readLines(file.path(dir, "MANIFEST.sha256"))
  writeLines(c(original, original[[1L]]), file.path(dir, "MANIFEST.sha256"))
  checks <- .gk_manifest_checks(dir)
  expect_false(checks$ok[checks$check == "manifest_paths_unique"])
  bad_paths <- c("../escape", "a/../escape", "/absolute", "C:/absolute", "a\\b", "a//b", "./a", "a/.")
  for (path in bad_paths) {
    writeLines(paste0(strrep("0", 64), "  ", path), file.path(dir, "MANIFEST.sha256"))
    checks <- .gk_manifest_checks(dir)
    expect_false(checks$ok[checks$check == "manifest_paths_safe"], info = path)
  }
  expect_error(.gk_write_manifest(dir, c("a.txt", "a.txt")), "unique regular files")
})

test_that("manifests reject directories and symlinks without traversing them", {
  root <- withr::local_tempdir()
  dir <- file.path(root, "out")
  write_bound_dir(dir)
  writeLines(paste0(strrep("0", 64), "  sub"), file.path(dir, "MANIFEST.sha256"))
  checks <- .gk_manifest_checks(dir)
  expect_false(checks$ok[checks$check == "listed_files_regular"])
  outside <- file.path(root, "outside")
  dir.create(outside)
  writeLines("external", file.path(outside, "external.txt"))
  link <- file.path(dir, "link")
  if (!file.symlink(outside, link)) skip("Symbolic links unavailable")
  withr::defer(fs::link_delete(link))
  writeLines(paste0(strrep("0", 64), "  link/external.txt"), file.path(dir, "MANIFEST.sha256"))
  checks <- .gk_manifest_checks(dir)
  expect_false(checks$ok[checks$check == "listed_files_regular"])
  expect_true("link" %in% .gk_list_files(dir))
  expect_false("link/external.txt" %in% .gk_list_files(dir))
  expect_error(.gk_write_manifest(dir, "link/external.txt"), "regular files")
  unlink(file.path(dir, "DONE"))
  file.symlink(file.path(outside, "external.txt"), file.path(dir, "DONE"))
  withr::defer(fs::link_delete(file.path(dir, "DONE")))
  checks <- .gk_manifest_checks(dir)
  expect_false(checks$ok[checks$check == "control_files_regular"])
})


test_that("unexpected publication errors restore the previous directory", {
  dir <- file.path(withr::local_tempdir(), "out")
  write_bound_dir(dir)
  stage <- .gk_stage_dir(dir, overwrite = TRUE)
  writeLines("replacement", file.path(stage, "new.txt"))
  testthat::local_mocked_bindings(.gk_rename_dir = function(from, to) {
    if (identical(from, stage)) cli::cli_abort("simulated interrupted rename")
    file.rename(from, to)
  })
  expect_error(.gk_publish_dir(stage, dir, overwrite = TRUE), "simulated interrupted rename")
  expect_identical(readLines(file.path(dir, "a.txt")), "a.txt")
  expect_identical(readLines(file.path(stage, "new.txt")), "replacement")
})

test_that("DONE fields cannot contain duplicate identities", {
  dir <- file.path(withr::local_tempdir(), "out")
  write_bound_dir(dir)
  path <- file.path(dir, "DONE")
  writeLines(c(readLines(path), "review_id another-identity"), path)
  checks <- .gk_manifest_checks(dir)
  expect_false(checks$ok[checks$check == "done_well_formed"])
})
