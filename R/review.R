# Immutable review state and append-only ledgers.

.gk_ledger_columns <- function(name) {
  common <- list(
    sequence = integer(), order = integer(), entry_id = character(),
    time_utc = character(), reviewer = character(), image_id = character(),
    reason = character(), reverts = character()
  )
  extra <- switch(name,
    cut_log = list(marker = character(), parent = character(), old_estimate = double(),
      new_estimate = double(), old_status = character()),
    structure_log = list(mode = character(), structure_id = character(), xmin = double(),
      xmax = double(), ymin = double(), ymax = double(), decision = character(),
      n_affected_at_creation = integer(), cut_at_creation = integer()),
    disposition_log = list(mode = character(), cell_id = character(), xmin = double(),
      xmax = double(), ymin = double(), ymax = double(), disposition = character(),
      n_affected_at_creation = integer()),
    state_log = list(marker = character(), parent = character(), action = character(),
      old_estimate = double(), new_estimate = double())
  )
  as.data.frame(c(common, extra), stringsAsFactors = FALSE)
}

.gk_empty_ledgers <- function() {
  stats::setNames(lapply(c("cut_log", "structure_log", "disposition_log", "state_log"),
    .gk_ledger_columns), c("cut_log", "structure_log", "disposition_log", "state_log"))
}

.gk_review_clone <- function(review) {
  out <- review
  out$ledgers <- lapply(review$ledgers, function(x) x)
  out$updated_utc <- .gk_utc_now()
  out
}

.gk_review_next_order <- function(review) {
  values <- unlist(lapply(review$ledgers, function(x) x$order), use.names = FALSE)
  if (length(values) == 0L) 1L else max(values) + 1L
}

.gk_append_ledger <- function(review, name, row) {
  out <- .gk_review_clone(review)
  order <- .gk_review_next_order(review)
  row$sequence <- as.integer(order)
  row$order <- as.integer(order)
  row$entry_id <- paste0(switch(name, cut_log = "CL", structure_log = "ER",
    disposition_log = "XR", state_log = "SL"), sprintf("%04d", order))
  row$time_utc <- .gk_utc_now()
  out$ledgers[[name]] <- rbind(out$ledgers[[name]], row[, names(out$ledgers[[name]]), drop = FALSE])
  out
}

.gk_review_check <- function(review) {
  .gk_check_class(review, "gk_review")
  invisible(review)
}

.gk_review_image <- function(review, image_id) {
  .gk_check_string(image_id)
  if (!image_id %in% review$prepared$cells$image_id) {
    .gk_abort("Image {.val {image_id}} is not present in the prepared data.", class = "ledger")
  }
  invisible(image_id)
}

.gk_review_marker <- function(review, marker, state = FALSE) {
  .gk_check_string(marker)
  pm <- review$config$panel$markers
  roles <- pm$role[pm$marker == marker]
  if (length(roles) != 1L || (state && roles != "state") || (!state && roles == "context")) {
    .gk_abort("Marker {.val {marker}} is not a valid {.arg marker} for this review action.", class = "ledger")
  }
  invisible(marker)
}

.gk_bbox <- function(bbox) {
  if (!is.numeric(bbox) || length(bbox) != 4L || any(!is.finite(bbox))) {
    .gk_abort("{.arg bbox} must be c(xmin, xmax, ymin, ymax) with finite values.", class = "input")
  }
  if (bbox[[1L]] > bbox[[2L]] || bbox[[3L]] > bbox[[4L]]) {
    .gk_abort("{.arg bbox} limits must be ordered xmin, xmax, ymin, ymax.", class = "input")
  }
  as.double(bbox)
}

.gk_cells_in_bbox <- function(prepared, image_id, bbox) {
  bbox <- .gk_bbox(bbox)
  cells <- prepared$cells
  which(cells$image_id == image_id & cells$x >= bbox[[1L]] & cells$x <= bbox[[2L]] &
    cells$y >= bbox[[3L]] & cells$y <= bbox[[4L]])
}

