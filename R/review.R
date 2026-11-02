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
  rownames(out$ledgers[[name]]) <- NULL
  out
}

.gk_review_check <- function(review) {
  .gk_check_class(review, "gk_review")
  .gk_validate_ledgers(review)
  invisible(review)
}

.gk_review_validate_base <- function(review) {
  if (!identical(gk_config_hash(review$config), review$config_sha256) ||
    !identical(gk_config_hash(review$prepared$config), review$config_sha256) ||
    !identical(review$prepared$config_sha256, review$config_sha256) ||
    !identical(review$prepared$source_sha256, review$source_sha256))
    .gk_abort("The review base source or configuration is inconsistent.", class = "state")
  gk_review(review$classification, review$state_calls, review$structures,
    review$thresholds, review$prepared)
  invisible(TRUE)
}

.gk_validate_ledgers <- function(review) {
  expected <- names(.gk_empty_ledgers())
  if (!is.list(review$ledgers) || !identical(names(review$ledgers), expected))
    .gk_abort("Review must contain the four declared ledgers.", class = "ledger")
  rows <- list()
  for (name in expected) {
    x <- review$ledgers[[name]]
    needed <- names(.gk_ledger_columns(name))
    if (!is.data.frame(x) || !identical(names(x), needed))
      .gk_abort("Review ledger {.val {name}} has an invalid schema.", class = "ledger")
    if (!nrow(x)) next
    for (field in c("sequence", "order")) {
      value <- x[[field]]
      if (!is.numeric(value) || anyNA(value) || any(!is.finite(value)) ||
          any(value < 1 | value != floor(value)))
        .gk_abort("Ledger sequence and order must be positive integers.", class = "ledger")
    }
    if (any(x$sequence != x$order) || is.unsorted(x$order, strictly = TRUE))
      .gk_abort("Each ledger must retain strictly increasing sequence/order.", class = "ledger")
    for (field in c("entry_id", "time_utc", "reviewer", "image_id", "reason")) {
      value <- x[[field]]
      if (!is.character(value) || anyNA(value) || any(!nzchar(trimws(value))))
        .gk_abort("Ledger {.val {field}} must contain nonempty values.", class = "ledger")
    }
    if (!is.character(x$reverts))
      .gk_abort("Ledger revert targets must be entry IDs or NA.", class = "ledger")
    if (any(!x$image_id %in% review$prepared$cells$image_id))
      .gk_abort("Ledger refers to an image absent from the prepared data.", class = "ledger")
    control <- !is.na(x$reverts) & nzchar(x$reverts)
    active <- x[!control, , drop = FALSE]
    if (name %in% c("cut_log", "state_log")) {
      pm <- review$config$panel$markers
      role <- pm$role[match(x$marker, pm$marker)]
      if (anyNA(role) || any(!role %in% if (name == "state_log") "state" else .gk_gating_roles))
        .gk_abort("Ledger marker has an invalid role.", class = "ledger")
      if (name == "cut_log" && any(!is.na(x$parent)))
        .gk_abort("Identity ledger cuts cannot name a parent.", class = "ledger")
      if (name == "state_log") {
        if (anyNA(x$parent) || any(!vapply(seq_len(nrow(x)), function(i)
          x$parent[[i]] %in% review$config$panel$parents[[x$marker[[i]]]], logical(1))) ||
          anyNA(x$action) || any(!x$action %in% c("SET_CUT", "ENABLE", "DISABLE")))
          .gk_abort("State ledger parent or action is invalid.", class = "ledger")
        active <- active[active$action == "SET_CUT", , drop = FALSE]
      }
      if (!is.numeric(active$new_estimate) || any(!is.finite(active$new_estimate)))
        .gk_abort("Active cut estimates must be finite numbers.", class = "ledger")
    } else {
      modes <- if (name == "structure_log") c("STRUCTURE", "BBOX") else c("POINT", "BBOX")
      if (anyNA(x$mode) || any(!x$mode %in% modes))
        .gk_abort("Ledger selection mode is invalid.", class = "ledger")
      for (i in which(x$mode == "BBOX"))
        .gk_bbox(unlist(x[i, c("xmin", "xmax", "ymin", "ymax")], use.names = FALSE))
      if (name == "structure_log") {
        if (anyNA(x$decision) || any(!x$decision %in% .gk_decisions))
          .gk_abort("Structure ledger decision is invalid.", class = "ledger")
        for (i in which(x$mode == "STRUCTURE")) {
          st <- review$structures$structures
          if (is.na(x$structure_id[[i]]) || !any(st$image_id == x$image_id[[i]] &
            st$structure_id == x$structure_id[[i]]))
            .gk_abort("Ledger refers to an absent structure.", class = "ledger")
        }
      } else {
        if (anyNA(x$disposition) || any(!x$disposition %in% c("EXCLUDE", "DELETE", "RESTORE")))
          .gk_abort("Disposition ledger action is invalid.", class = "ledger")
        for (i in which(x$mode == "POINT")) {
          cells <- review$prepared$cells
          if (is.na(x$cell_id[[i]]) || !any(cells$image_id == x$image_id[[i]] &
            cells$cell_id == x$cell_id[[i]]))
            .gk_abort("Ledger refers to an absent cell.", class = "ledger")
        }
      }
    }
    rows[[name]] <- data.frame(order = x$order, entry_id = x$entry_id,
      reverts = x$reverts, ledger = name, stringsAsFactors = FALSE)
  }
  if (!length(rows)) return(invisible(TRUE))
  all <- do.call(rbind, rows)
  if (anyDuplicated(all$order) || anyDuplicated(all$entry_id))
    .gk_abort("Review ledger orders and entry IDs must be globally unique.", class = "ledger")
  undo <- !is.na(all$reverts) & nzchar(all$reverts)
  target <- match(all$reverts[undo], all$entry_id)
  if (anyNA(target) || any(all$order[target] >= all$order[undo]) ||
      any(all$ledger[target] != all$ledger[undo]))
    .gk_abort("An undo must refer to an earlier action in the same ledger.", class = "ledger")
  invisible(TRUE)
}

