# Version 2 binds typed table contents as well as replay inputs and decisions.
# Transport checksums detect damaged files; the full review ID binds meaning.
.gk_export_paths <- function() {
  c("thresholds.tsv", "cells.tsv.gz", "scores.tsv.gz", "state_calls.tsv.gz",
    "structures.tsv", paste0("ledgers/", names(.gk_empty_ledgers()), ".tsv"),
    paste0("replay/", c("prepared_cells", "raw_scores", "source_flags",
      "callability", "localization", "base_state_calls", "cell_structures"), ".tsv.gz"))
}

.gk_table_schema <- function(x) {
  types <- vapply(x, typeof, character(1))
  if (any(!types %in% c("character", "double", "integer", "logical")) ||
    anyDuplicated(names(x)) || any(!nzchar(names(x)))) {
    .gk_abort("Export tables must have unique names and atomic typed columns.", class = "verify")
  }
  types
}

.gk_table_hash <- function(x) {
  columns <- lapply(x, function(column) {
    attributes(column) <- NULL
    column
  })
  do.call(.gk_sha256_data, c(list(names(x), .gk_table_schema(x), nrow(x)), unname(columns)))
}

.gk_export_matrix <- function(prepared, matrix) {
  cbind(.gk_cell_keys(prepared$cells), as.data.frame(matrix, check.names = FALSE),
    row.names = NULL)
}

.gk_export_tables <- function(snapshot) {
  review <- snapshot$review
  prepared <- review$prepared
  cells <- snapshot$replayed$cells
  idx <- match(.gk_cell_key(cells), .gk_cell_key(prepared$cells))
  if (anyNA(idx)) .gk_abort("Replay contains cells absent from its source.", class = "verify")
  cells$x <- prepared$cells$x[idx]
  cells$y <- prepared$cells$y[idx]
  score <- .gk_score_matrix(prepared, review$classification$correction)
  scores <- .gk_cell_keys(prepared$cells)
  for (marker in colnames(score)) scores[[paste0("score__", marker)]] <- score[, marker]
  for (marker in names(prepared$localization)) {
    scores[[paste0("localization_ratio__", marker)]] <- prepared$localization[[marker]]$ratio
  }
  localization <- data.frame(image_id = character(), cell_id = character(),
    marker = character(), numerator = double(), denominator = double(),
    ratio = double(), evaluable = logical())
  for (marker in names(prepared$localization)) {
    localization <- rbind(localization, cbind(.gk_cell_keys(prepared$cells),
      marker = marker, prepared$localization[[marker]], row.names = NULL))
  }
  tables <- c(list(.gk_export_thresholds(snapshot), cells, scores,
    snapshot$replayed$state_calls, review$structures$structures), review$ledgers,
    list(prepared$cells, .gk_export_matrix(prepared, prepared$score),
      .gk_export_matrix(prepared, prepared$source), as.data.frame(prepared$callability),
      localization, review$state_calls$calls, review$structures$cell_structure))
  names(tables) <- .gk_export_paths()
  lapply(tables, function(x) {
    x <- as.data.frame(x, stringsAsFactors = FALSE)
    rownames(x) <- NULL
    x
  })
}

.gk_export_content <- function(snapshot, tables = .gk_export_tables(snapshot)) {
  list(
    table_schemas = lapply(tables, function(x) as.list(.gk_table_schema(x))),
    table_hashes = as.list(vapply(tables, .gk_table_hash, character(1))),
    matrix_rownames = if (is.null(rownames(snapshot$review$prepared$score))) NULL else
      I(rownames(snapshot$review$prepared$score)),
    disabled_rules = snapshot$replayed$disabled_rules
  )
}

.gk_export_identity <- function(snapshot) {
  snapshot[c("schema", "format_version", "status", "production_eligible", "reviewer",
    "source_sha256", "source_manifest_sha256", "config_sha256", "thresholds_sha256",
    "correction_model_sha256", "ledgers_sha256", "package_version", "content")]
}

.gk_read_export_tables <- function(dir, snapshot) {
  paths <- .gk_export_paths()
  if (!setequal(names(snapshot$content$table_schemas), paths) ||
    !setequal(names(snapshot$content$table_hashes), paths)) {
    .gk_abort("Export has missing or unknown table schemas.", class = "verify")
  }
  out <- lapply(paths, function(path) {
    types <- unlist(snapshot$content$table_schemas[[path]], use.names = TRUE)
    if (!is.character(types) || anyDuplicated(names(types)) ||
      any(!types %in% c("character", "double", "integer", "logical"))) {
      .gk_abort("Invalid table schema in snapshot.", class = "verify")
    }
    x <- .gk_read_tsv(file.path(dir, path), types = c(review_id = "character", types))
    # JSON object key ordering is canonical; TSV preserves original column order.
    if (!identical(names(x)[1L], "review_id") ||
      !setequal(names(x)[-1L], names(types)) || anyNA(x$review_id) ||
      any(x$review_id != snapshot$review_id)) {
      .gk_abort("Table {.val {path}} has invalid columns or review IDs.", class = "verify")
    }
    x[, -1L, drop = FALSE]
  })
  stats::setNames(out, paths)
}

