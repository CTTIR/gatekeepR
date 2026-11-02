# Immutable snapshots, content-addressed exports and replay verification.

.gk_export_thresholds <- function(snapshot) {
  rbind(as.data.frame(snapshot$review$thresholds),
    as.data.frame(snapshot$review$state_calls$state_thresholds))
}

.gk_export_correction_hash <- function(review) {
  correction <- review$classification$correction
  .gk_sha256_object(if (is.null(correction)) "none" else correction$model)
}

.gk_export_ledgers_hash <- function(review) .gk_sha256_object(review$ledgers)

.gk_snapshot_payload <- function(snapshot) {
  snapshot[setdiff(names(snapshot), c("review", "replayed"))]
}

#' Lock a review into an immutable snapshot
#'
#' The version 2 review ID binds source identity, typed replay inputs, effective
#' outputs, ledgers, correction model, reviewer and status. It is a content hash,
#' not a signature or proof of a reviewer's identity. REVIEWED records the human
#' reviewer's assertion; it does not certify scientific or clinical validity.
#'
#' @param review A [gk_review()] object.
#' @param reviewer Reviewer identifier.
#' @param status `"PENDING"` or `"REVIEWED"`.
#' @return An object of class `gk_snapshot`.
#' @family export
#' @export
gk_lock <- function(review, reviewer, status = c("PENDING", "REVIEWED")) {
  .gk_review_check(review)
  .gk_check_reviewer(reviewer)
  status <- rlang::arg_match(status)
  # Validate the base objects independently of their append-only ledgers.
  gk_review(review$classification, review$state_calls, review$structures,
    review$thresholds, review$prepared)
  soft <- extSoftVersion()
  snapshot <- list(
    schema = "gatekeepR-snapshot", format_version = 2L,
    status = status, production_eligible = identical(status, "REVIEWED"),
    reviewer = reviewer, locked_utc = .gk_utc_now(),
    source_sha256 = review$source_sha256,
    source_manifest_sha256 = review$prepared$source_manifest_sha256,
    config_sha256 = review$config_sha256,
    thresholds_sha256 = .gk_sha256_object(.gk_export_thresholds(list(review = review))),
    correction_model_sha256 = .gk_export_correction_hash(review),
    ledgers_sha256 = .gk_export_ledgers_hash(review),
    package_version = .gk_package_version(),
    session = list(r_version = R.version$version.string, platform = R.version$platform,
      blas = unname(soft["BLAS"]), lapack = unname(soft["LAPACK"]),
      packages = list(gatekeepR = .gk_package_version(),
        cellspecR = .gk_package_version("cellspecR"),
        jsonlite = .gk_package_version("jsonlite")), time_utc = .gk_utc_now()),
    review = review, replayed = gk_replay(review)
  )
  snapshot$content <- .gk_export_content(snapshot)
  full <- .gk_sha256_object(.gk_export_identity(snapshot))
  snapshot$review_id_full <- full
  snapshot$review_id <- paste0("gk-", substr(full, 1L, 16L))
  class(snapshot) <- "gk_snapshot"
  snapshot
}

.gk_export_with_id <- function(df, review_id) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  cbind(review_id = rep(review_id, nrow(df)), df, row.names = NULL)
}

#' Write a locked review export
#'
#' Modified snapshots are rejected before writing. Staged files must pass
#' content and replay verification before they replace the destination.
#'
#' @param snapshot A [gk_lock()] result.
#' @param dir Destination directory.
#' @param overwrite Replace an existing export directory.
#' @return The destination directory invisibly.
#' @family export
#' @export
gk_export <- function(snapshot, dir, overwrite = FALSE) {
  .gk_check_class(snapshot, "gk_snapshot")
  .gk_check_string(dir)
  .gk_check_flag(overwrite)
  tables <- .gk_export_tables(snapshot)
  current <- snapshot
  current$content <- .gk_export_content(snapshot, tables)
  current$source_sha256 <- snapshot$review$prepared$source_sha256
  current$source_manifest_sha256 <- snapshot$review$prepared$source_manifest_sha256
  current$config_sha256 <- gk_config_hash(snapshot$review$config)
  current$correction_model_sha256 <- .gk_export_correction_hash(snapshot$review)
  current$ledgers_sha256 <- .gk_export_ledgers_hash(snapshot$review)
  current$thresholds_sha256 <- .gk_sha256_object(.gk_export_thresholds(snapshot))
  full <- .gk_sha256_object(.gk_export_identity(current))
  if (!identical(snapshot$format_version, 2L) ||
    !identical(full, snapshot$review_id_full) ||
    !identical(snapshot$review_id, paste0("gk-", substr(full, 1L, 16L)))) {
    .gk_abort("Snapshot content changed after locking; review and lock again.", class = "verify")
  }
  stage <- .gk_stage_dir(dir, overwrite = overwrite)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  for (subdir in c("ledgers", "replay")) dir.create(file.path(stage, subdir))
  .gk_write_json(.gk_snapshot_payload(snapshot), file.path(stage, "snapshot.json"))
  .gk_write_json(list(review_id = snapshot$review_id,
    config = .gk_config_to_list(snapshot$review$config)), file.path(stage, "config.json"))
  correction <- snapshot$review$classification$correction
  .gk_write_json(list(review_id = snapshot$review_id,
    model = if (is.null(correction)) "none" else correction$model),
    file.path(stage, "correction_model.json"))
  for (path in names(tables)) {
    .gk_write_tsv(.gk_export_with_id(tables[[path]], snapshot$review_id), file.path(stage, path))
  }
  .gk_write_manifest(stage, .gk_list_files(stage), done = list(review_id = snapshot$review_id))
  gk_verify_export(stage, expected_review_id = snapshot$review_id_full)
  .gk_publish_dir(stage, dir, overwrite = overwrite)
  invisible(dir)
}

