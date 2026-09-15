# The single hierarchy evaluator used by batch code and the review app.

.gk_thresholds_hash <- function(thresholds) {
  .gk_sha256_object(as.data.frame(thresholds, stringsAsFactors = FALSE))
}

.gk_threshold_row <- function(thresholds, image_id, marker, parent = NA_character_) {
  hit <- thresholds$image_id == image_id & thresholds$marker == marker
  if (is.na(parent)) {
    hit <- hit & is.na(thresholds$parent)
  } else {
    hit <- hit & thresholds$parent == parent
  }
  which(hit)
}

.gk_threshold_lookup <- function(thresholds, image_id, marker,
                                 parent = NA_character_) {
  rows <- .gk_threshold_row(thresholds, image_id, marker, parent)
  if (length(rows) != 1L) return(list(status = "NOT_CALLABLE_UNAVAILABLE", estimate = NA_real_))
  list(status = thresholds$status[[rows]], estimate = thresholds$estimate[[rows]])
}

.gk_rule_disabled <- function(rule, callable) {
  required <- unique(c(rule$all_of, rule$any_of))
  absent_required <- required[!vapply(required, function(m) isTRUE(callable[[m]]), logical(1))]
  absent_excluded <- if (identical(rule$on_uncallable, "disable_rule")) {
    rule$none_of[!vapply(rule$none_of, function(m) isTRUE(callable[[m]]), logical(1))]
  } else character()
  list(
    disabled = length(c(absent_required, absent_excluded)) > 0L,
    markers = unique(c(absent_required, absent_excluded)),
    reason = if (length(absent_required) > 0L) {
      "A required marker is not callable on this image."
    } else if (length(absent_excluded) > 0L) {
      "An excluded marker is not callable and the rule disables on uncertainty."
    } else ""
  )
}

.gk_expr_match <- function(calls, all_of = character(), any_of = character(),
                           none_of = character(), none_na_negative = TRUE) {
  n <- nrow(calls)
  all_ok <- if (length(all_of) == 0L) rep(TRUE, n) else {
    rowSums(calls[, all_of, drop = FALSE] == TRUE, na.rm = TRUE) == length(all_of)
  }
  any_ok <- if (length(any_of) == 0L) rep(TRUE, n) else {
    rowSums(calls[, any_of, drop = FALSE] == TRUE, na.rm = TRUE) > 0L
  }
  none_ok <- if (length(none_of) == 0L) rep(TRUE, n) else {
    x <- calls[, none_of, drop = FALSE]
    if (none_na_negative) x[is.na(x)] <- FALSE
    rowSums(!x) == length(none_of)
  }
  all_ok & any_ok & none_ok
}

.gk_rule_table_for_image <- function(config, image_id, calls, callable) {
  rows <- list()
  matches <- vector("list", length(config$hierarchy$rules))
  for (i in seq_along(config$hierarchy$rules)) {
    rule <- config$hierarchy$rules[[i]]
    disabled <- .gk_rule_disabled(rule, callable)
    matches[[i]] <- if (disabled$disabled) {
      rep(FALSE, nrow(calls))
    } else {
      .gk_expr_match(
        calls, rule$all_of, rule$any_of, rule$none_of,
        none_na_negative = identical(rule$on_uncallable, "treat_as_negative")
      )
    }
    if (disabled$disabled) {
      rows[[length(rows) + 1L]] <- data.frame(
        image_id = image_id, rule_id = rule$rule_id, label = rule$label,
        reason = disabled$reason, markers = paste(disabled$markers, collapse = ","),
        stringsAsFactors = FALSE
      )
    }
  }
  list(matches = matches, disabled = if (length(rows)) do.call(rbind, rows) else NULL)
}

