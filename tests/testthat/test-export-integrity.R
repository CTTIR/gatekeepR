gk_export_refresh_transport <- function(dir, id) {
  .gk_write_manifest(dir, setdiff(.gk_list_files(dir), c("MANIFEST.sha256", "DONE")),
    done = list(review_id = id))
}

test_that("version 2 binds real source, reviewer, status and effective contents", {
  review <- gk_integrity_review(duplicate_keys = TRUE)
  changed <- gk_set_cut(review, "img-2", "A", estimate = 2.5, reviewer = "r", reason = "Second image")
  changed <- gk_set_state(changed, "img-2", "S", "A population", "ENABLE", reviewer = "r", reason = "State review")
  changed <- gk_dispose(changed, "img-2", cell_id = "c0001", disposition = "DELETE", reviewer = "r", reason = "Second image only")
  snapshot <- gk_lock(changed, "r", "REVIEWED")
  expect_identical(gk_lock(changed, "r", "REVIEWED")$review_id_full, snapshot$review_id_full)
  expect_false(identical(gk_lock(changed, "r", "PENDING")$review_id, snapshot$review_id))
  expect_false(identical(gk_lock(changed, "other", "REVIEWED")$review_id, snapshot$review_id))
  expect_false(identical(gk_lock(gk_integrity_review(), "r")$review_id, gk_lock(review, "r")$review_id))
  dir <- file.path(withr::local_tempdir(), "export")
  gk_export(snapshot, dir)
  exported <- gk_read_export(dir, expected_review_id = snapshot$review_id_full)
  expect_true(all(exported$checks$ok))
  expect_identical(exported$cells$x, review$prepared$cells$x)
  expect_identical(exported$cells$analysed, c(rep(TRUE, 12), FALSE, rep(TRUE, 11)))
  expect_identical(exported$state_calls$positive, gk_replay(changed)$state_calls$positive)
  expect_error(gk_verify_export(dir, expected_review_id = paste(rep("0", 64), collapse = "")), "expected_review_identity")
})

test_that("refreshed transport checksums cannot conceal semantic tampering", {
  review <- gk_set_cut(gk_integrity_review(), "img-1", "A", estimate = 2.5, reviewer = "r", reason = "Original reason")
  snapshot <- gk_lock(review, "r")
  root <- withr::local_tempdir()
  dir <- file.path(root, "export")
  gk_export(snapshot, dir)
  paths <- c("ledgers/cut_log.tsv", "scores.tsv.gz", "state_calls.tsv.gz",
    "replay/raw_scores.tsv.gz", "replay/prepared_cells.tsv.gz")
  fields <- c("reason", "score__A", "positive", "A", "x")
  values <- list("Changed reason", 999, TRUE, 999, 999)
  for (i in seq_along(paths)) {
    path <- file.path(dir, paths[[i]])
    backup <- tempfile(tmpdir = root)
    file.copy(path, backup)
    table <- .gk_read_tsv(path, types = unlist(snapshot$content$table_schemas[[paths[[i]]]]))
    table[[fields[[i]]]][1L] <- values[[i]]
    .gk_write_tsv(table, path)
    gk_export_refresh_transport(dir, snapshot$review_id)
    expect_error(gk_verify_export(dir), "content_", info = paths[[i]])
    expect_false(all(gk_verify_export(dir, strict = FALSE)$ok))
    file.copy(backup, path, overwrite = TRUE)
  }
  path <- file.path(dir, "snapshot.json")
  payload <- .gk_read_json(path)
  payload$production_eligible <- TRUE
  .gk_write_json(payload, path)
  gk_export_refresh_transport(dir, snapshot$review_id)
  expect_error(gk_verify_export(dir), "review_identity")
})

test_that("mutated snapshots fail before publication and legacy inspection is explicit", {
  snapshot <- gk_lock(gk_integrity_review(), "r")
  dir <- file.path(withr::local_tempdir(), "export")
  bad <- snapshot
  bad$review$prepared$cells$x[1L] <- 99
  expect_error(gk_export(bad, dir), "changed after locking")
  expect_false(dir.exists(dir))
  gk_export(snapshot, dir)
  payload <- .gk_read_json(file.path(dir, "snapshot.json"))
  payload$format_version <- NULL
  .gk_write_json(payload, file.path(dir, "snapshot.json"))
  gk_export_refresh_transport(dir, snapshot$review_id)
  expect_error(gk_read_export(dir), "Legacy or unknown")
  expect_s3_class(gk_read_export(dir, verify = FALSE), "gk_export")
  writeLines("invalid JSON", file.path(dir, "snapshot.json"))
  gk_export_refresh_transport(dir, snapshot$review_id)
  expect_false(all(gk_verify_export(dir, strict = FALSE)$ok))
})

test_that("typed table hashes distinguish ambiguous strings and survive text transport", {
  left <- data.frame(value = c("a\nb", "c", NA_character_))
  right <- data.frame(value = c("a", "b\nc", "\001NA"))
  expect_false(identical(.gk_table_hash(left), .gk_table_hash(right)))
  table <- data.frame(id = c("NA", "x\ty", 'a""b'), value = c(NaN, -0, pi),
    flag = c(TRUE, FALSE, NA))
  path <- withr::local_tempfile(fileext = ".tsv.gz")
  .gk_write_tsv(table, path)
  read <- .gk_read_tsv(path, types = .gk_table_schema(table))
  expect_identical(.gk_table_hash(read), .gk_table_hash(table))
})
