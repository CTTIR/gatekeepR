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
#'
#' @return The saved directory invisibly.
#' @family review
#' @export
gk_save_review <- function(review, dir, overwrite = FALSE) {
  .gk_review_check(review)
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
  stage <- .gk_stage_dir(dir, overwrite = overwrite)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  if (file.exists(file.path(dir, "review.rds"))) {
    file.copy(file.path(dir, "review.rds"), file.path(stage, "checkpoint.prev"), overwrite = TRUE)
  }
  dir.create(file.path(stage, "ledgers"), recursive = TRUE, showWarnings = FALSE)
  save_review <- review
  save_review$updated_utc <- .gk_utc_now()
  saveRDS(save_review, file.path(stage, "review.rds"), version = 3L)
  .gk_write_json(list(
    schema_version = "1.0.0", config_sha256 = review$config_sha256,
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
  .gk_publish_dir(stage, dir, overwrite = overwrite)
  invisible(dir)
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
gk_load_review <- function(dir, takeover = FALSE) {
  .gk_check_string(dir)
  .gk_check_flag(takeover)
  .gk_check_dir_exists(dir)
  dir <- .gk_review_path(dir)
  operation_lock <- .gk_review_operation_lock(dir)
  on.exit(filelock::unlock(operation_lock), add = TRUE)
  .gk_verify_manifest(dir, "verify")
  path <- file.path(dir, "review.rds")
  .gk_check_file_exists(path)
  review <- readRDS(path)
  .gk_review_check(review)
  for (name in names(review$ledgers)) {
    ledger_path <- file.path(dir, "ledgers", paste0(name, ".tsv"))
    .gk_check_file_exists(ledger_path)
    review$ledgers[[name]] <- .gk_read_tsv(ledger_path, types = .gk_ledger_types)
  }
  config <- .gk_read_json(file.path(dir, "config.json"))
  parsed_config <- .gk_config_from_list(config)
  if (!identical(gk_config_hash(parsed_config), review$config_sha256)) {
    .gk_abort("The saved configuration hash does not match the review.", class = "verify")
  }
  if (!identical(.gk_thresholds_hash(review$thresholds), review$classification$thresholds_sha256)) {
    .gk_abort("The saved threshold hash does not match the classification.", class = "verify")
  }
  .gk_acquire_review_lock(dir, takeover = takeover)
  review$locked <- FALSE
  review$working_dir <- dir
  review$updated_utc <- .gk_utc_now()
  review
}