.gk_verify_add <- function(rows, check, ok, details = "") {
  row <- data.frame(check = check, ok = isTRUE(ok), details = details, stringsAsFactors = FALSE)
  if (is.data.frame(rows)) rbind(rows, row) else c(rows, list(row))
}

.gk_verify_fail <- function(checks, strict) {
  failed <- checks[!checks$ok, , drop = FALSE]
  if (nrow(failed) && isTRUE(strict)) {
    details <- paste0(failed$check, ": ", failed$details)
    names(details) <- rep("x", length(details))
    .gk_abort(c("Export verification failed.", details), class = "verify")
  }
  checks
}

.gk_verify_export_content <- function(dir, cellspec_dir, expected_review_id) {
  checks <- data.frame(check = character(), ok = logical(), details = character())
  add <- function(check, ok, details = "") {
    checks <<- .gk_verify_add(checks, check, ok, details)
  }
  snapshot <- .gk_read_json(file.path(dir, "snapshot.json"))
  version_ok <- identical(snapshot$schema, "gatekeepR-snapshot") &&
    identical(as.integer(snapshot$format_version), 2L)
  add("format_version", version_ok,
    if (!version_ok) "Legacy or unknown export format: inspect with verify = FALSE; regenerate, review and lock with version 2." else "")
  if (!version_ok) return(checks)
  id <- snapshot$review_id
  full <- .gk_sha256_object(.gk_export_identity(snapshot))
  add("review_identity", identical(full, snapshot$review_id_full) &&
    identical(id, paste0("gk-", substr(full, 1L, 16L))))
  if (!is.null(expected_review_id)) {
    add("expected_review_identity", identical(expected_review_id, snapshot$review_id_full),
      "Compare the full ID with an independently retained trusted value.")
  }
  add("review_status", is.character(snapshot$status) && length(snapshot$status) == 1L &&
    snapshot$status %in% c("PENDING", "REVIEWED") &&
    identical(snapshot$production_eligible, identical(snapshot$status, "REVIEWED")) &&
    is.character(snapshot$reviewer) && length(snapshot$reviewer) == 1L &&
    !is.na(snapshot$reviewer) && nzchar(trimws(snapshot$reviewer)))
  done <- .gk_read_done(dir)
  add("done_review_id", identical(unname(done$fields[["review_id"]]), id))
  manifest <- .gk_read_manifest(dir)
  required <- c("snapshot.json", "config.json", "correction_model.json", .gk_export_paths())
  add("export_files", setequal(manifest$file, required))
  if (any(!checks$ok)) return(checks)
  tables <- .gk_read_export_tables(dir, snapshot)
  for (path in names(tables)) {
    add(paste0("content_", path),
      identical(.gk_table_hash(tables[[path]]), snapshot$content$table_hashes[[path]]))
  }
  config_json <- .gk_read_json(file.path(dir, "config.json"))
  config <- .gk_config_from_list(config_json$config)
  add("config_hash", identical(config_json$review_id, id) &&
    identical(gk_config_hash(config), snapshot$config_sha256))
  correction <- .gk_read_json(file.path(dir, "correction_model.json"))
  add("correction_model_hash", identical(correction$review_id, id) &&
    identical(.gk_sha256_object(correction$model), snapshot$correction_model_sha256))
  add("threshold_hash", identical(.gk_sha256_object(tables[["thresholds.tsv"]]),
    snapshot$thresholds_sha256))
  if (any(!checks$ok)) return(checks)
  review <- .gk_export_restore_review(snapshot, config, tables, correction$model)
  add("ledgers_hash", identical(.gk_export_ledgers_hash(review), snapshot$ledgers_sha256))
  replayed <- gk_replay(review)
  rebuilt <- .gk_export_tables(list(review = review, replayed = replayed))
  for (path in c("cells.tsv.gz", "scores.tsv.gz", "state_calls.tsv.gz")) {
    add(paste0("replay_", path), identical(.gk_table_hash(rebuilt[[path]]), .gk_table_hash(tables[[path]])))
  }
  add("disabled_rules", identical(.gk_sha256_object(replayed$disabled_rules),
    .gk_sha256_object(snapshot$content$disabled_rules)))
  cells <- replayed$cells
  add("deleted_cells_not_analysed", !any(cells$disposition_effective == "DELETE" & cells$analysed))
  if (!is.null(cellspec_dir)) {
    source <- gk_prepare(cellspec_dir, config, quiet = TRUE)
    add("source_hash", identical(source$source_sha256, snapshot$source_sha256))
    add("source_prepared_cells", identical(.gk_table_hash(source$cells),
      .gk_table_hash(tables[["replay/prepared_cells.tsv.gz"]])))
    add("source_raw_scores", identical(.gk_table_hash(.gk_export_matrix(source, source$score)),
      .gk_table_hash(tables[["replay/raw_scores.tsv.gz"]])))
  }
  checks
}