#' Classify cells with the configured ordered hierarchy
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Evaluates flags and ordered hierarchy rules against per-image thresholds.
#' This is the only phenotype evaluator in gatekeepR: the review application
#' and batch code both call it. A rule that depends on a non-callable required
#' marker is disabled and recorded; no missing marker is silently treated as
#' positive. Structure-review rules receive their configured pending label
#' until a later review decision is replayed.
#'
#' @param prepared A [gk_prepare()] result.
#' @param thresholds A [gk_thresholds()] result.
#' @param config The configuration used to prepare the data.
#' @param correction `NULL` or a [gk_correct()] result.
#'
#' @return An object of class `gk_classification` with `cells`, `calls`,
#'   `disabled_rules`, the configuration and threshold hashes, and the source
#'   hashes needed for review and export.
#'
#' @examples
#' prep <- gk_prepare(gk_example_path("example-slide"), gk_example_config(), quiet = TRUE)
#' th <- gk_thresholds(prep, gk_example_config(), seed = 1L)
#' cl <- gk_classify(prep, th, gk_example_config())
#' summary(cl)
#'
#' @family classification
#' @export
gk_classify <- function(prepared, thresholds, config, correction = NULL) {
  .gk_check_class(prepared, "gk_prepared")
  .gk_check_class(thresholds, "gk_thresholds")
  .gk_check_class(config, "gk_config")
  if (!identical(prepared$config_sha256, gk_config_hash(config))) {
    .gk_abort("{.arg config} does not match the configuration used for preparation.", class = "state")
  }
  if (!identical(attr(thresholds, "config_sha256"), prepared$config_sha256)) {
    .gk_abort("{.arg thresholds} does not match the prepared configuration.", class = "state")
  }
  score <- if (is.null(correction)) prepared$score else {
    .gk_check_class(correction, "gk_corrected")
    if (!identical(correction$source_sha256, prepared$source_sha256) ||
      !identical(correction$config_sha256, prepared$config_sha256)) {
      .gk_abort("{.arg correction} does not match the prepared data.", class = "state")
    }
    correction$matrix
  }
  pm <- config$panel$markers
  gating <- pm$marker[pm$role %in% .gk_gating_roles]
  cells <- prepared$cells
  calls <- matrix(NA, nrow(cells), length(gating),
    dimnames = list(cells$cell_id, gating)
  )
  images <- unique(cells$image_id)
  callable_by_image <- list()
  disabled <- list()
  for (img in images) {
    idx <- which(cells$image_id == img)
    callable <- stats::setNames(rep(FALSE, length(gating)), gating)
    for (mk in gating) {
      hit <- .gk_threshold_lookup(thresholds, img, mk)
      callable[[mk]] <- .gk_is_callable_status(hit$status) && is.finite(hit$estimate)
      if (callable[[mk]]) calls[idx, mk] <- is.finite(score[idx, mk]) & score[idx, mk] >= hit$estimate
    }
    callable_by_image[[img]] <- callable
    evaluated <- .gk_rule_table_for_image(config, img, calls[idx, , drop = FALSE], callable)
    if (!is.null(evaluated$disabled)) disabled[[length(disabled) + 1L]] <- evaluated$disabled
  }
  disabled_rules <- if (length(disabled)) {
    out <- do.call(rbind, disabled)
    rownames(out) <- NULL
    out
  } else {
    data.frame(image_id = character(), rule_id = character(), label = character(),
      reason = character(), markers = character(), stringsAsFactors = FALSE)
  }
  flag_names <- names(config$hierarchy$flags)
  flag_values <- stats::setNames(vector("list", length(flag_names)), flag_names)
  for (nm in flag_names) flag_values[[nm]] <- logical(nrow(cells))
  cell_type <- rep(config$hierarchy$undefined_label, nrow(cells))
  rule_id <- rep(NA_character_, nrow(cells))
  pending <- rep(FALSE, nrow(cells))
  excluded <- rep(FALSE, nrow(cells))
  for (img in images) {
    idx <- which(cells$image_id == img)
    image_calls <- calls[idx, , drop = FALSE]
    flag_hit <- stats::setNames(rep(FALSE, length(idx)), seq_along(idx))
    flag_exclude <- rep(FALSE, length(idx))
    flag_unresolved <- rep(FALSE, length(idx))
    for (nm in flag_names) {
      flag <- config$hierarchy$flags[[nm]]
      value <- .gk_expr_match(image_calls, flag$all_of, flag$any_of, flag$none_of)
      flag_values[[nm]][idx] <- value
      policy <- config$hierarchy$flag_policy[[nm]]
      flag_hit <- flag_hit | value
      if (identical(policy, "exclude")) flag_exclude <- flag_exclude | value
      if (identical(policy, "unresolved")) flag_unresolved <- flag_unresolved | value
    }
    evaluated <- .gk_rule_table_for_image(config, img, image_calls, callable_by_image[[img]])
    selected <- rep(NA_integer_, length(idx))
    for (i in seq_along(evaluated$matches)) {
      take <- is.na(selected) & evaluated$matches[[i]] & !flag_exclude & !flag_unresolved
      selected[take] <- i
    }
    for (k in seq_along(idx)) {
      i <- idx[[k]]
      if (flag_exclude[[k]]) {
        cell_type[[i]] <- config$hierarchy$excluded_label
        excluded[[i]] <- TRUE
      } else if (flag_unresolved[[k]]) {
        cell_type[[i]] <- config$hierarchy$unresolved_label
      } else if (is.finite(selected[[k]])) {
        rule <- config$hierarchy$rules[[selected[[k]]]]
        rule_id[[i]] <- rule$rule_id
        if (!is.null(rule$review)) {
          cell_type[[i]] <- rule$pending_label
          pending[[i]] <- TRUE
        } else {
          cell_type[[i]] <- rule$label
        }
      }
    }
  }
  if (nrow(disabled_rules) > 0L) {
    .gk_warn(
      "{nrow(disabled_rules)} hierarchy rule{?s} disabled because required markers are not callable.",
      class = "disabled_rules"
    )
  }
  cell_out <- data.frame(
    image_id = cells$image_id, cell_id = cells$cell_id, cell_type = cell_type,
    rule_id = rule_id, pending_review = pending, stringsAsFactors = FALSE
  )
  for (nm in flag_names) cell_out[[nm]] <- flag_values[[nm]]
  cell_out$excluded <- excluded
  structure(
    list(
      cells = cell_out, calls = calls, disabled_rules = disabled_rules,
      config = config, config_sha256 = prepared$config_sha256,
      thresholds_sha256 = .gk_thresholds_hash(thresholds),
      source_sha256 = prepared$source_sha256,
      source_manifest_sha256 = prepared$source_manifest_sha256,
      thresholds = thresholds, correction = correction,
      created_utc = .gk_utc_now()
    ),
    class = "gk_classification"
  )
}