.gk_validate_state_calls <- function(prepared, state_calls, classification, thresholds) {
  .gk_check_class(state_calls, "gk_state_calls")
  .gk_check_source(prepared, state_calls, "state_calls")
  if (!identical(state_calls$thresholds_sha256, .gk_thresholds_hash(thresholds)) ||
    !identical(state_calls$classification_sha256, .gk_classification_hash(classification)) ||
    !identical(state_calls$score_sha256, classification$score_sha256))
    .gk_abort("State calls do not match the classification, thresholds or score space.", class = "state")
  expected <- list()
  markers <- prepared$config$panel$markers
  for (img in unique(prepared$cells$image_id)) {
    cells <- prepared$cells[prepared$cells$image_id == img, , drop = FALSE]
    for (marker in markers$marker[markers$role == "state"]) {
      for (parent in prepared$config$panel$parents[[marker]]) {
        expected[[length(expected) + 1L]] <- data.frame(image_id = cells$image_id,
          cell_id = cells$cell_id, marker = marker, parent = parent,
          stringsAsFactors = FALSE)
      }
    }
  }
  keys <- c("image_id", "cell_id", "marker", "parent")
  expected <- if (length(expected)) do.call(rbind, expected) else
    data.frame(image_id = character(), cell_id = character(), marker = character(),
      parent = character(), stringsAsFactors = FALSE)
  rownames(expected) <- NULL
  calls <- state_calls$calls
  if (!is.data.frame(calls) || !all(keys %in% names(calls)) ||
    !identical(calls[, keys, drop = FALSE], expected))
    .gk_abort("State calls must contain the complete ordered cell, marker and parent keys.", class = "state")
  for (flag in c("in_parent", "evaluable", "positive", "enabled")) {
    if (!is.logical(calls[[flag]]) || length(calls[[flag]]) != nrow(calls) || anyNA(calls[[flag]]))
      .gk_abort("State call flags must be complete logical values.", class = "state")
  }
  state_thresholds <- state_calls$state_thresholds
  threshold_keys <- c("image_id", "marker", "parent")
  expected_thresholds <- unique(expected[, threshold_keys, drop = FALSE])
  rownames(expected_thresholds) <- NULL
  if (!is.data.frame(state_thresholds) || !all(c(threshold_keys, "estimate", "status") %in% names(state_thresholds)) ||
    !identical(.gk_sha256_object(state_thresholds[, threshold_keys, drop = FALSE]), .gk_sha256_object(expected_thresholds)) ||
    !identical(attr(state_thresholds, "source_sha256"), prepared$source_sha256) ||
    !identical(attr(state_thresholds, "config_sha256"), prepared$config_sha256) ||
    !identical(attr(state_thresholds, "cell_keys"), .gk_cell_keys(prepared$cells)) ||
    !identical(attr(state_thresholds, "score_sha256"), classification$score_sha256) ||
    !is.numeric(state_thresholds$estimate) || anyNA(state_thresholds$status) ||
    any(!state_thresholds$status %in% .gk_status_levels) ||
    any(!is.finite(state_thresholds$estimate[.gk_is_callable_status(state_thresholds$status)])))
    .gk_abort("State thresholds have inconsistent keys, values or provenance.", class = "state")
  score <- .gk_score_matrix(prepared, classification$correction)
  state_markers <- markers$marker[markers$role == "state"]
  available <- .gk_score_available(prepared, state_markers)
  for (i in seq_len(nrow(state_thresholds))) {
    th <- state_thresholds[i, , drop = FALSE]
    take <- calls$image_id == th$image_id & calls$marker == th$marker & calls$parent == th$parent
    idx <- match(.gk_cell_key(calls[take, , drop = FALSE]), .gk_cell_key(prepared$cells))
    marker <- th$marker[[1L]]
    loc <- .gk_state_localization(prepared, marker)
    in_parent <- classification$cells$cell_type[idx] %in% prepared$config$parent_sets[[th$parent[[1L]]]]
    values <- unname(score[idx, marker])
    evaluable <- unname(available[idx, marker]) & loc$evaluable[idx] &
      is.finite(loc$ratio[idx]) & is.finite(values)
    positive <- evaluable & in_parent & loc$ratio[idx] >= loc$min_ratio &
      is.finite(th$estimate[[1L]]) & values >= th$estimate[[1L]] &
      .gk_is_callable_status(th$status[[1L]])
    if (!identical(calls$score[take], values) ||
      !identical(calls$estimate[take], rep(th$estimate[[1L]], length(idx))) ||
      !identical(calls$localization_ratio[take], unname(loc$ratio[idx])) ||
      !identical(calls$in_parent[take], in_parent) ||
      !identical(calls$evaluable[take], unname(evaluable)) ||
      !identical(calls$positive[take], unname(positive)) || any(calls$enabled[take]))
      .gk_abort("Base state calls differ from their scores, thresholds or parent/localization gates.", class = "state")
  }
  invisible(TRUE)
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
  .gk_validate_classification(prepared, classification, thresholds)
  .gk_validate_state_calls(prepared, state_calls, classification, thresholds)
  if (!identical(prepared$source_sha256, structures$source_sha256) ||
    !identical(prepared$config_sha256, structures$config_sha256) ||
    !identical(.gk_cell_keys(structures$cell_structure), .gk_cell_keys(prepared$cells)) ||
    !identical(.gk_classification_hash(structures$classification),
      .gk_classification_hash(classification))) {
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
  if (length(parent) != 1L || (!is.na(parent) && !is.character(parent))) {
    .gk_abort("{.arg parent} must be one parent name or NA.", class = "input")
  }
  .gk_review_marker(review, marker, state = !is.na(parent))
  .gk_check_reviewer(reviewer)
  .gk_check_reason(reason)
  .gk_check_number(estimate)
  pm <- review$config$panel$markers
  role <- pm$role[pm$marker == marker]
  is_state <- identical(role, "state")
  if (is_state && (is.na(parent) || !parent %in% review$config$panel$parents[[marker]])) {
    .gk_abort("State cut requires one configured parent set.", class = "ledger")
  }
  if (!is_state && !is.na(parent)) .gk_abort("Identity cuts cannot name a parent set.", class = "ledger")
  if (is_state) return(gk_set_state(review, image_id, marker, parent,
    action = "SET_CUT", estimate = estimate, reviewer = reviewer, reason = reason))
  source <- review$thresholds
  hit <- .gk_threshold_row(source, image_id, marker, parent)
  old <- if (length(hit)) source$estimate[[hit[[1L]]]] else NA_real_
  old_status <- if (length(hit)) source$status[[hit[[1L]]]] else "NOT_CALLABLE_UNAVAILABLE"
  effective <- .gk_effective_cut(review, image_id, marker)
  if (!is.null(effective)) {
    old <- effective$estimate
    old_status <- "MANUAL"
  }
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
  effective <- .gk_effective_cut(review, image_id, marker, parent, state = TRUE)
  if (!is.null(effective)) old <- effective$estimate
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
  # Undo records are control actions. An active undo cancels its target; an
  # undo of that undo reactivates the original action. Evaluate newest first.
  rows <- .gk_review_all_rows(review)
  skipped <- character()
  if (!nrow(rows)) return(skipped)
  for (i in rev(seq_len(nrow(rows)))) {
    if (rows$entry_id[[i]] %in% skipped) next
    x <- review$ledgers[[rows$ledger[[i]]]]
    target <- x$reverts[match(rows$entry_id[[i]], x$entry_id)]
    if (length(target) && !is.na(target) && nzchar(target))
      skipped <- unique(c(skipped, target))
  }
  skipped
}

.gk_active_ledger <- function(review, name) {
  x <- review$ledgers[[name]]
  control <- !is.na(x$reverts) & nzchar(x$reverts)
  x[!control & !x$entry_id %in% .gk_reverted_entries(review), , drop = FALSE]
}

.gk_effective_cut <- function(review, image_id, marker, parent = NA_character_, state = FALSE) {
  log <- .gk_active_ledger(review, if (state) "state_log" else "cut_log")
  log <- log[log$image_id == image_id & log$marker == marker, , drop = FALSE]
  if (state) log <- log[log$parent == parent & log$action == "SET_CUT", , drop = FALSE]
  else log <- log[is.na(log$parent) & is.na(parent), , drop = FALSE]
  if (!nrow(log)) return(NULL)
  row <- log[which.max(log$order), , drop = FALSE]
  list(estimate = row$new_estimate[[1L]], entry_id = row$entry_id[[1L]])
}

.gk_effective_thresholds <- function(review) {
  out <- review$thresholds
  log <- .gk_active_ledger(review, "cut_log")
  for (i in seq_len(nrow(log))) {
    hit <- .gk_threshold_row(out, log$image_id[[i]], log$marker[[i]], NA_character_)
    if (length(hit) != 1L)
      .gk_abort("A reviewed identity cut must identify exactly one threshold.", class = "ledger")
    out$estimate[hit] <- log$new_estimate[[i]]
    out$status[hit] <- "MANUAL"
    out$method[hit] <- "manual"
    out$rule[hit] <- "manual"
    out$args_json[hit] <- .gk_canonical_json(list(value = log$new_estimate[[i]]))
    out$details[hit] <- paste("Manual threshold set by review action",
      paste0(log$entry_id[[i]], "."))
  }
  out
}

#' Replay all effective review decisions
#'
#' @param review A [gk_review()] object.
#' @return A `gk_replayed` object with effective cells, thresholds and state calls.
#' @family review
#' @export
gk_replay <- function(review) {
  .gk_review_check(review)
  .gk_review_validate_base(review)
  base <- review$classification$cells
  effective_thresholds <- .gk_effective_thresholds(review)
  # Disabled rules are a retained diagnostic, not a repeated warning at every
  # UI replay. Other warnings still propagate to the caller.
  effective_classification <- withCallingHandlers(gk_classify(review$prepared,
    effective_thresholds, review$config, correction = review$classification$correction),
    gatekeepr_warning_disabled_rules = function(w) invokeRestart("muffleWarning"))
  out <- effective_classification$cells
  coords <- review$prepared$cells[match(.gk_cell_key(out), .gk_cell_key(review$prepared$cells)),
    c("x", "y"), drop = FALSE]
  out$x <- coords$x
  out$y <- coords$y
  out$base_cell_type <- base$cell_type
  out$structure_id <- review$structures$cell_structure$structure_id[match(.gk_cell_key(out),
    .gk_cell_key(review$structures$cell_structure))]
  out$structure_decision <- NA_character_
  struct_log <- .gk_active_ledger(review, "structure_log")
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
    take <- !is.na(out$rule_id) & out$rule_id == r$rule_id & !is.na(out$structure_decision) &
      out$structure_decision %in% names(r$decisions)
    out$cell_type[take] <- unname(unlist(r$decisions[out$structure_decision[take]]))
    out$pending_review[take] <- FALSE
  }
  effective_state <- review$state_calls$calls
  state_log <- .gk_active_ledger(review, "state_log")
  effective_state$enabled <- FALSE
  state_cell_index <- match(.gk_cell_key(effective_state), .gk_cell_key(out))
  effective_state$in_parent <- vapply(seq_len(nrow(effective_state)), function(i) {
    labels <- review$config$parent_sets[[effective_state$parent[[i]]]]
    out$cell_type[state_cell_index[[i]]] %in% labels
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
          toggles <- rows[rows$action %in% c("ENABLE", "DISABLE"), , drop = FALSE]
          if (nrow(toggles)) {
            last <- toggles[which.max(toggles$order), , drop = FALSE]
            effective_state$enabled[effective_state$image_id == img &
              effective_state$marker == marker & effective_state$parent == parent] <-
              last$action[[1L]] == "ENABLE"
          }
          cuts <- rows[rows$action == "SET_CUT", , drop = FALSE]
          if (nrow(cuts)) {
            last_cut <- cuts[which.max(cuts$order), , drop = FALSE]
            state_cut[[length(state_cut) + 1L]] <- last_cut
          }
        }
      }
    }
  }
  for (cut in state_cut) {
    take <- effective_state$image_id == cut$image_id[[1L]] &
      effective_state$marker == cut$marker[[1L]] & effective_state$parent == cut$parent[[1L]]
    effective_state$estimate[take] <- cut$new_estimate[[1L]]
    marker <- cut$marker[[1L]]
    loc <- review$config$panel$localization[[marker]]
    min_ratio <- if (is.null(loc)) 0 else loc$min_ratio %||% 0
    effective_state$positive[take] <- effective_state$evaluable[take] &
      effective_state$in_parent[take] & effective_state$localization_ratio[take] >= min_ratio &
      is.finite(effective_state$score[take]) & effective_state$score[take] >= cut$new_estimate[[1L]]
  }
  dispositions <- rep("NONE", nrow(out))
  disp_log <- .gk_active_ledger(review, "disposition_log")
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
    state_cells <- unique(.gk_cell_key(effective_state[take_state, , drop = FALSE]))
    take <- .gk_cell_key(out) %in% state_cells & out$cell_type == rf$from_label & out$analysed
    out$cell_type[take] <- rf$to_label
  }
  structure(list(cells = out, state_calls = effective_state,
    thresholds = effective_thresholds, ledgers = review$ledgers,
    disabled_rules = effective_classification$disabled_rules,
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
#' @details Replacement requires the same analytical base. Partial replacement
#'   must preserve globally unique action orders and valid undo references.
#'   If histories conflict, use [gk_import_cuts()] to append new cuts, or replace
#'   the complete history with `scope = "all"`.
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
  if (isTRUE(review$locked)) .gk_abort("Locked reviews cannot be changed.", class = "locked")
  snapshot_dir <- .gk_review_path(snapshot_dir)
  operation_lock <- .gk_review_operation_lock(snapshot_dir)
  incoming <- tryCatch(.gk_read_review_checkpoint(snapshot_dir),
    finally = filelock::unlock(operation_lock))
  if (!identical(incoming$source_sha256, review$source_sha256) ||
    !identical(incoming$config_sha256, review$config_sha256) ||
    !identical(.gk_classification_hash(incoming$classification),
      .gk_classification_hash(review$classification)) ||
    !identical(incoming$state_calls$calls, review$state_calls$calls) ||
    !identical(incoming$structures$cell_structure, review$structures$cell_structure) ||
    !identical(incoming$structures$structures, review$structures$structures)) {
    .gk_abort("The replacement review has different source, configuration or analytical base.", class = "state")
  }
  selected <- switch(scope,
    cuts = "cut_log", structures = "structure_log",
    dispositions = "disposition_log", states = "state_log",
    all = names(review$ledgers)
  )
  out <- .gk_review_clone(review)
  for (nm in selected) out$ledgers[[nm]] <- incoming$ledgers[[nm]]
  .gk_validate_ledgers(out)
  backup_path <- backup_dir %||% tempfile("gatekeepR-review-backup-")
  gk_save_review(review, backup_path, overwrite = FALSE)
  attr(out, "backup_path") <- backup_path
  out
}

#' Undo the most recent review action without deleting history
#'
#' @param review A [gk_review()] object.
#' @param reviewer Reviewer identifier.
#' @param reason Required reason recorded in the ledger.
#' @details The appended row references the target action. Replay restores the
#'   state before that action, including earlier overlapping selections. Undoing
#'   an undo reactivates its target. No existing ledger row is removed.
#' @return A new `gk_review` object.
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
  row <- target
  row$reviewer <- reviewer
  row$reason <- reason
  row$reverts <- reverted_id
  .gk_append_ledger(review, ledger, row)
}