.gk_export_bind_thresholds <- function(x, prepared, score) {
  class(x) <- c("gk_thresholds", "data.frame")
  rownames(x) <- NULL
  attr(x, "config_sha256") <- prepared$config_sha256
  attr(x, "source_sha256") <- prepared$source_sha256
  attr(x, "cell_keys") <- .gk_cell_keys(prepared$cells)
  attr(x, "score_sha256") <- .gk_score_hash(prepared, score)
  x
}

.gk_export_restore_review <- function(snapshot, config, tables, model) {
  cells <- tables[["replay/prepared_cells.tsv.gz"]]
  markers <- config$panel$markers$marker
  matrix_from <- function(path, columns = markers) {
    table <- tables[[path]]
    if (!identical(.gk_cell_keys(table), .gk_cell_keys(cells)) ||
      !all(columns %in% names(table))) {
      .gk_abort("Export score rows or markers do not match prepared cells.", class = "verify")
    }
    out <- as.matrix(table[, columns, drop = FALSE])
    dimnames(out) <- list(unlist(snapshot$content$matrix_rownames, use.names = FALSE), markers)
    out
  }
  raw_score <- matrix_from("replay/raw_scores.tsv.gz")
  source <- matrix_from("replay/source_flags.tsv.gz")
  localization <- tables[["replay/localization.tsv.gz"]]
  loc <- lapply(unique(localization$marker), function(marker) {
    x <- localization[localization$marker == marker, , drop = FALSE]
    if (!identical(.gk_cell_keys(x), .gk_cell_keys(cells)))
      .gk_abort("Localization rows do not match prepared cells.", class = "verify")
    x <- x[, c("numerator", "denominator", "ratio", "evaluable"), drop = FALSE]
    rownames(x) <- NULL
    x
  })
  names(loc) <- unique(localization$marker)
  prepared <- structure(list(cells = cells, score = raw_score, source = source,
    localization = loc, callability = tables[["replay/callability.tsv.gz"]],
    config = config, config_sha256 = snapshot$config_sha256,
    source_sha256 = snapshot$source_sha256,
    source_manifest_sha256 = snapshot$source_manifest_sha256 %||% NA_character_),
    class = "gk_prepared")
  score <- matrix_from("scores.tsv.gz", paste0("score__", markers))
  correction <- if (identical(model, "none")) NULL else structure(list(
    matrix = score, model = model, source_sha256 = prepared$source_sha256,
    config_sha256 = prepared$config_sha256, cell_keys = .gk_cell_keys(cells),
    score_sha256 = .gk_score_hash(prepared, score)), class = "gk_corrected")
  thresholds <- tables[["thresholds.tsv"]]
  identity <- .gk_export_bind_thresholds(thresholds[is.na(thresholds$parent), , drop = FALSE], prepared, score)
  classification <- withCallingHandlers(gk_classify(prepared, identity, config, correction = correction),
    gatekeepr_warning_disabled_rules = function(w) invokeRestart("muffleWarning"))
  states <- structure(list(calls = tables[["replay/base_state_calls.tsv.gz"]],
    state_thresholds = .gk_export_bind_thresholds(thresholds[!is.na(thresholds$parent), , drop = FALSE], prepared, score),
    config_sha256 = prepared$config_sha256, source_sha256 = prepared$source_sha256,
    thresholds_sha256 = .gk_thresholds_hash(identity),
    classification_sha256 = .gk_classification_hash(classification),
    score_sha256 = classification$score_sha256), class = "gk_state_calls")
  structures <- structure(list(structures = tables[["structures.tsv"]],
    cell_structure = tables[["replay/cell_structures.tsv.gz"]], classification = classification,
    config_sha256 = prepared$config_sha256, source_sha256 = prepared$source_sha256), class = "gk_structures")
  review <- gk_review(classification, states, structures, identity, prepared)
  for (name in names(review$ledgers)) review$ledgers[[name]] <- tables[[paste0("ledgers/", name, ".tsv")]]
  review
}
