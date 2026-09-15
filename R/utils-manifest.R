# Staged directories, SHA-256 manifests and DONE markers.
#
# Layout written by every directory writer in gatekeepR:
#   <dir>/...files...
#   <dir>/MANIFEST.sha256   "<sha256>  <relative path>", sorted by path
#   <dir>/DONE              line 1: SHA-256 of MANIFEST.sha256; further
#                           "key value" lines (e.g. review_id)
# Writes go to "<dir>.partial-<pid>" and are renamed into place at the end.

.gk_stage_dir <- function(dir, overwrite = FALSE, call = rlang::caller_env()) {
  dir <- sub("[/\\\\]+$", "", dir)
  if (file.exists(dir) && !overwrite) {
    .gk_abort(
      c(
        "{.path {dir}} already exists.",
        "i" = "Use {.code overwrite = TRUE} to replace it."
      ),
      class = "input", call = call
    )
  }
  parent <- dirname(dir)
  if (!dir.exists(parent)) {
    dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  }
  stage <- paste0(dir, ".partial-", Sys.getpid())
  if (file.exists(stage)) {
    unlink(stage, recursive = TRUE)
  }
  if (!dir.create(stage, recursive = TRUE, showWarnings = FALSE)) {
    .gk_abort("Could not create staging directory {.path {stage}}.",
      class = "input", call = call
    )
  }
  stage
}

.gk_publish_dir <- function(stage, dir, overwrite = FALSE, call = rlang::caller_env()) {
  dir <- sub("[/\\\\]+$", "", dir)
  old <- NULL
  if (file.exists(dir)) {
    if (!overwrite) {
      .gk_abort("{.path {dir}} already exists.", class = "input", call = call)
    }
    old <- paste0(dir, ".old-", Sys.getpid())
    unlink(old, recursive = TRUE)
    if (!file.rename(dir, old)) {
      .gk_abort("Could not move the existing {.path {dir}} aside.", class = "input", call = call)
    }
  }
  if (!file.rename(stage, dir)) {
    if (!is.null(old)) {
      file.rename(old, dir)
    }
    .gk_abort("Could not publish {.path {dir}}.", class = "input", call = call)
  }
  if (!is.null(old)) {
    unlink(old, recursive = TRUE)
  }
  invisible(dir)
}

# List files below `dir` as relative paths with "/" separators.
.gk_list_files <- function(dir) {
  files <- list.files(dir, recursive = TRUE, all.files = TRUE, no.. = TRUE)
  files <- gsub("\\\\", "/", files)
  sort(files, method = "radix")
}

.gk_write_manifest <- function(stage, files, done = list()) {
  files <- sort(unique(files), method = "radix")
  hashes <- vapply(file.path(stage, files), .gk_sha256_file, character(1))
  lines <- paste0(hashes, "  ", files)
  manifest <- file.path(stage, "MANIFEST.sha256")
  writeLines(enc2utf8(lines), manifest, useBytes = TRUE)
  done_lines <- .gk_sha256_file(manifest)
  if (length(done) > 0L) {
    done_lines <- c(done_lines, paste(names(done), unlist(done)))
  }
  writeLines(enc2utf8(done_lines), file.path(stage, "DONE"), useBytes = TRUE)
  invisible(manifest)
}

.gk_read_manifest <- function(dir) {
  path <- file.path(dir, "MANIFEST.sha256")
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- lines[nzchar(lines)]
  m <- regmatches(lines, regexec("^([0-9a-f]{64})  (.+)$", lines))
  ok <- lengths(m) == 3L
  data.frame(
    file = vapply(m, function(v) if (length(v) == 3L) v[[3L]] else NA_character_, character(1)),
    expected = vapply(m, function(v) if (length(v) == 3L) v[[2L]] else NA_character_, character(1)),
    well_formed = ok,
    stringsAsFactors = FALSE
  )
}

