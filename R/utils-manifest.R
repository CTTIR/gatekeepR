# Staged directories, SHA-256 manifests and DONE markers.
# Staging and rollback directories are newly reserved siblings of the target.
# Files left by another operation are never treated as disposable temporary data.

.gk_stage_dir <- function(dir, overwrite = FALSE, call = rlang::caller_env()) {
  dir <- .gk_review_path(dir)
  if (file.exists(dir) && !dir.exists(dir))
    .gk_abort("The destination {.path {dir}} is not a directory.", class = "input", call = call)
  if (dir.exists(dir) && !overwrite) {
    .gk_abort(c("{.path {dir}} already exists.",
      "i" = "Use {.code overwrite = TRUE} to replace it."), class = "input", call = call)
  }
  stage <- tempfile(pattern = paste0(basename(dir), ".partial-"), tmpdir = dirname(dir))
  if (!dir.create(stage, showWarnings = FALSE))
    .gk_abort("Could not create staging directory {.path {stage}}.", class = "input", call = call)
  stage
}

.gk_rename_dir <- function(from, to) file.rename(from, to)

.gk_publish_dir <- function(stage, dir, overwrite = FALSE, call = rlang::caller_env()) {
  dir <- .gk_review_path(dir)
  .gk_check_dir_exists(stage)
  if (identical(normalizePath(stage, winslash = "/", mustWork = TRUE), dir))
    .gk_abort("Staging and destination directories must differ.", class = "input", call = call)
  old <- backup <- NULL
  restore_pending <- FALSE
  on.exit({
    if (restore_pending && !is.null(old) && dir.exists(old)) {
      restored <- if (!file.exists(dir))
        tryCatch(.gk_rename_dir(old, dir), error = function(e) FALSE) else FALSE
      if (isTRUE(restored)) unlink(backup, recursive = TRUE) else
        .gk_warn("The previous directory is preserved at {.path {old}}.", class = "recovery")
    }
  }, add = TRUE)
  if (file.exists(dir)) {
    if (!overwrite || !dir.exists(dir))
      .gk_abort("{.path {dir}} already exists.", class = "input", call = call)
    # Reserve a new container atomically; the path to move into is absent even
    # on platforms that cannot rename a directory onto an empty directory.
    backup <- tempfile(pattern = paste0(basename(dir), ".old-"), tmpdir = dirname(dir))
    if (!dir.create(backup, showWarnings = FALSE))
      .gk_abort("Could not reserve a rollback directory.", class = "input", call = call)
    old <- file.path(backup, "checkpoint")
    restore_pending <- TRUE
    if (!.gk_rename_dir(dir, old)) {
      unlink(backup, recursive = TRUE)
      .gk_abort("Could not move the existing {.path {dir}} aside.", class = "input", call = call)
    }
  }
  if (!.gk_rename_dir(stage, dir)) {
    restore_pending <- FALSE
    restored <- is.null(old) || .gk_rename_dir(old, dir)
    if (!is.null(backup) && restored) unlink(backup, recursive = TRUE)
    if (!restored)
      .gk_abort(c("Could not publish or restore {.path {dir}}.",
        "i" = "The previous directory is preserved at {.path {old}}."), class = "input", call = call)
    .gk_abort("Could not publish {.path {dir}}; the previous directory was preserved.",
      class = "input", call = call)
  }
  restore_pending <- FALSE
  if (!is.null(backup)) unlink(backup, recursive = TRUE)
  invisible(dir)
}

# Do not traverse directory symlinks while discovering files. A symlink itself
# is returned as an entry so strict verification detects it as unlisted/unsafe.
.gk_list_files <- function(dir) {
  walk <- function(relative = "") {
    children <- list.files(file.path(dir, relative), all.files = TRUE, no.. = TRUE)
    out <- character()
    for (child in children) {
      entry <- if (nzchar(relative)) paste(relative, child, sep = "/") else child
      path <- file.path(dir, entry)
      link <- Sys.readlink(path)
      is_link <- !is.na(link) && nzchar(link)
      if (dir.exists(path) && !is_link) out <- c(out, walk(entry)) else out <- c(out, entry)
    }
    out
  }
  sort(walk(), method = "radix")
}

