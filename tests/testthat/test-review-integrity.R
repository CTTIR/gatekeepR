test_that("identity review cuts recalculate calls, labels and effective thresholds", {
  review <- gk_integrity_review()
  changed <- gk_set_cut(review, "img-1", "A", estimate = 2.5, reviewer = "r", reason = "Inspect cells")
  effective <- gk_replay(changed)
  expect_identical(effective$cells$pending_review, rep(seq_len(12) > 2.5, 2))
  expect_identical(effective$thresholds$estimate, 2.5)
  expect_identical(jsonlite::fromJSON(effective$thresholds$args_json)$value, 2.5)
  expect_identical(effective$thresholds$evidence_ref, review$thresholds$evidence_ref)
  expect_match(effective$thresholds$details, "CL0001", fixed = TRUE)
  expect_identical(review$thresholds$estimate, 6.5)
  expect_identical(effective$cells$base_cell_type, review$classification$cells$cell_type)
  again <- gk_set_cut(changed, "img-1", "A", estimate = 9.5, reviewer = "r", reason = "Inspect again")
  expect_identical(again$ledgers$cut_log$old_estimate, c(6.5, 2.5))
  undone <- gk_revert_last(again, "r", "Restore previous cut")
  expect_identical(gk_replay(undone)$cells, effective$cells)
  redone <- gk_revert_last(undone, "r", "Reapply decision")
  expect_identical(gk_replay(redone)$cells, gk_replay(again)$cells)
  expect_identical(undone$ledgers$cut_log[1:2, ], again$ledgers$cut_log)
})

test_that("state cuts and enablement are independent and undoable", {
  review <- gk_integrity_review()
  cut <- gk_set_cut(review, "img-1", "S", "A population", 8.5, "r", "State cut")
  enabled <- gk_set_state(cut, "img-1", "S", "A population", "ENABLE", reviewer = "r", reason = "Enable state")
  state <- gk_replay(enabled)$state_calls
  expect_true(all(state$enabled))
  expect_true(all(state$estimate == 8.5))
  expect_identical(state$positive, rep(seq_len(12) > 8.5, 2))
  recut <- gk_set_state(enabled, "img-1", "S", "A population", "SET_CUT", 10.5, "r", "Raise cut")
  expect_true(all(gk_replay(recut)$state_calls$enabled))
  expect_true(all(gk_replay(recut)$state_calls$estimate == 10.5))
  disabled <- gk_set_state(recut, "img-1", "S", "A population", "DISABLE", reviewer = "r", reason = "Disable state")
  expect_false(any(gk_replay(disabled)$state_calls$enabled))
  expect_true(all(gk_replay(disabled)$state_calls$estimate == 10.5))
  restored <- gk_revert_last(disabled, "r", "Restore enabled state")
  expect_identical(gk_replay(restored)$state_calls, gk_replay(recut)$state_calls)
})

test_that("undo restores prior overlapping dispositions and structure decisions", {
  review <- gk_integrity_review()
  excluded <- gk_dispose(review, "img-1", bbox = c(1, 12, 1, 1), disposition = "EXCLUDE", reviewer = "r", reason = "Region")
  deleted <- gk_dispose(excluded, "img-1", cell_id = "c0001", disposition = "DELETE", reviewer = "r", reason = "Cell")
  undone <- gk_revert_last(deleted, "r", "Restore region decision")
  expect_identical(gk_replay(undone)$cells$disposition_effective, rep(c("EXCLUDE", "NONE"), each = 12))
  sid <- review$structures$structures$structure_id[[1L]]
  tumor <- gk_decide_structure(review, "img-1", structure_id = sid, decision = "Tumor", reviewer = "r", reason = "Structure")
  benign <- gk_decide_structure(tumor, "img-1", bbox = c(1, 24, 1, 1), decision = "Benign", reviewer = "r", reason = "Whole region")
  restored <- gk_revert_last(benign, "r", "Restore prior structure")
  expect_identical(gk_replay(restored)$cells, gk_replay(tumor)$cells)
})

