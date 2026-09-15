test_that("locked exports verify and read back", {
  review <- gk_example_review()
  snapshot <- gk_lock(review, reviewer = "reviewer-01", status = "REVIEWED")
  expect_s3_class(snapshot, "gk_snapshot")
  expect_true(snapshot$production_eligible)
  dir <- tempfile("gatekeepR-export-")
  gk_export(snapshot, dir)
  checks <- gk_verify_export(dir, strict = FALSE)
  expect_true(all(checks$ok))
  imported <- gk_read_export(dir)
  expect_s3_class(imported, "gk_export")
  expect_identical(imported$snapshot$review_id, snapshot$review_id)
  expect_equal(nrow(imported$cells), nrow(review$prepared$cells))
  expect_equal(nrow(imported$state_calls), nrow(review$state_calls$calls))
  unlink(dir, recursive = TRUE)
})

test_that("export verification detects tampering and semantic contradictions", {
  review <- gk_example_review()
  snapshot <- gk_lock(review, reviewer = "reviewer-01")
  dir <- tempfile("gatekeepR-export-")
  gk_export(snapshot, dir)
  con <- file.path(dir, "ledgers", "cut_log.tsv")
  writeLines(c(readLines(con), "tampered"), con)
  expect_error(gk_verify_export(dir), class = "gatekeepr_error_verify")
  unlink(dir, recursive = TRUE)

  bad <- snapshot
  bad$replayed$cells$analysed[[1L]] <- TRUE
  bad$replayed$cells$disposition_effective[[1L]] <- "DELETE"
  bad_dir <- tempfile("gatekeepR-export-bad-")
  gk_export(bad, bad_dir)
  expect_error(gk_verify_export(bad_dir), class = "gatekeepr_error_verify")
  unlink(bad_dir, recursive = TRUE)
})