.gk_read_done <- function(dir) {
  lines <- readLines(file.path(dir, "DONE"), warn = FALSE, encoding = "UTF-8")
  lines <- lines[nzchar(lines)]
  kv <- strsplit(lines[-1L], " ", fixed = TRUE)
  vals <- vapply(kv, function(v) paste(v[-1L], collapse = " "), character(1))
  names(vals) <- vapply(kv, `[[`, character(1), 1L)
  list(manifest_sha256 = if (length(lines)) lines[[1L]] else NA_character_, fields = vals)
}

# Check a manifest-bound directory. Returns a check table (check, ok, details).
# With `class` set, aborts with that error class on the first failure.
.gk_manifest_checks <- function(dir, allow_extra = TRUE) {
  rows <- list()
  add <- function(check, ok, details = "") {
    rows[[length(rows) + 1L]] <<- data.frame(
      check = check, ok = ok, details = details, stringsAsFactors = FALSE
    )
  }
  has_manifest <- file.exists(file.path(dir, "MANIFEST.sha256"))
  has_done <- file.exists(file.path(dir, "DONE"))
  add("done_present", has_done, if (has_done) "" else "DONE marker missing (incomplete write?)")
  add("manifest_present", has_manifest, if (has_manifest) "" else "MANIFEST.sha256 missing")
  if (!has_manifest || !has_done) {
    return(do.call(rbind, rows))
  }
  done <- .gk_read_done(dir)
  observed <- .gk_sha256_file(file.path(dir, "MANIFEST.sha256"))
  ok_done <- identical(done$manifest_sha256, observed)
  add("done_matches_manifest", ok_done,
    if (ok_done) "" else "DONE does not hold the SHA-256 of MANIFEST.sha256"
  )
  man <- .gk_read_manifest(dir)
  add("manifest_well_formed", all(man$well_formed),
    if (all(man$well_formed)) "" else "MANIFEST.sha256 has malformed lines"
  )
  man <- man[man$well_formed, , drop = FALSE]
  unsafe <- grepl("(^|/)\\.\\.(/|$)", man$file) | grepl("^(/|[A-Za-z]:)", man$file)
  add("manifest_paths_safe", !any(unsafe),
    if (any(unsafe)) paste("unsafe paths:", paste(man$file[unsafe], collapse = ", ")) else ""
  )
  man <- man[!unsafe, , drop = FALSE]
  present <- file.exists(file.path(dir, man$file))
  add("listed_files_present", all(present),
    if (all(present)) "" else paste("missing:", paste(man$file[!present], collapse = ", "))
  )
  obs <- rep(NA_character_, nrow(man))
  obs[present] <- vapply(file.path(dir, man$file[present]), .gk_sha256_file, character(1))
  match <- present & obs == man$expected
  bad <- man$file[present & !match]
  add("file_hashes_match", length(bad) == 0L,
    if (length(bad) == 0L) "" else paste("changed:", paste(bad, collapse = ", "))
  )
  if (!allow_extra) {
    actual <- .gk_list_files(dir)
    extra <- setdiff(actual, c(man$file, "MANIFEST.sha256", "DONE"))
    add("no_unlisted_files", length(extra) == 0L,
      if (length(extra) == 0L) "" else paste("unlisted:", paste(extra, collapse = ", "))
    )
  }
  do.call(rbind, rows)
}

.gk_verify_manifest <- function(dir, class, allow_extra = TRUE, call = rlang::caller_env()) {
  checks <- .gk_manifest_checks(dir, allow_extra = allow_extra)
  failed <- checks[!checks$ok, , drop = FALSE]
  if (nrow(failed) > 0L) {
    details <- paste0(failed$check, ": ", failed$details)
    names(details) <- rep("x", length(details))
    .gk_abort(
      c("Integrity check failed for {.path {dir}}.", details),
      class = class, call = call
    )
  }
  invisible(checks)
}