.gk_manifest_safe_path <- function(files) {
  !is.na(files) & nzchar(files) &
    !grepl("(^/|^[A-Za-z]:|[\\\\[:cntrl:]])", files) &
    !grepl("(^|/)(\\.|\\.\\.|)(/|$)", files)
}

.gk_manifest_regular_file <- function(dir, relative) {
  root <- normalizePath(dir, winslash = "/", mustWork = TRUE)
  vapply(relative, function(entry) {
    if (!.gk_manifest_safe_path(entry)) return(FALSE)
    parts <- strsplit(entry, "/", fixed = TRUE)[[1L]]
    for (i in seq_along(parts)) {
      link <- Sys.readlink(file.path(dir, paste(parts[seq_len(i)], collapse = "/")))
      if (!is.na(link) && nzchar(link)) return(FALSE)
    }
    path <- file.path(dir, entry)
    if (!isTRUE(utils::file_test("-f", path))) return(FALSE)
    resolved <- normalizePath(path, winslash = "/", mustWork = TRUE)
    startsWith(resolved, paste0(sub("/+$", "", root), "/"))
  }, logical(1), USE.NAMES = FALSE)
}

.gk_write_manifest <- function(stage, files, done = list()) {
  if (!is.character(files) || anyDuplicated(files) ||
    any(!.gk_manifest_safe_path(files)) ||
    any(!.gk_manifest_regular_file(stage, files)))
    .gk_abort("Manifest entries must be unique regular files inside the directory without symbolic links.", class = "input")
  files <- sort(files, method = "radix")
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
  valid <- length(lines) >= 1L && grepl("^[0-9a-f]{64}$", lines[[1L]]) &&
    all(grepl("^[^[:space:]]+ .+$", lines[-1L])) && !anyDuplicated(names(vals))
  list(manifest_sha256 = if (length(lines)) lines[[1L]] else NA_character_,
    fields = vals, well_formed = isTRUE(valid))
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
  controls_regular <- all(.gk_manifest_regular_file(dir, c("MANIFEST.sha256", "DONE")))
  add("control_files_regular", controls_regular,
    if (controls_regular) "" else "MANIFEST.sha256 and DONE must be regular files without symbolic links")
  if (!controls_regular) return(do.call(rbind, rows))
  done <- .gk_read_done(dir)
  add("done_well_formed", done$well_formed,
    if (done$well_formed) "" else "DONE has malformed or duplicate fields")
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
  duplicate <- anyDuplicated(man$file) > 0L
  add("manifest_paths_unique", !duplicate,
    if (duplicate) "MANIFEST.sha256 lists duplicate paths" else "")
  unsafe <- !.gk_manifest_safe_path(man$file)
  add("manifest_paths_safe", !any(unsafe),
    if (any(unsafe)) paste("unsafe paths:", paste(man$file[unsafe], collapse = ", ")) else ""
  )
  man <- man[!unsafe, , drop = FALSE]
  present <- file.exists(file.path(dir, man$file))
  add("listed_files_present", all(present),
    if (all(present)) "" else paste("missing:", paste(man$file[!present], collapse = ", "))
  )
  regular <- .gk_manifest_regular_file(dir, man$file)
  bad_type <- present & !regular
  add("listed_files_regular", !any(bad_type),
    if (any(bad_type)) paste("nonregular or symbolic-link paths:", paste(man$file[bad_type], collapse = ", ")) else "")
  obs <- rep(NA_character_, nrow(man))
  obs[regular] <- vapply(file.path(dir, man$file[regular]), .gk_sha256_file, character(1))
  match <- regular & obs == man$expected
  bad <- man$file[regular & !match]
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