#' Create an editable review state
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Creates an immutable base review and four empty append-only ledgers. Every
#' subsequent review function returns a new object; effective labels and
#' dispositions are calculated by [gk_replay()].
#'
#' @param classification A [gk_classify()] result.
#' @param state_calls A [gk_state_calls()] result.
#' @param structures A [gk_structures()] result.
#' @param thresholds A [gk_thresholds()] result.
#' @param prepared The matching [gk_prepare()] result.
#'
#' @return An object of class `gk_review`.
#'
#' @family review
#' @export
gk_review <- function(classification, state_calls, structures, thresholds, prepared) {
  .gk_check_class(classification, "gk_classification")
  .gk_check_class(state_calls, "gk_state_calls")
  .gk_check_class(structures, "gk_structures")
  .gk_check_class(thresholds, "gk_thresholds")
  .gk_check_class(prepared, "gk_prepared")
  if (!identical(prepared$source_sha256, classification$source_sha256) ||
    !identical(prepared$source_sha256, structures$source_sha256) ||
    !identical(prepared$config_sha256, classification$config_sha256)) {
    .gk_abort("Review inputs do not share the same prepared source and configuration.", class = "state")
  }
  structure(list(
    classification = classification, state_calls = state_calls,
    structures = structures, thresholds = thresholds, prepared = prepared,
    config = prepared$config, config_sha256 = prepared$config_sha256,
    source_sha256 = prepared$source_sha256, ledgers = .gk_empty_ledgers(),
    created_utc = .gk_utc_now(), updated_utc = .gk_utc_now(),
    locked = FALSE
  ), class = "gk_review")
}

#' Return the four review ledgers
#' @param review A [gk_review()] object.
#' @return A named list of append-only data frames.
#' @family review
#' @export
gk_ledgers <- function(review) {
  .gk_review_check(review)
  review$ledgers
}

#' Set an identity or state threshold in the review ledger
#'
#' @param review A [gk_review()] object.
#' @param image_id Image to change.
#' @param marker Marker to change.
#' @param parent Parent set for a state marker; `NA` for identity markers.
#' @param estimate New finite threshold.
#' @param reviewer Reviewer identifier.
#' @param reason Required reason recorded in the ledger.
#' @return A new `gk_review` object.
#' @family review
#' @export
gk_set_cut <- function(review, image_id, marker, parent = NA_character_, estimate,
                       reviewer, reason) {
  .gk_review_check(review)
  if (isTRUE(review$locked)) .gk_abort("Locked reviews cannot be changed.", class = "locked")
  .gk_review_image(review, image_id)
  .gk_review_marker(review, marker, state = !is.na(parent))
  .gk_check_reviewer(reviewer)
  .gk_check_reason(reason)
  .gk_check_number(estimate)
  if (length(parent) != 1L || (!is.na(parent) && !is.character(parent))) {
    .gk_abort("{.arg parent} must be one parent name or NA.", class = "input")
  }
  pm <- review$config$panel$markers
  role <- pm$role[pm$marker == marker]
  is_state <- identical(role, "state")
  if (is_state && (is.na(parent) || !parent %in% review$config$panel$parents[[marker]])) {
    .gk_abort("State cut requires one configured parent set.", class = "ledger")
  }
  if (!is_state && !is.na(parent)) .gk_abort("Identity cuts cannot name a parent set.", class = "ledger")
  source <- if (is_state) review$state_calls$state_thresholds else review$thresholds
  hit <- .gk_threshold_row(source, image_id, marker, parent)
  old <- if (length(hit)) source$estimate[[hit[[1L]]]] else NA_real_
  old_status <- if (length(hit)) source$status[[hit[[1L]]]] else "NOT_CALLABLE_UNAVAILABLE"
  row <- data.frame(
    image_id = image_id, reason = reason, reviewer = reviewer, reverts = NA_character_,
    marker = marker, parent = as.character(parent), old_estimate = old,
    new_estimate = as.double(estimate), old_status = old_status,
    stringsAsFactors = FALSE
  )
  .gk_append_ledger(review, if (is_state) "state_log" else "cut_log", row)
}

