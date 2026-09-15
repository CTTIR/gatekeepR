test_that("review actions are immutable and replay in ledger order", {
  review <- gk_example_review()
  img <- unique(review$prepared$cells$image_id)
  cell <- review$prepared$cells$cell_id[[1L]]
  changed <- gk_set_cut(review, img, "PanCK", estimate = 1,
    reviewer = "reviewer-01", reason = "manual review")
  changed <- gk_dispose(changed, img, cell_id = cell, disposition = "EXCLUDE",
    reviewer = "reviewer-01", reason = "artefact")
  expect_equal(sum(vapply(gk_ledgers(review), nrow, integer(1))), 0L)
  ledgers <- gk_ledgers(changed)
  expect_identical(ledgers$cut_log$entry_id, "CL0001")
  expect_identical(ledgers$disposition_log$entry_id, "XR0002")
  expect_identical(ledgers$cut_log$order, 1L)
  expect_identical(ledgers$disposition_log$order, 2L)
  effective <- gk_replay(changed)$cells
  expect_identical(effective$disposition_effective[[1L]], "EXCLUDE")
  expect_false(effective$analysed[[1L]])
})

test_that("structure decisions resolve pending labels and RESTORE reverses disposition", {
  review <- gk_example_review()
  img <- unique(review$prepared$cells$image_id)
  sid <- review$structures$structures$structure_id[[1L]]
  changed <- gk_decide_structure(review, img, structure_id = sid, decision = "Tumor",
    reviewer = "reviewer-01", reason = "structure review")
  replayed <- gk_replay(changed)$cells
  affected <- !is.na(replayed$structure_id) & replayed$structure_id == sid
  expect_true(any(affected))
  expect_true(all(replayed$cell_type[affected] == "Tumor cells"))
  expect_false(any(replayed$pending_review[affected]))
  cell <- review$prepared$cells$cell_id[[1L]]
  changed <- gk_dispose(changed, img, cell_id = cell, disposition = "DELETE",
    reviewer = "reviewer-01", reason = "remove artefact")
  changed <- gk_dispose(changed, img, cell_id = cell, disposition = "RESTORE",
    reviewer = "reviewer-01", reason = "restore after review")
  expect_identical(gk_replay(changed)$cells$disposition_effective[[1L]], "NONE")
})

test_that("cut import is isolated and replacement requires a backup", {
  review <- gk_example_review()
  img <- unique(review$prepared$cells$image_id)
  changed <- gk_dispose(review, img, cell_id = review$prepared$cells$cell_id[[1L]],
    disposition = "EXCLUDE", reviewer = "reviewer-01", reason = "artefact")
  path <- tempfile(fileext = ".tsv")
  writeLines(c("image_id\tmarker\testimate", paste(img, "PanCK", "1", sep = "\t")), path)
  imported <- gk_import_cuts(changed, path, reviewer = "reviewer-01", reason = "batch import")
  expect_equal(nrow(gk_ledgers(imported)$structure_log), 0L)
  expect_equal(nrow(gk_ledgers(imported)$disposition_log), 1L)
  expect_error(gk_replace_review(imported, tempfile(), scope = "cuts"),
    class = "gatekeepr_error_confirm")
  saved <- tempfile("review-source-")
  gk_save_review(review, saved)
  replaced <- gk_replace_review(imported, saved, scope = "cuts", confirm = TRUE)
  expect_true(dir.exists(attr(replaced, "backup_path")))
  expect_equal(nrow(gk_ledgers(replaced)$disposition_log), 1L)
  unlink(c(path, saved, attr(replaced, "backup_path")), recursive = TRUE)
})

test_that("review checkpoints round trip and lock the working directory", {
  review <- gk_example_review()
  img <- unique(review$prepared$cells$image_id)
  review <- gk_set_cut(review, img, "PanCK", estimate = 1,
    reviewer = "reviewer-01", reason = "manual review")
  dir <- tempfile("review-checkpoint-")
  gk_save_review(review, dir)
  loaded <- gk_load_review(dir)
  expect_identical(gk_replay(loaded)$cells, gk_replay(review)$cells)
  expect_true(file.exists(file.path(dir, "review.lock")))
  expect_no_error(gk_load_review(dir))
  unlink(dir, recursive = TRUE)
})
