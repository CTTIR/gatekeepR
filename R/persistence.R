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
  vals <- strsplit(lines, " ", fixed = TRUE)
  keys <- vapply(vals, `[[`, character(1), 1L)
  value <- vapply(vals, function(x) paste(x[-1L], collapse = " "), character(1))
  names(value) <- keys
  identical(value[["host"]], unname(Sys.info()[["nodename"]])) &&
    identical(suppressWarnings(as.integer(value[["pid"]])), as.integer(Sys.getpid()))
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
#' @param review A [gk_review()] object.
#' @param dir Directory to create.
#' @param overwrite Replace an existing directory.
#' @return The saved directory invisibly.
#' @family review
#' @export
gk_save_review <- function(review, dir, overwrite = FALSE) {
  .gk_review_check(review)
  .gk_check_string(dir)
  .gk_check_flag(overwrite)
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
  files <- setdiff(.gk_list_files(stage), "review.lock")
  .gk_write_manifest(stage, files)
  .gk_publish_dir(stage, dir, overwrite = overwrite)
  on.exit(NULL, add = FALSE)
  invisible(dir)
}

#' Load a review checkpoint and acquire its single-writer lock
#'
#' @param dir Directory written by [gk_save_review()].
#' @param takeover Replace a lock left by a stale session.
#' @return A `gk_review` object.
#' @family review
#' @export
gk_load_review <- function(dir, takeover = FALSE) {
  .gk_check_dir_exists(dir)
  .gk_check_flag(takeover)
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