#' Decide one structure or bounding box
#' @param review A [gk_review()] object.
#' @param image_id Image to change.
#' @param structure_id A structure ID, or `NULL`.
#' @param bbox A `c(xmin, xmax, ymin, ymax)` selection, or `NULL`.
#' @param decision One of `"Tumor"`, `"Benign"` or `"Unresolved"`.
#' @param reviewer Reviewer identifier.
#' @param reason Required reason recorded in the ledger.
#' @return A new `gk_review` object.
#' @family review
#' @export
gk_decide_structure <- function(review, image_id, structure_id = NULL, bbox = NULL,
                                 decision = c("Tumor", "Benign", "Unresolved"),
                                 reviewer, reason) {
  .gk_review_check(review)
  if (isTRUE(review$locked)) .gk_abort("Locked reviews cannot be changed.", class = "locked")
  .gk_review_image(review, image_id)
  decision <- rlang::arg_match(decision, .gk_decisions)
  .gk_check_reviewer(reviewer)
  .gk_check_reason(reason)
  if (xor(is.null(structure_id), is.null(bbox))) {
    mode <- if (is.null(structure_id)) "BBOX" else "STRUCTURE"
  } else {
    .gk_abort("Supply exactly one of {.arg structure_id} or {.arg bbox}.", class = "input")
  }
  if (identical(mode, "STRUCTURE")) {
    .gk_check_string(structure_id)
    hit <- review$structures$structures$structure_id == structure_id &
      review$structures$structures$image_id == image_id
    if (!any(hit)) .gk_abort("Structure {.val {structure_id}} is not present on this image.", class = "ledger")
    s <- review$structures$structures[which(hit)[[1L]], ]
    bbox <- c(s$xmin, s$xmax, s$ymin, s$ymax)
    n <- sum(review$structures$cell_structure$image_id == image_id &
      review$structures$cell_structure$structure_id == structure_id)
  } else {
    bbox <- .gk_bbox(bbox)
    structure_id <- NA_character_
    n <- length(.gk_cells_in_bbox(review$prepared, image_id, bbox))
  }
  row <- data.frame(image_id = image_id, reason = reason, reviewer = reviewer,
    reverts = NA_character_, mode = mode, structure_id = structure_id,
    xmin = bbox[[1L]], xmax = bbox[[2L]], ymin = bbox[[3L]], ymax = bbox[[4L]],
    decision = decision, n_affected_at_creation = as.integer(n),
    cut_at_creation = NA_integer_, stringsAsFactors = FALSE)
  .gk_append_ledger(review, "structure_log", row)
}

#' Set a cell disposition
#' @param review A [gk_review()] object.
#' @param image_id Image to change.
#' @param cell_id A cell ID, or `NULL` when using `bbox`.
#' @param bbox A `c(xmin, xmax, ymin, ymax)` selection, or `NULL`.
#' @param disposition `"EXCLUDE"`, `"DELETE"` or `"RESTORE"`.
#' @param reviewer Reviewer identifier.
#' @param reason Required reason recorded in the ledger.
#' @return A new `gk_review` object.
#' @family review
#' @export
gk_dispose <- function(review, image_id, cell_id = NULL, bbox = NULL,
                       disposition = c("EXCLUDE", "DELETE", "RESTORE"),
                       reviewer, reason) {
  .gk_review_check(review)
  if (isTRUE(review$locked)) .gk_abort("Locked reviews cannot be changed.", class = "locked")
  .gk_review_image(review, image_id)
  disposition <- rlang::arg_match(disposition, c("EXCLUDE", "DELETE", "RESTORE"))
  .gk_check_reviewer(reviewer)
  .gk_check_reason(reason)
  if (xor(is.null(cell_id), is.null(bbox))) {
    mode <- if (is.null(cell_id)) "BBOX" else "POINT"
  } else {
    .gk_abort("Supply exactly one of {.arg cell_id} or {.arg bbox}.", class = "input")
  }
  if (identical(mode, "POINT")) {
    .gk_check_string(cell_id)
    hit <- review$prepared$cells$cell_id == cell_id & review$prepared$cells$image_id == image_id
    if (!any(hit)) .gk_abort("Cell {.val {cell_id}} is not present on this image.", class = "ledger")
    bbox <- c(NA_real_, NA_real_, NA_real_, NA_real_)
    n <- 1L
  } else {
    bbox <- .gk_bbox(bbox)
    cell_id <- NA_character_
    n <- length(.gk_cells_in_bbox(review$prepared, image_id, bbox))
    if (n == 0L) .gk_abort("The disposition selection contains no cells.", class = "ledger")
  }
  row <- data.frame(image_id = image_id, reason = reason, reviewer = reviewer,
    reverts = NA_character_, mode = mode, cell_id = cell_id,
    xmin = bbox[[1L]], xmax = bbox[[2L]], ymin = bbox[[3L]], ymax = bbox[[4L]],
    disposition = disposition, n_affected_at_creation = as.integer(n),
    stringsAsFactors = FALSE)
  .gk_append_ledger(review, "disposition_log", row)
}

