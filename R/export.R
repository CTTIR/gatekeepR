# Immutable snapshots, content-addressed exports and replay verification.

.gk_export_thresholds <- function(snapshot) {
  rbind(
    as.data.frame(snapshot$review$thresholds, stringsAsFactors = FALSE),
    as.data.frame(snapshot$review$state_calls$state_thresholds, stringsAsFactors = FALSE)
  )
}

.gk_export_correction_hash <- function(review) {
  correction <- review$classification$correction
  if (is.null(correction)) return(.gk_sha256_object("none"))
  .gk_sha256_object(correction$model)
}

.gk_export_ledgers_hash <- function(review) .gk_sha256_object(review$ledgers)

.gk_snapshot_payload <- function(snapshot) {
  list(
    schema = "gatekeepR-snapshot", review_id = snapshot$review_id,
    review_id_full = snapshot$review_id_full, status = snapshot$status,
    production_eligible = snapshot$production_eligible,
    reviewer = snapshot$reviewer, locked_utc = snapshot$locked_utc,
    source_sha256 = snapshot$source_sha256,
    source_manifest_sha256 = snapshot$source_manifest_sha256,
    config_sha256 = snapshot$config_sha256,
    thresholds_sha256 = snapshot$thresholds_sha256,
    correction_model_sha256 = snapshot$correction_model_sha256,
    ledgers_sha256 = snapshot$ledgers_sha256, session = snapshot$session,
    disabled_rules = snapshot$review$classification$disabled_rules
  )
}

#' Lock a review into an immutable snapshot
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
  replayed <- gk_replay(review)
  correction_hash <- .gk_export_correction_hash(review)
  threshold_hash <- .gk_sha256_object(.gk_export_thresholds(list(review = review)))
  ledgers_hash <- .gk_export_ledgers_hash(review)
  id_object <- list(
    source_cellspec_manifest_sha256 = review$prepared$source_manifest_sha256,
    config_sha256 = review$config_sha256, thresholds_sha256 = threshold_hash,
    correction_model_sha256 = correction_hash, ledgers_sha256 = ledgers_hash,
    gatekeepR_version = .gk_package_version(), cellspecR_version = "1.0.0"
  )
  full <- .gk_sha256_object(id_object)
  soft <- extSoftVersion()
  blas <- if ("BLAS" %in% names(soft)) unname(soft[["BLAS"]]) else NA_character_
  lapack <- if ("LAPACK" %in% names(soft)) unname(soft[["LAPACK"]]) else NA_character_
  snapshot <- list(
    review_id = paste0("gk-", substr(full, 1L, 16L)), review_id_full = full,
    status = status, production_eligible = identical(status, "REVIEWED"),
    reviewer = reviewer, locked_utc = .gk_utc_now(),
    source_sha256 = review$source_sha256,
    source_manifest_sha256 = review$prepared$source_manifest_sha256,
    config_sha256 = review$config_sha256, thresholds_sha256 = threshold_hash,
    correction_model_sha256 = correction_hash, ledgers_sha256 = ledgers_hash,
    session = list(r_version = R.version$version.string, platform = R.version$platform,
      blas = blas, lapack = lapack,
      packages = list(gatekeepR = .gk_package_version(),
        jsonlite = .gk_package_version("jsonlite")), seed = NA_character_,
      time_utc = .gk_utc_now()),
    review = review, replayed = replayed
  )
  class(snapshot) <- "gk_snapshot"
  snapshot
}

.gk_export_with_id <- function(df, review_id) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  cbind(review_id = rep(review_id, nrow(df)), df, row.names = NULL)
}

.gk_export_scores <- function(snapshot) {
  review <- snapshot$review
  prepared <- review$prepared
  score <- if (!is.null(review$classification$correction)) review$classification$correction$matrix else prepared$score
  out <- data.frame(review_id = snapshot$review_id, image_id = prepared$cells$image_id,
    cell_id = prepared$cells$cell_id, stringsAsFactors = FALSE)
  for (marker in colnames(score)) out[[paste0("score__", marker)]] <- score[, marker]
  for (marker in names(prepared$localization)) {
    out[[paste0("localization_ratio__", marker)]] <- prepared$localization[[marker]]$ratio
  }
  out
}