test_that("constructor rejects foreign and incomplete state call sets", {
  review <- gk_integrity_review()
  states <- review$state_calls
  states$calls <- states$calls[-1, ]
  expect_error(gk_review(review$classification, states, review$structures, review$thresholds, review$prepared), "ordered cell")
  states <- review$state_calls
  states$classification_sha256 <- "foreign"
  expect_error(gk_review(review$classification, states, review$structures, review$thresholds, review$prepared), "do not match")
})

gk_integrity_refresh_manifest <- function(dir) {
  .gk_write_manifest(dir, setdiff(.gk_list_files(dir), c("review.lock", "MANIFEST.sha256", "DONE")))
}

test_that("checkpoints reject divergent ledgers and metadata even with refreshed checksums", {
  review <- gk_set_cut(gk_integrity_review(), "img-1", "A", estimate = 2.5, reviewer = "r", reason = "Original")
  dir <- file.path(withr::local_tempdir(), "checkpoint")
  gk_save_review(review, dir)
  path <- file.path(dir, "ledgers", "cut_log.tsv")
  ledger <- .gk_read_tsv(path, types = .gk_ledger_types)
  ledger$reason <- "Changed outside checkpoint"
  .gk_write_tsv(ledger, path)
  gk_integrity_refresh_manifest(dir)
  expect_error(gk_load_review(dir), "differs from the checkpoint")
  expect_error(gk_replace_review(review, dir, scope = "all", confirm = TRUE), "differs from the checkpoint")
  expect_false(file.exists(file.path(dir, "review.lock")))
  gk_save_review(review, dir, overwrite = TRUE)
  metadata <- .gk_read_json(file.path(dir, "metadata.json"))
  metadata$source_sha256 <- "foreign"
  .gk_write_json(metadata, file.path(dir, "metadata.json"))
  gk_integrity_refresh_manifest(dir)
  expect_error(gk_load_review(dir), "metadata does not match")
})

test_that("same-process checkpoint readers cannot silently overwrite each other", {
  dir <- file.path(withr::local_tempdir(), "checkpoint")
  gk_save_review(gk_integrity_review(), dir)
  first <- gk_load_review(dir)
  second <- gk_load_review(dir)
  first <- gk_set_cut(first, "img-1", "A", estimate = 2.5, reviewer = "r", reason = "First session")
  saved <- gk_save_review(first, dir, overwrite = TRUE)
  second <- gk_set_cut(second, "img-1", "A", estimate = 9.5, reviewer = "r", reason = "Stale session")
  expect_error(gk_save_review(second, dir, overwrite = TRUE), "checkpoint changed")
  expect_identical(gk_load_review(dir)$ledgers$cut_log$new_estimate, 2.5)
  first$checkpoint_revision <- attr(saved, "checkpoint_revision")
  first <- gk_dispose(first, "img-1", cell_id = "c0001", disposition = "EXCLUDE", reviewer = "r", reason = "Continue")
  expect_no_error(gk_save_review(first, dir, overwrite = TRUE))
})

test_that("replacement rejects ambiguous order collisions and locked targets", {
  review <- gk_integrity_review()
  incoming <- gk_set_cut(review, "img-1", "A", estimate = 2.5, reviewer = "r", reason = "Cut")
  dir <- file.path(withr::local_tempdir(), "incoming")
  gk_save_review(incoming, dir)
  current <- gk_dispose(review, "img-1", cell_id = "c0001", disposition = "EXCLUDE", reviewer = "r", reason = "Cell")
  expect_error(gk_replace_review(current, dir, scope = "cuts", confirm = TRUE), "globally unique")
  current$locked <- TRUE
  expect_error(gk_replace_review(current, dir, scope = "all", confirm = TRUE), class = "gatekeepr_error_locked")
})

test_that("malformed ledger actions are rejected before replay or save", {
  review <- gk_set_cut(gk_integrity_review(), "img-1", "A", estimate = 2.5, reviewer = "r", reason = "Cut")
  review$ledgers$cut_log$new_estimate <- Inf
  expect_error(gk_replay(review), "finite")
  dir <- file.path(withr::local_tempdir(), "invalid")
  expect_error(gk_save_review(review, dir), "finite")
  expect_false(dir.exists(dir))
})