#' Enable, disable or set a parent-specific state call
#' @param review A [gk_review()] object.
#' @param image_id Image to change.
#' @param marker State marker.
#' @param parent Configured parent set.
#' @param action `"ENABLE"`, `"DISABLE"` or `"SET_CUT"`.
#' @param estimate New threshold for `SET_CUT`.
#' @param reviewer Reviewer identifier.
#' @param reason Required reason recorded in the ledger.
#' @return A new `gk_review` object.
#' @family review
#' @export
gk_set_state <- function(review, image_id, marker, parent,
                         action = c("ENABLE", "DISABLE", "SET_CUT"), estimate = NULL,
                         reviewer, reason) {
  .gk_review_check(review)
  if (isTRUE(review$locked)) .gk_abort("Locked reviews cannot be changed.", class = "locked")
  .gk_review_image(review, image_id)
  .gk_review_marker(review, marker, state = TRUE)
  .gk_check_string(parent)
  if (!parent %in% review$config$panel$parents[[marker]]) .gk_abort("Parent is not configured for this marker.", class = "ledger")
  action <- rlang::arg_match(action)
  .gk_check_reviewer(reviewer)
  .gk_check_reason(reason)
  source <- review$state_calls$state_thresholds
  hit <- .gk_threshold_row(source, image_id, marker, parent)
  old <- if (length(hit)) source$estimate[[hit[[1L]]]] else NA_real_
  if (identical(action, "SET_CUT")) {
    if (is.null(estimate)) .gk_abort("SET_CUT needs a finite {.arg estimate}.", class = "input")
    .gk_check_number(estimate)
  } else if (!is.null(estimate)) {
    .gk_abort("{.arg estimate} is used only with SET_CUT.", class = "input")
  }
  row <- data.frame(image_id = image_id, reason = reason, reviewer = reviewer,
    reverts = NA_character_, marker = marker, parent = parent, action = action,
    old_estimate = old, new_estimate = if (is.null(estimate)) NA_real_ else as.double(estimate),
    stringsAsFactors = FALSE)
  .gk_append_ledger(review, "state_log", row)
}

.gk_review_all_rows <- function(review) {
  rows <- lapply(names(review$ledgers), function(name) {
    x <- review$ledgers[[name]]
    if (!nrow(x)) return(data.frame())
    data.frame(order = x$order, entry_id = x$entry_id, ledger = name,
      stringsAsFactors = FALSE)
  })
  rows <- rows[vapply(rows, nrow, integer(1)) > 0L]
  if (!length(rows)) return(data.frame())
  out <- do.call(rbind, rows)
  out[order(out$order), , drop = FALSE]
}

.gk_reverted_entries <- function(review) {
  vals <- unlist(lapply(review$ledgers, function(x) x$reverts), use.names = FALSE)
  unique(vals[!is.na(vals) & nzchar(vals)])
}

.gk_effective_cut <- function(review, image_id, marker, parent = NA_character_, state = FALSE) {
  log <- review$ledgers[[if (state) "state_log" else "cut_log"]]
  if (nrow(log) == 0L) return(NULL)
  skipped <- .gk_reverted_entries(review)
  log <- log[!log$entry_id %in% skipped & log$image_id == image_id & log$marker == marker, , drop = FALSE]
  if (state) log <- log[log$parent == parent & log$action %in% c("SET_CUT"), , drop = FALSE]
  else log <- log[is.na(log$parent) & is.na(parent), , drop = FALSE]
  if (!nrow(log)) return(NULL)
  row <- log[which.max(log$order), , drop = FALSE]
  list(estimate = row$new_estimate[[1L]], entry_id = row$entry_id[[1L]])
}

