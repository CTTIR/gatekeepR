# Independent boundary probes retain the original full review ID while changing
# transport bytes, so refreshed transport checksums cannot act as authority.
gk_refresh_boundary_transport <- function(dir, id) {
  .gk_write_manifest(dir, setdiff(.gk_list_files(dir), c("MANIFEST.sha256", "DONE")),
    done = list(review_id = id))
}

test_that("fractional integer fields cannot pass verification by truncation", {
  review <- gk_set_cut(gk_integrity_review(), "img-1", "A", estimate = 2.5,
    reviewer = "r", reason = "Original")
  snapshot <- gk_lock(review, "r")
  dir <- file.path(withr::local_tempdir(), "export")
  gk_export(snapshot, dir)
  path <- file.path(dir, "ledgers", "cut_log.tsv")
  table <- .gk_read_tsv(path)
  table$sequence <- "1.5"
  table$order <- "1.5"
  .gk_write_tsv(table, path)
  gk_refresh_boundary_transport(dir, snapshot$review_id)
  checks <- gk_verify_export(dir, strict = FALSE, expected_review_id = snapshot$review_id_full)
  expect_false(all(checks$ok))
  expect_error(gk_verify_export(dir, expected_review_id = snapshot$review_id_full), "integer")
})

test_that("source, model and schema edits remain bound to the review identity", {
  snapshot <- gk_lock(gk_integrity_review(duplicate_keys = TRUE), "r", "REVIEWED")
  dir <- file.path(withr::local_tempdir(), "export")
  gk_export(snapshot, dir)
  snapshot_path <- file.path(dir, "snapshot.json")
  original <- .gk_read_json(snapshot_path)
  changed <- original
  changed$source_sha256 <- strrep("0", 64)
  .gk_write_json(changed, snapshot_path)
  gk_refresh_boundary_transport(dir, snapshot$review_id)
  expect_error(gk_verify_export(dir, expected_review_id = snapshot$review_id_full), "review_identity")
  changed <- original
  changed$content$table_schemas[["scores.tsv.gz"]][["score__A"]] <- "list"
  .gk_write_json(changed, snapshot_path)
  gk_refresh_boundary_transport(dir, snapshot$review_id)
  expect_error(gk_verify_export(dir, expected_review_id = snapshot$review_id_full), "review_identity")
  .gk_write_json(original, snapshot_path)
  path <- file.path(dir, "correction_model.json")
  model <- .gk_read_json(path)
  model$model <- list(method = "substituted")
  .gk_write_json(model, path)
  gk_refresh_boundary_transport(dir, snapshot$review_id)
  expect_error(gk_verify_export(dir, expected_review_id = snapshot$review_id_full), "correction_model_hash")
})

test_that("both unlisted and manifest-listed extra export files are refused", {
  snapshot <- gk_lock(gk_integrity_review(), "r")
  dir <- file.path(withr::local_tempdir(), "export")
  gk_export(snapshot, dir)
  writeLines("unbound content", file.path(dir, "extra.tsv"))
  expect_error(gk_verify_export(dir), "no_unlisted_files")
  gk_refresh_boundary_transport(dir, snapshot$review_id)
  expect_error(gk_verify_export(dir), "export_files")
})

test_that("corrected-score exports replay reviewed cuts in the same score space", {
  original <- gk_integrity_review(duplicate_keys = TRUE)
  prepared <- original$prepared
  config <- original$config
  correction <- gk_correct(prepared, method = "robust_z")
  thresholds <- gk_thresholds(prepared, config, correction = correction)
  classified <- gk_classify(prepared, thresholds, config, correction = correction)
  states <- gk_state_calls(prepared, thresholds, classified, config)
  structures <- gk_structures(classified, prepared, min_cells = 2L, min_pts = 2L)
  review <- gk_review(classified, states, structures, thresholds, prepared)
  review <- gk_set_cut(review, "img-2", "A", estimate = 0, reviewer = "r", reason = "Corrected identity score")
  review <- gk_set_state(review, "img-2", "S", "A population", "SET_CUT", 0, "r", "Corrected state score")
  review <- gk_set_state(review, "img-2", "S", "A population", "ENABLE", reviewer = "r", reason = "Reviewed state")
  snapshot <- gk_lock(review, "r", "REVIEWED")
  dir <- file.path(withr::local_tempdir(), "corrected")
  gk_export(snapshot, dir)
  exported <- gk_read_export(dir, expected_review_id = snapshot$review_id_full)
  expect_true(all(exported$checks$ok))
  expect_identical(exported$scores$score__A, unname(correction$matrix[, "A"]))
  expect_identical(exported$state_calls$positive, gk_replay(review)$state_calls$positive)
  expect_identical(exported$cells$cell_type, gk_replay(review)$cells$cell_type)
})

test_that("top-level review provenance cannot diverge from its prepared base", {
  original <- gk_integrity_review()
  changed <- original
  changed$source_sha256 <- strrep("0", 64)
  expect_error(gk_lock(changed, "r"), "base source or configuration")
  changed <- original
  changed$config_sha256 <- strrep("0", 64)
  expect_error(gk_lock(changed, "r"), "base source or configuration")
  changed <- original
  changed$config$hierarchy$version <- "changed outside preparation"
  expect_error(gk_lock(changed, "r"), "base source or configuration")
})