.gk_export_cells <- function(snapshot) {
  review <- snapshot$review
  replayed <- snapshot$replayed$cells
  coords <- review$prepared$cells[match(replayed$cell_id, review$prepared$cells$cell_id), c("x", "y"), drop = FALSE]
  replayed$x <- coords$x
  replayed$y <- coords$y
  replayed <- replayed[, c("image_id", "cell_id", "x", "y", "base_cell_type", "cell_type",
    "rule_id", "pending_review", setdiff(names(replayed), c("image_id", "cell_id", "x", "y",
      "base_cell_type", "cell_type", "rule_id", "pending_review", "excluded", "structure_id",
      "structure_decision", "disposition_effective", "analysed")), "excluded", "structure_id",
    "structure_decision", "disposition_effective", "analysed"), drop = FALSE]
  .gk_export_with_id(replayed, snapshot$review_id)
}

#' Write a locked review export
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
  stage <- .gk_stage_dir(dir, overwrite = overwrite)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  dir.create(file.path(stage, "ledgers"), recursive = TRUE, showWarnings = FALSE)
  review <- snapshot$review
  .gk_write_json(.gk_snapshot_payload(snapshot), file.path(stage, "snapshot.json"))
  .gk_write_json(list(review_id = snapshot$review_id, config = .gk_config_to_list(review$config)),
    file.path(stage, "config.json"))
  .gk_write_tsv(.gk_export_with_id(.gk_export_thresholds(snapshot), snapshot$review_id),
    file.path(stage, "thresholds.tsv"))
  correction <- review$classification$correction
  .gk_write_json(list(review_id = snapshot$review_id,
    model = if (is.null(correction)) "none" else correction$model),
    file.path(stage, "correction_model.json"))
  .gk_write_tsv(.gk_export_cells(snapshot), file.path(stage, "cells.tsv.gz"))
  .gk_write_tsv(.gk_export_scores(snapshot), file.path(stage, "scores.tsv.gz"))
  .gk_write_tsv(.gk_export_with_id(snapshot$replayed$state_calls, snapshot$review_id),
    file.path(stage, "state_calls.tsv.gz"))
  .gk_write_tsv(.gk_export_with_id(review$structures$structures, snapshot$review_id),
    file.path(stage, "structures.tsv"))
  for (name in names(review$ledgers)) {
    .gk_write_tsv(.gk_export_with_id(review$ledgers[[name]], snapshot$review_id),
      file.path(stage, "ledgers", paste0(name, ".tsv")))
  }
  files <- .gk_list_files(stage)
  .gk_write_manifest(stage, files, done = list(review_id = snapshot$review_id))
  .gk_publish_dir(stage, dir, overwrite = overwrite)
  on.exit(NULL, add = FALSE)
  invisible(dir)
}