#' Replay all effective review decisions
#'
#' @param review A [gk_review()] object.
#' @return A `gk_replayed` object with effective cells, thresholds and state calls.
#' @family review
#' @export
gk_replay <- function(review) {
  .gk_review_check(review)
  base <- review$classification$cells
  out <- base
  coords <- review$prepared$cells[match(out$cell_id, review$prepared$cells$cell_id),
    c("x", "y"), drop = FALSE]
  out$x <- coords$x
  out$y <- coords$y
  out$base_cell_type <- base$cell_type
  out$structure_id <- review$structures$cell_structure$structure_id[match(out$cell_id,
    review$structures$cell_structure$cell_id)]
  out$structure_decision <- NA_character_
  skipped <- .gk_reverted_entries(review)
  struct_log <- review$ledgers$structure_log
  if (nrow(struct_log)) struct_log <- struct_log[!struct_log$entry_id %in% skipped, , drop = FALSE]
  if (nrow(struct_log)) {
    for (i in seq_len(nrow(out))) {
      rows <- struct_log[struct_log$image_id == out$image_id[[i]], , drop = FALSE]
      if (nrow(rows)) {
        rows <- rows[vapply(seq_len(nrow(rows)), function(j) {
          if (rows$mode[[j]] == "STRUCTURE") {
            identical(rows$structure_id[[j]], out$structure_id[[i]])
          } else {
            out$x[[i]] >= rows$xmin[[j]] && out$x[[i]] <= rows$xmax[[j]] &&
              out$y[[i]] >= rows$ymin[[j]] && out$y[[i]] <= rows$ymax[[j]]
          }
        }, logical(1)), , drop = FALSE]
        if (nrow(rows)) out$structure_decision[[i]] <- rows$decision[[which.max(rows$order)]]
      }
    }
  }
  h <- review$config$hierarchy
  pending_rule <- vapply(h$rules, function(r) !is.null(r$review), logical(1))
  for (r in h$rules[pending_rule]) {
    take <- out$rule_id == r$rule_id & !is.na(out$structure_decision) &
      out$structure_decision %in% names(r$decisions)
    out$cell_type[take] <- unname(unlist(r$decisions[out$structure_decision[take]]))
    out$pending_review[take] <- FALSE
  }
  effective_state <- review$state_calls$calls
  state_log <- review$ledgers$state_log
  if (nrow(state_log)) state_log <- state_log[!state_log$entry_id %in% skipped, , drop = FALSE]
  effective_state$enabled <- FALSE
  effective_state$in_parent <- vapply(seq_len(nrow(effective_state)), function(i) {
    labels <- review$config$parent_sets[[effective_state$parent[[i]]]]
    out$cell_type[match(effective_state$cell_id[[i]], out$cell_id)] %in% labels
  }, logical(1))
  effective_state$positive <- effective_state$evaluable & effective_state$in_parent &
    effective_state$localization_ratio >= vapply(effective_state$marker, function(marker) {
      loc <- review$config$panel$localization[[marker]]
      if (is.null(loc)) 0 else loc$min_ratio %||% 0
    }, numeric(1)) & is.finite(effective_state$estimate) &
    effective_state$score >= effective_state$estimate
  state_cut <- list()
  for (img in unique(effective_state$image_id)) {
    for (marker in unique(effective_state$marker)) {
      parents <- unique(effective_state$parent[effective_state$image_id == img &
        effective_state$marker == marker])
      for (parent in parents) {
        rows <- state_log[state_log$image_id == img & state_log$marker == marker &
          state_log$parent == parent, , drop = FALSE]
        if (nrow(rows)) {
          last <- rows[which.max(rows$order), ]
          effective_state$enabled[effective_state$image_id == img &
            effective_state$marker == marker & effective_state$parent == parent] <-
            last$action[[1L]] == "ENABLE"
          if (last$action[[1L]] == "SET_CUT") state_cut[[paste(img, marker, parent, sep = "\r")]] <- last$new_estimate[[1L]]
        }
      }
    }
  }
  for (key in names(state_cut)) {
    p <- strsplit(key, "\r", fixed = TRUE)[[1L]]
    take <- effective_state$image_id == p[[1L]] & effective_state$marker == p[[2L]] & effective_state$parent == p[[3L]]
    effective_state$estimate[take] <- state_cut[[key]]
    marker <- p[[2L]]
    loc <- review$config$panel$localization[[marker]]
    min_ratio <- if (is.null(loc)) 0 else loc$min_ratio %||% 0
    effective_state$positive[take] <- effective_state$evaluable[take] &
      effective_state$in_parent[take] & effective_state$localization_ratio[take] >= min_ratio &
      is.finite(effective_state$score[take]) & effective_state$score[take] >= state_cut[[key]]
  }
  dispositions <- rep("NONE", nrow(out))
  disp_log <- review$ledgers$disposition_log
  if (nrow(disp_log)) disp_log <- disp_log[!disp_log$entry_id %in% skipped, , drop = FALSE]
  if (nrow(disp_log)) {
    for (i in seq_len(nrow(disp_log))) {
      hit <- if (disp_log$mode[[i]] == "POINT") {
        out$image_id == disp_log$image_id[[i]] & out$cell_id == disp_log$cell_id[[i]]
      } else {
        out$image_id == disp_log$image_id[[i]] & out$x >= disp_log$xmin[[i]] & out$x <= disp_log$xmax[[i]] &
          out$y >= disp_log$ymin[[i]] & out$y <= disp_log$ymax[[i]]
      }
      dispositions[hit] <- if (disp_log$disposition[[i]] == "RESTORE") "NONE" else disp_log$disposition[[i]]
    }
  }
  out$disposition_effective <- dispositions
  out$analysed <- !out$excluded & dispositions == "NONE"
  # Refinements are evaluated after structure decisions and state settings.
  for (rf in review$config$refinements) {
    take_state <- effective_state$enabled & effective_state$positive &
      effective_state$marker == rf$marker & effective_state$parent == rf$parent
    state_cells <- unique(effective_state$cell_id[take_state])
    take <- out$cell_id %in% state_cells & out$cell_type == rf$from_label & out$analysed
    out$cell_type[take] <- rf$to_label
  }
  structure(list(cells = out, state_calls = effective_state,
    thresholds = review$thresholds, ledgers = review$ledgers,
    config_sha256 = review$config_sha256, source_sha256 = review$source_sha256),
    class = "gk_replayed")
}