#' @export
print.gk_classification <- function(x, ...) {
  tab <- table(x$cells$cell_type, useNA = "ifany")
  cli::cli_text("{.cls gk_classification}: {nrow(x$cells)} cells")
  cli::cli_bullets(c(
    "*" = "Cell types: {.val {paste(names(tab), as.integer(tab), sep = ' = ', collapse = '; ')}}",
    "*" = "Pending structure review: {sum(x$cells$pending_review)}",
    "*" = "Disabled rules: {nrow(x$disabled_rules)}"
  ))
  invisible(x)
}

#' @export
summary.gk_classification <- function(object, ...) {
  out <- as.data.frame(table(object$cells$image_id, object$cells$cell_type),
    stringsAsFactors = FALSE
  )
  names(out) <- c("image_id", "cell_type", "n")
  totals <- stats::aggregate(n ~ image_id, out, sum)
  names(totals)[[2L]] <- "total"
  out <- merge(out, totals, by = "image_id", sort = FALSE)
  out$proportion <- out$n / out$total
  out[order(out$image_id, out$cell_type), c("image_id", "cell_type", "n", "proportion")]
}

#' @export
gk_callability.gk_thresholds <- function(x, ...) x

#' @export
gk_callability.gk_classification <- function(x, ...) x$thresholds