.gk_verify_add <- function(rows, check, ok, details = "") {
  row <- data.frame(check = check, ok = isTRUE(ok), details = details,
    stringsAsFactors = FALSE)
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

#' Verify manifest integrity, replay and reconciliation invariants
#'
#' @param dir Export directory written by [gk_export()].
#' @param cellspec_dir Optional source cellspec directory.
#' @param strict Abort on the first failed verification group?
#' @return A check data frame with `check`, `ok` and `details`.
#' @family export
#' @export
gk_verify_export <- function(dir, cellspec_dir = NULL, strict = TRUE) {
  .gk_check_dir_exists(dir)
  .gk_check_flag(strict)
  checks <- .gk_manifest_checks(dir)
  checks <- .gk_verify_fail(checks, strict)
  if (any(!checks$ok)) return(checks)
  snapshot <- .gk_read_json(file.path(dir, "snapshot.json"))
  review_id <- snapshot$review_id
  checks <- .gk_verify_add(checks, "snapshot_review_id", is.character(review_id) && length(review_id) == 1L)
  done <- .gk_read_done(dir)
  checks <- .gk_verify_add(checks, "done_review_id", identical(unname(done$fields[["review_id"]]), review_id))
  tsv_paths <- c("thresholds.tsv", "cells.tsv.gz", "scores.tsv.gz", "state_calls.tsv.gz",
    "structures.tsv", file.path("ledgers", paste0(names(.gk_empty_ledgers()), ".tsv")))
  threshold_types <- c(image_id = "character", marker = "character", parent = "character",
    role = "character", method = "character", status = "character", estimate = "double",
    crossing = "double", negative_q99 = "double", auc = "double",
    n_positive_pool = "integer", n_negative_pool = "integer",
    positive_populations = "character", negative_populations = "character",
    rule = "character", args_json = "character", details = "character",
    evidence_ref = "character")
  cells_types <- c(image_id = "character", cell_id = "character", x = "double", y = "double",
    base_cell_type = "character", cell_type = "character", rule_id = "character",
    pending_review = "logical", excluded = "logical", structure_id = "character",
    structure_decision = "character", disposition_effective = "character", analysed = "logical")
  raw_scores <- .gk_read_tsv(file.path(dir, "scores.tsv.gz"))
  score_fields <- grep("^(score|localization_ratio)__", names(raw_scores), value = TRUE)
  score_types <- c(image_id = "character", cell_id = "character",
    stats::setNames(rep("double", length(score_fields)), score_fields))
  structure_types <- c(image_id = "character", structure_id = "character", n_cells = "integer",
    centroid_x = "double", centroid_y = "double", xmin = "double", xmax = "double",
    ymin = "double", ymax = "double", decision = "character")
  state_types <- c(image_id = "character", cell_id = "character", marker = "character",
    parent = "character", in_parent = "logical", evaluable = "logical", score = "double",
    estimate = "double", localization_ratio = "double", positive = "logical", enabled = "logical")
  types <- list(threshold_types, cells_types, score_types, state_types, structure_types,
    .gk_ledger_types, .gk_ledger_types, .gk_ledger_types, .gk_ledger_types)
  tsvs <- lapply(seq_along(tsv_paths), function(i) {
    .gk_read_tsv(file.path(dir, tsv_paths[[i]]), types = types[[i]])
  })
  names(tsvs) <- tsv_paths
  for (i in seq_along(tsvs)) {
    x <- tsvs[[i]]
    ok <- ncol(x) > 0L && identical(names(x)[[1L]], "review_id") &&
      (nrow(x) == 0L || all(x[[1L]] == review_id))
    checks <- .gk_verify_add(checks, paste0("review_id_", gsub("/", "_", tsv_paths[[i]], fixed = TRUE)), ok)
  }
  config_json <- .gk_read_json(file.path(dir, "config.json"))
  config <- .gk_config_from_list(config_json$config %||% config_json)
  checks <- .gk_verify_add(checks, "config_hash", identical(gk_config_hash(config), snapshot$config_sha256))
  if (!is.null(cellspec_dir)) {
    .gk_check_dir_exists(cellspec_dir)
    source <- gk_read_cellspec(cellspec_dir)
    checks <- .gk_verify_add(checks, "source_manifest_hash",
      identical(source$provenance$manifest_sha256, snapshot$source_manifest_sha256))
  }
  cells <- tsvs[["cells.tsv.gz"]]
  scores <- tsvs[["scores.tsv.gz"]]
  thresholds <- tsvs[["thresholds.tsv"]]
  threshold_data <- thresholds[, setdiff(names(thresholds), "review_id"), drop = FALSE]
  class(threshold_data) <- c("gk_thresholds", "data.frame")
  attr(threshold_data, "config_sha256") <- snapshot$config_sha256
  attr(threshold_data, "source_sha256") <- snapshot$source_sha256
  score_cols <- grep("^score__", names(scores), value = TRUE)
  score_matrix <- as.matrix(scores[, score_cols, drop = FALSE])
  colnames(score_matrix) <- sub("^score__", "", score_cols)
  stub_cells <- cells[, c("image_id", "cell_id", "x", "y"), drop = FALSE]
  prepared <- structure(list(cells = stub_cells, score = score_matrix,
    config = config, config_sha256 = snapshot$config_sha256,
    source_sha256 = snapshot$source_sha256, source_manifest_sha256 = snapshot$source_manifest_sha256),
    class = "gk_prepared")
  identity_thresholds <- threshold_data[is.na(threshold_data$parent), , drop = FALSE]
  class(identity_thresholds) <- c("gk_thresholds", "data.frame")
  attr(identity_thresholds, "config_sha256") <- snapshot$config_sha256
  attr(identity_thresholds, "source_sha256") <- snapshot$source_sha256
  base_classification <- suppressWarnings(gk_classify(prepared, identity_thresholds, config))
  state_thresholds <- threshold_data[!is.na(threshold_data$parent), , drop = FALSE]
  class(state_thresholds) <- c("gk_thresholds", "data.frame")
  attr(state_thresholds, "config_sha256") <- snapshot$config_sha256
  attr(state_thresholds, "source_sha256") <- snapshot$source_sha256
  state_data <- tsvs[["state_calls.tsv.gz"]][, setdiff(names(tsvs[["state_calls.tsv.gz"]]), "review_id"), drop = FALSE]
  state_obj <- structure(list(calls = state_data, state_thresholds = state_thresholds,
    config_sha256 = snapshot$config_sha256, source_sha256 = snapshot$source_sha256),
    class = "gk_state_calls")
  structure_data <- tsvs[["structures.tsv"]][, setdiff(names(tsvs[["structures.tsv"]]), "review_id"), drop = FALSE]
  cell_structure <- cells[, c("image_id", "cell_id", "structure_id"), drop = FALSE]
  structure_obj <- structure(list(structures = structure_data, cell_structure = cell_structure,
    config_sha256 = snapshot$config_sha256, source_sha256 = snapshot$source_sha256),
    class = "gk_structures")
  review <- gk_review(base_classification, state_obj, structure_obj, identity_thresholds, prepared)
  for (name in names(review$ledgers)) {
    x <- tsvs[[file.path("ledgers", paste0(name, ".tsv"))]]
    review$ledgers[[name]] <- x[, setdiff(names(x), "review_id"), drop = FALSE]
  }
  replayed <- gk_replay(review)$cells
  compare <- intersect(c("image_id", "cell_id", "base_cell_type", "cell_type", "rule_id",
    "pending_review", "excluded", "structure_id", "structure_decision",
    "disposition_effective", "analysed"), names(cells))
  checks <- .gk_verify_add(checks, "replay_matches_cells",
    identical(replayed[, compare, drop = FALSE], cells[, compare, drop = FALSE]))
  benign_tumour <- any(cells$structure_decision == "Benign" & cells$cell_type == "Tumor cells", na.rm = TRUE)
  checks <- .gk_verify_add(checks, "benign_structure_not_tumour", !benign_tumour)
  deleted_analysed <- any(cells$disposition_effective == "DELETE" & cells$analysed, na.rm = TRUE)
  checks <- .gk_verify_add(checks, "deleted_cells_not_analysed", !deleted_analysed)
  checks <- .gk_verify_add(checks, "threshold_hash",
    identical(snapshot$thresholds_sha256, .gk_sha256_object(thresholds[, setdiff(names(thresholds), "review_id"), drop = FALSE])))
  .gk_verify_fail(checks, strict)
}

#' Read a verified export
#'
#' @param dir Export directory.
#' @param verify Verify before reading?
#' @return A `gk_export` list containing snapshot, configuration and tables.
#' @family export
#' @export
gk_read_export <- function(dir, verify = TRUE) {
  .gk_check_dir_exists(dir)
  .gk_check_flag(verify)
  checks <- if (verify) gk_verify_export(dir, strict = TRUE) else NULL
  snapshot <- .gk_read_json(file.path(dir, "snapshot.json"))
  config_json <- .gk_read_json(file.path(dir, "config.json"))
  out <- list(
    snapshot = snapshot,
    config = .gk_config_from_list(config_json$config %||% config_json),
    thresholds = .gk_read_tsv(file.path(dir, "thresholds.tsv")),
    cells = .gk_read_tsv(file.path(dir, "cells.tsv.gz")),
    scores = .gk_read_tsv(file.path(dir, "scores.tsv.gz")),
    state_calls = .gk_read_tsv(file.path(dir, "state_calls.tsv.gz")),
    structures = .gk_read_tsv(file.path(dir, "structures.tsv")),
    ledgers = stats::setNames(lapply(names(.gk_empty_ledgers()), function(name) {
      .gk_read_tsv(file.path(dir, "ledgers", paste0(name, ".tsv")))
    }), names(.gk_empty_ledgers())), checks = checks
  )
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