#' @export
print.gk_review <- function(x, ...) {
  n <- sum(vapply(x$ledgers, nrow, integer(1)))
  cli::cli_text("{.cls gk_review}: {n} ledger entr{?y/ies}; locked = {x$locked}")
  invisible(x)
}

#' @export
print.gk_replayed <- function(x, ...) {
  cli::cli_text("{.cls gk_replayed}: {nrow(x$cells)} effective cells")
  invisible(x)
}

#' Import identity-marker cuts without replacing other ledgers
#'
#' @param review A [gk_review()] object.
#' @param path A TSV file with `image_id`, `marker`, `estimate` and optional
#'   `parent` columns.
#' @param reviewer Reviewer identifier.
#' @param reason Required reason recorded for every imported cut.
#' @return A new `gk_review` object.
#' @family review
#' @export
gk_import_cuts <- function(review, path, reviewer, reason) {
  .gk_review_check(review)
  .gk_check_file_exists(path)
  .gk_check_reviewer(reviewer)
  .gk_check_reason(reason)
  cuts <- .gk_read_tsv(path, types = c(image_id = "character", marker = "character",
    parent = "character", estimate = "double"))
  needed <- c("image_id", "marker", "estimate")
  if (!all(needed %in% names(cuts))) {
    .gk_abort("The cuts file must contain {.val {needed}}.", class = "input")
  }
  if (!"parent" %in% names(cuts)) cuts$parent <- NA_character_
  out <- review
  for (i in seq_len(nrow(cuts))) {
    out <- gk_set_cut(out, cuts$image_id[[i]], cuts$marker[[i]],
      parent = cuts$parent[[i]], estimate = cuts$estimate[[i]],
      reviewer = reviewer, reason = reason)
  }
  out
}