test_that("manual state cuts cannot create support for missing measurements", {
  review <- gk_integrity_review(rep(NA_real_, 24))
  changed <- gk_set_state(review, "img-1", "S", "A population", "SET_CUT", -100, "r", "Manual inspection")
  changed <- gk_set_state(changed, "img-1", "S", "A population", "ENABLE", reviewer = "r", reason = "Enable")
  state <- gk_replay(changed)$state_calls
  expect_false(any(state$evaluable))
  expect_false(any(state$positive))
  expect_true(all(state$enabled))
})

test_that("state scores and threshold provenance cannot be substituted", {
  review <- gk_integrity_review()
  altered <- review$state_calls
  altered$calls$score[[1L]] <- 1000
  expect_error(gk_review(review$classification, altered, review$structures,
    review$thresholds, review$prepared), "Base state calls differ")
  altered <- review$state_calls
  attr(altered$state_thresholds, "score_sha256") <- "foreign"
  expect_error(gk_review(review$classification, altered, review$structures,
    review$thresholds, review$prepared), "provenance")
})


test_that("replay joins use image and cell together when local IDs repeat", {
  review <- gk_integrity_review(duplicate_keys = TRUE)
  changed <- gk_set_cut(review, "img-1", "A", estimate = 2.5, reviewer = "r", reason = "Image one")
  replayed <- gk_replay(changed)
  expect_identical(replayed$cells$x, as.double(c(seq_len(12), 100 + seq_len(12))))
  expect_identical(replayed$state_calls$in_parent, c(seq_len(12) > 2.5, seq_len(12) > 6.5))
  changed <- gk_decide_structure(changed, "img-2", bbox = c(107, 112, 1, 1), decision = "Tumor", reviewer = "r", reason = "Second image region")
  replayed <- gk_replay(changed)
  expect_true(all(replayed$cells$cell_type[19:24] == "Tumor"))
  expect_false(any(replayed$cells$cell_type[1:12] == "Tumor"))
  changed <- gk_dispose(changed, "img-2", cell_id = "c0001", disposition = "EXCLUDE", reviewer = "r", reason = "Second image cell")
  expect_identical(which(gk_replay(changed)$cells$disposition_effective == "EXCLUDE"), 13L)
  changed <- gk_decide_structure(changed, "img-1", bbox = c(1, 12, 1, 1), decision = "Tumor", reviewer = "r", reason = "First image region")
  changed <- gk_set_state(changed, "img-2", "S", "A population", "ENABLE", reviewer = "r", reason = "Only second image")
  replayed <- gk_replay(changed)
  expect_true(all(replayed$cells$cell_type[19:24] == "State-positive Tumor"))
  expect_true(all(replayed$cells$cell_type[7:12] == "Tumor"))
})


test_that("legacy checkpoints are preserved and require explicit re-review", {
  dir <- file.path(withr::local_tempdir(), "legacy")
  gk_save_review(gk_integrity_review(), dir)
  metadata <- .gk_read_json(file.path(dir, "metadata.json"))
  metadata$schema_version <- "1.0.0"
  .gk_write_json(metadata, file.path(dir, "metadata.json"))
  gk_integrity_refresh_manifest(dir)
  before <- .gk_sha256_file(file.path(dir, "review.rds"))
  expect_error(gk_load_review(dir), "Legacy checkpoint provenance")
  expect_identical(.gk_sha256_file(file.path(dir, "review.rds")), before)
  expect_false(file.exists(file.path(dir, "review.lock")))
})


test_that("edited base state scores are rejected before replay or checkpoint output", {
  review <- gk_integrity_review()
  review$state_calls$calls$score[[1L]] <- 1000
  expect_error(gk_replay(review), "Base state calls differ")
  dir <- file.path(withr::local_tempdir(), "edited-base")
  expect_error(gk_save_review(review, dir), "Base state calls differ")
  expect_false(dir.exists(dir))
})