#' Verify content identity, replay and reconciliation invariants
#'
#' Version 2 checks typed contents, source identity, correction model and every
#' ledger, then reconstructs the base review and compares effective cells,
#' scores and state calls. Legacy exports can be inspected explicitly with
#' `gk_read_export(verify = FALSE)`, but require a new review and lock to obtain
#' this verification contract. No export files are modified.
#'
#' Hashes are not signatures. Keep the full review ID independently and supply
#' `expected_review_id` when verification must detect a replaced whole export.
#'
#' @param dir Export directory written by [gk_export()].
#' @param cellspec_dir Optional source cellspec directory, checked against the
#'   source and prepared score contents.
#' @param strict Abort on failed verification?
#' @param expected_review_id Optional independently retained full SHA-256 review
#'   ID (the snapshot's `review_id_full`).
#' @return A check data frame with `check`, `ok` and `details`.
#' @family export
#' @export
gk_verify_export <- function(dir, cellspec_dir = NULL, strict = TRUE, expected_review_id = NULL) {
  .gk_check_dir_exists(dir)
  .gk_check_flag(strict)
  if (!is.null(expected_review_id)) .gk_check_string(expected_review_id)
  checks <- tryCatch(.gk_manifest_checks(dir, allow_extra = FALSE),
    error = function(e) .gk_verify_add(data.frame(), "manifest_readable", FALSE, conditionMessage(e)))
  if (all(checks$ok)) {
    content <- tryCatch(.gk_verify_export_content(dir, cellspec_dir, expected_review_id),
      error = function(e) .gk_verify_add(data.frame(), "content_and_replay", FALSE, conditionMessage(e)))
    checks <- rbind(checks, content)
  }
  .gk_verify_fail(checks, strict)
}

#' Read a verified export
#'
#' @param dir Export directory.
#' @param verify Verify before reading? `FALSE` permits inspection of legacy or
#'   untrusted exports and makes no integrity claim.
#' @param expected_review_id Optional full ID passed to [gk_verify_export()].
#' @return A `gk_export` list containing snapshot, configuration and tables.
#' @family export
#' @export
gk_read_export <- function(dir, verify = TRUE, expected_review_id = NULL) {
  .gk_check_dir_exists(dir)
  .gk_check_flag(verify)
  checks <- if (verify) gk_verify_export(dir, expected_review_id = expected_review_id) else NULL
  snapshot <- .gk_read_json(file.path(dir, "snapshot.json"))
  config_json <- .gk_read_json(file.path(dir, "config.json"))
  tables <- if (isTRUE(verify)) .gk_read_export_tables(dir, snapshot) else NULL
  read <- function(path) {
    if (is.null(tables)) .gk_read_tsv(file.path(dir, path)) else
      .gk_export_with_id(tables[[path]], snapshot$review_id)
  }
  out <- list(snapshot = snapshot,
    config = .gk_config_from_list(config_json$config %||% config_json),
    thresholds = read("thresholds.tsv"), cells = read("cells.tsv.gz"),
    scores = read("scores.tsv.gz"), state_calls = read("state_calls.tsv.gz"),
    structures = read("structures.tsv"),
    ledgers = stats::setNames(lapply(names(.gk_empty_ledgers()), function(name)
      read(paste0("ledgers/", name, ".tsv"))), names(.gk_empty_ledgers())), checks = checks)
  class(out) <- "gk_export"
  out
}

#' @export
print.gk_snapshot <- function(x, ...) {
  cli::cli_text("{.cls gk_snapshot} {.val {x$review_id}}: {.val {x$status}}")
  cli::cli_bullets(c("*" = "Production eligible: {.val {x$production_eligible}}",
    "*" = "Locked: {.val {x$locked_utc}}"))
  invisible(x)
}
