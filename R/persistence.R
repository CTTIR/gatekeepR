# Atomic review checkpoints and a single-writer lock file.

.gk_review_lock <- function(dir) file.path(dir, "review.lock")

.gk_lock_lines <- function() {
  c(
    paste("pid", Sys.getpid()),
    paste("host", Sys.info()[["nodename"]]),
    paste("time_utc", .gk_utc_now())
  )
}

.gk_lock_owned <- function(path) {
  if (!file.exists(path)) return(FALSE)
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  if (length(lines) != 3L || any(!grepl("^[^ ]+ .+$", lines))) return(FALSE)
  keys <- sub(" .*", "", lines)
  if (anyDuplicated(keys) || !setequal(keys, c("pid", "host", "time_utc"))) {
    return(FALSE)
  }
  value <- stats::setNames(sub("^[^ ]+ ", "", lines), keys)
  stamp <- value[["time_utc"]]
  valid_stamp <- grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", stamp) &&
    !is.na(as.POSIXct(stamp, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  valid_stamp && identical(value[["host"]], unname(Sys.info()[["nodename"]])) &&
    identical(value[["pid"]], as.character(Sys.getpid()))
}

.gk_acquire_review_lock <- function(dir, takeover = FALSE) {
  path <- .gk_review_lock(dir)
  if (file.exists(path) && !.gk_lock_owned(path) && !isTRUE(takeover)) {
    .gk_abort(
      c(
        "Review directory {.path {dir}} is locked by another session.",
        "i" = "Use {.arg takeover = TRUE} only after confirming the other session is stale."
      ),
      class = "lockfile"
    )
  }
  .gk_write_atomic(path, function(tmp) writeLines(.gk_lock_lines(), tmp, useBytes = TRUE))
  invisible(path)
}

.gk_review_path <- function(dir) {
  dir <- sub("[/\\\\]+$", "", dir)
  if (!nzchar(dir)) .gk_abort("A review cannot replace the filesystem root.", class = "input")
  parent <- dirname(dir)
  if (!dir.exists(parent) &&
      !dir.create(parent, recursive = TRUE, showWarnings = FALSE)) {
    .gk_abort("Could not create review parent {.path {parent}}.", class = "input")
  }
  path <- if (dir.exists(dir)) normalizePath(dir, winslash = "/", mustWork = TRUE) else
    file.path(normalizePath(parent, winslash = "/", mustWork = TRUE), basename(dir))
  if (identical(dirname(path), path)) {
    .gk_abort("A review cannot replace the filesystem root.", class = "input")
  }
  path
}

.gk_review_operation_lock <- function(dir) {
  dir <- .gk_review_path(dir)
  parent <- dirname(dir)
  path <- file.path(parent, paste0(".", basename(dir), ".gatekeepR.lock"))
  lock <- filelock::lock(path, timeout = 0)
  if (is.null(lock)) {
    .gk_abort("Another session is reading or saving review {.path {dir}}.",
      class = "lockfile")
  }
  lock
}

.gk_ledger_types <- c(
  sequence = "integer", order = "integer", entry_id = "character",
  time_utc = "character", reviewer = "character", image_id = "character",
  reason = "character", reverts = "character", marker = "character",
  parent = "character", old_estimate = "double", new_estimate = "double",
  old_status = "character", mode = "character", structure_id = "character",
  xmin = "double", xmax = "double", ymin = "double", ymax = "double",
  decision = "character", n_affected_at_creation = "integer",
  cut_at_creation = "integer", cell_id = "character", disposition = "character",
  action = "character"
)

.gk_read_review_checkpoint <- function(dir) {
  # The caller holds the sibling operation lock through this entire read.
  .gk_verify_manifest(dir, "verify")
  path <- file.path(dir, "review.rds")
  .gk_check_file_exists(path)
  review <- readRDS(path)
  .gk_review_check(review)
  for (name in names(review$ledgers)) {
    ledger_path <- file.path(dir, "ledgers", paste0(name, ".tsv"))
    .gk_check_file_exists(ledger_path)
    ledger <- .gk_read_tsv(ledger_path, types = .gk_ledger_types)
    if (!identical(.gk_sha256_object(ledger), .gk_sha256_object(review$ledgers[[name]])))
      .gk_abort("The saved ledger {.val {name}} differs from the checkpoint.", class = "verify")
  }
  parsed_config <- .gk_config_from_list(.gk_read_json(file.path(dir, "config.json")))
  metadata <- .gk_read_json(file.path(dir, "metadata.json"))
  if (!identical(metadata$schema_version, "2.0.0"))
    .gk_abort(paste("Legacy checkpoint provenance cannot be verified by this version.",
      "Preserve this directory; regenerate the analytical base from the original data",
      "and re-review the recorded actions before saving a new checkpoint."), class = "verify")
  if (!identical(gk_config_hash(parsed_config), review$config_sha256) ||
    !identical(gk_config_hash(review$config), review$config_sha256) ||
    !identical(gk_config_hash(review$prepared$config), review$config_sha256) ||
    !identical(review$prepared$config_sha256, review$config_sha256) ||
    !identical(review$prepared$source_sha256, review$source_sha256))
    .gk_abort("The saved source or configuration does not match the review.", class = "verify")
  expected <- list(schema_version = "2.0.0", config_sha256 = review$config_sha256,
    source_sha256 = review$source_sha256,
    thresholds_sha256 = .gk_thresholds_hash(review$thresholds),
    updated_utc = review$updated_utc)
  if (!identical(.gk_sha256_object(metadata), .gk_sha256_object(expected)))
    .gk_abort("The saved metadata does not match the checkpoint.", class = "verify")
  # Recheck all cross-component bindings without replacing the saved history.
  gk_review(review$classification, review$state_calls, review$structures,
    review$thresholds, review$prepared)
  review
}

#' Save a review checkpoint atomically
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' @param review A [gk_review()] object.
#' @param dir Directory to create.
#' @param overwrite Replace an existing directory.
#' @details
#' Saving over a checkpoint requires ownership of any existing session lock.
#' Both save and load use an operating-system lock on a separate hidden sibling
#' file named `.DIRECTORY.gatekeepR.lock`. This empty file remains after use;
#' do not remove it while sessions may be accessing the review. The filesystem
#' must support advisory file locks, and its parent directory must be writable.
#' Session ownership is preserved when replacing the checkpoint.
#' Reviews returned by [gk_load_review()] carry a checkpoint revision. Saving
#' that review back to its working directory rejects intervening writes, even
#' from another browser session in the same R process. After saving, reload the
#' checkpoint before further editing, or copy the returned path's
#' `checkpoint_revision` attribute to `review$checkpoint_revision`.
#' Explicit overwrites with reviews that were never loaded remain supported.
#'
#' @return The saved directory invisibly, with a `checkpoint_revision` attribute.
#' @family review
#' @export
#' @examplesIf requireNamespace("dbscan", quietly = TRUE)
#' cfg <- gk_example_config()
#' prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), cfg, quiet = TRUE)
#' thresholds <- gk_thresholds(prep, cfg, seed = 7L)
#' classification <- gk_classify(prep, thresholds, cfg)
#' states <- gk_state_calls(prep, thresholds, classification, cfg)
#' structures <- gk_structures(classification, prep)
#' review <- gk_review(classification, states, structures, thresholds, prep)
#' root <- tempfile("gatekeepR-example-")
#' dir.create(root)
#' path <- gk_save_review(review, file.path(root, "review"))
#' list.files(path)
#' unlink(root, recursive = TRUE)
gk_save_review <- function(review, dir, overwrite = FALSE) {
  .gk_review_check(review)
  .gk_review_validate_base(review)
  .gk_check_string(dir)
  .gk_check_flag(overwrite)
  dir <- .gk_review_path(dir)
  operation_lock <- .gk_review_operation_lock(dir)
  on.exit(filelock::unlock(operation_lock), add = TRUE)
  ownership <- .gk_review_lock(dir)
  if (file.exists(ownership) && !.gk_lock_owned(ownership)) {
    .gk_abort("Review directory {.path {dir}} is owned by another session.",
      class = "lockfile")
  }
  checkpoint <- file.path(dir, "review.rds")
  if (!is.null(review$checkpoint_revision) && !is.null(review$working_dir) &&
    identical(.gk_review_path(review$working_dir), dir)) {
    if (!file.exists(checkpoint) ||
      !identical(review$checkpoint_revision, .gk_sha256_file(checkpoint)))
      .gk_abort("The checkpoint changed after this review was loaded. Reload it before saving.",
        class = "lockfile")
  }
  stage <- .gk_stage_dir(dir, overwrite = overwrite)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  if (file.exists(file.path(dir, "review.rds"))) {
    file.copy(file.path(dir, "review.rds"), file.path(stage, "checkpoint.prev"), overwrite = TRUE)
  }
  dir.create(file.path(stage, "ledgers"), recursive = TRUE, showWarnings = FALSE)
  save_review <- review
  save_review$updated_utc <- .gk_utc_now()
  save_review$checkpoint_revision <- NULL
  save_review$working_dir <- NULL
  saveRDS(save_review, file.path(stage, "review.rds"), version = 3L)
  .gk_write_json(list(
    schema_version = "2.0.0", config_sha256 = review$config_sha256,
    source_sha256 = review$source_sha256,
    thresholds_sha256 = .gk_thresholds_hash(review$thresholds),
    updated_utc = save_review$updated_utc
  ), file.path(stage, "metadata.json"))
  .gk_write_json(.gk_config_to_list(review$config), file.path(stage, "config.json"))
  for (name in names(review$ledgers)) {
    .gk_write_tsv(review$ledgers[[name]], file.path(stage, "ledgers", paste0(name, ".tsv")))
  }
  if (file.exists(ownership)) {
    writeLines(readLines(ownership, warn = FALSE, encoding = "UTF-8"),
      file.path(stage, "review.lock"), useBytes = TRUE)
  }
  files <- setdiff(.gk_list_files(stage), "review.lock")
  .gk_write_manifest(stage, files)
  revision <- .gk_sha256_file(file.path(stage, "review.rds"))
  .gk_publish_dir(stage, dir, overwrite = overwrite)
  invisible(structure(dir, checkpoint_revision = revision))
}

#' Load a review checkpoint and acquire its single-writer lock
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' @details
#' Loading is serialized with saving by the sibling operation lock described in
#' [gk_save_review()]. Explicit takeover applies to session ownership; it cannot
#' interrupt a save or load currently holding the operating-system lock.
#'
#' @param dir Directory written by [gk_save_review()].
#' @param takeover Replace a lock left by a stale session.
#' @return A `gk_review` object.
#' @family review
#' @export
#' @examplesIf requireNamespace("dbscan", quietly = TRUE)
#' cfg <- gk_example_config()
#' prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), cfg, quiet = TRUE)
#' thresholds <- gk_thresholds(prep, cfg, seed = 7L)
#' classification <- gk_classify(prep, thresholds, cfg)
#' states <- gk_state_calls(prep, thresholds, classification, cfg)
#' structures <- gk_structures(classification, prep)
#' review <- gk_review(classification, states, structures, thresholds, prep)
#' root <- tempfile("gatekeepR-example-")
#' dir.create(root)
#' gk_save_review(review, file.path(root, "review"))
#' loaded <- gk_load_review(file.path(root, "review"))
#' loaded
#' unlink(root, recursive = TRUE)
gk_load_review <- function(dir, takeover = FALSE) {
  .gk_check_string(dir)
  .gk_check_flag(takeover)
  .gk_check_dir_exists(dir)
  dir <- .gk_review_path(dir)
  operation_lock <- .gk_review_operation_lock(dir)
  on.exit(filelock::unlock(operation_lock), add = TRUE)
  review <- .gk_read_review_checkpoint(dir)
  review$checkpoint_revision <- .gk_sha256_file(file.path(dir, "review.rds"))
  .gk_acquire_review_lock(dir, takeover = takeover)
  review$locked <- FALSE
  review$working_dir <- dir
  review$updated_utc <- .gk_utc_now()
  review
}