#' Replace selected review ledgers from a saved checkpoint
#'
#' @param review A [gk_review()] object.
#' @param snapshot_dir A directory written by [gk_save_review()].
#' @param scope Ledgers to replace.
#' @param confirm Must be `TRUE`, because history is being replaced.
#' @param backup_dir Directory in which to save the current review first, or
#'   `NULL` for a temporary directory.
#' @return A new `gk_review` object with `backup_path` attribute.
#' @family review
#' @export
gk_replace_review <- function(review, snapshot_dir,
                              scope = c("cuts", "structures", "dispositions", "states", "all"),
                              confirm = FALSE, backup_dir = NULL) {
  .gk_review_check(review)
  if (!isTRUE(confirm)) .gk_abort("Replacing review history needs {.arg confirm = TRUE}.", class = "confirm")
  scope <- rlang::arg_match(scope)
  .gk_check_dir_exists(snapshot_dir)
  .gk_verify_manifest(snapshot_dir, "verify")
  checkpoint <- file.path(snapshot_dir, "review.rds")
  .gk_check_file_exists(checkpoint)
  incoming <- readRDS(checkpoint)
  .gk_review_check(incoming)
  if (!identical(incoming$source_sha256, review$source_sha256) ||
    !identical(incoming$config_sha256, review$config_sha256)) {
    .gk_abort("The replacement review has different source or configuration hashes.", class = "state")
  }
  backup_path <- backup_dir %||% tempfile("gatekeepR-review-backup-")
  gk_save_review(review, backup_path, overwrite = FALSE)
  selected <- switch(scope,
    cuts = "cut_log", structures = "structure_log",
    dispositions = "disposition_log", states = "state_log",
    all = names(review$ledgers)
  )
  out <- .gk_review_clone(review)
  for (nm in selected) out$ledgers[[nm]] <- incoming$ledgers[[nm]]
  attr(out, "backup_path") <- backup_path
  out
}

#' Append an inverse of the most recent review action
#'
#' @param review A [gk_review()] object.
#' @param reviewer Reviewer identifier.
#' @param reason Required reason recorded in the ledger.
#' @return A new `gk_review` object. No existing ledger row is removed.
#' @family review
#' @export
gk_revert_last <- function(review, reviewer, reason) {
  .gk_review_check(review)
  if (isTRUE(review$locked)) .gk_abort("Locked reviews cannot be changed.", class = "locked")
  .gk_check_reviewer(reviewer)
  .gk_check_reason(reason)
  all_rows <- .gk_review_all_rows(review)
  if (!nrow(all_rows)) .gk_abort("There is no review action to revert.", class = "ledger")
  target_meta <- all_rows[which.max(all_rows$order), , drop = FALSE]
  ledger <- target_meta$ledger[[1L]]
  target <- review$ledgers[[ledger]][review$ledgers[[ledger]]$entry_id ==
    target_meta$entry_id[[1L]], , drop = FALSE]
  reverted_id <- target$entry_id[[1L]]
  if (identical(ledger, "cut_log")) {
    row <- target
    row$sequence <- NA_integer_; row$order <- NA_integer_; row$entry_id <- NA_character_; row$time_utc <- NA_character_
    row$reviewer <- reviewer; row$reason <- reason; row$reverts <- reverted_id
    old <- row$new_estimate; row$new_estimate <- row$old_estimate; row$old_estimate <- old
    return(.gk_append_ledger(review, "cut_log", row[, names(.gk_ledger_columns("cut_log")), drop = FALSE]))
  }
  if (identical(ledger, "state_log")) {
    row <- target
    row$sequence <- NA_integer_; row$order <- NA_integer_; row$entry_id <- NA_character_; row$time_utc <- NA_character_
    row$reviewer <- reviewer; row$reason <- reason; row$reverts <- reverted_id
    if (row$action[[1L]] == "ENABLE") row$action <- "DISABLE"
    else if (row$action[[1L]] == "DISABLE") row$action <- "ENABLE"
    else {
      old <- row$new_estimate; row$new_estimate <- row$old_estimate; row$old_estimate <- old
    }
    return(.gk_append_ledger(review, "state_log", row[, names(.gk_ledger_columns("state_log")), drop = FALSE]))
  }
  if (identical(ledger, "disposition_log")) {
    row <- target
    row$sequence <- NA_integer_; row$order <- NA_integer_; row$entry_id <- NA_character_; row$time_utc <- NA_character_
    row$reviewer <- reviewer; row$reason <- reason; row$reverts <- reverted_id
    row$disposition <- "RESTORE"
    return(.gk_append_ledger(review, "disposition_log", row[, names(.gk_ledger_columns("disposition_log")), drop = FALSE]))
  }
  row <- target
  row$sequence <- NA_integer_; row$order <- NA_integer_; row$entry_id <- NA_character_; row$time_utc <- NA_character_
  row$reviewer <- reviewer; row$reason <- reason; row$reverts <- reverted_id
  row$decision <- "Unresolved"
  .gk_append_ledger(review, "structure_log", row[, names(.gk_ledger_columns("structure_log")), drop = FALSE])
}
