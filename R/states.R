# Parent-specific state calls and localisation gates.

.gk_state_score <- function(prepared, classification) {
  if (!is.null(classification$correction) && inherits(classification$correction, "gk_corrected")) {
    classification$correction$matrix
  } else {
    prepared$score
  }
}

.gk_state_reference_labels <- function(config, marker, parent, args) {
  reference <- args$reference %||% "rest"
  if (identical(reference, "rest")) {
    return(NULL)
  }
  config$parent_sets[[reference]]
}

.gk_state_estimate <- function(values, in_parent, cell_type, config, marker,
                               parent, method, args, min_auc) {
  positive <- values[in_parent & is.finite(values)]
  reference_labels <- .gk_state_reference_labels(config, marker, parent, args)
  reference <- if (is.null(reference_labels)) {
    values[!in_parent & is.finite(values)]
  } else {
    values[cell_type %in% reference_labels & !in_parent & is.finite(values)]
  }
  if (identical(method, "manual")) {
    value <- args$value
    if (is.numeric(value) && length(value) == 1L && is.finite(value)) {
      return(list(status = "MANUAL", estimate = as.double(value), crossing = NA_real_,
        auc = NA_real_, n_positive_pool = length(positive),
        n_negative_pool = length(reference), rule = "manual",
        details = "Fixed threshold from configuration."))
    }
  }
  if (length(positive) < 2L || length(reference) < 2L) {
    return(list(status = "NOT_CALLABLE_UNDERPOWERED", estimate = NA_real_,
      crossing = NA_real_, auc = NA_real_, n_positive_pool = length(positive),
      n_negative_pool = length(reference), rule = NA_character_,
      details = "The parent or reference pool is underpowered."))
  }
  auc <- .gk_auc_rank(positive, reference)
  auc <- max(auc, 1 - auc)
  crossing <- .gk_crossing(positive, reference, args$n_grid %||% 2048L)
  if (!is.finite(crossing) || !is.finite(auc) || auc < min_auc ||
    stats::median(positive) <= stats::median(reference)) {
    return(list(status = "NOT_CALLABLE_NO_SEPARATION", estimate = NA_real_,
      crossing = crossing, auc = auc, n_positive_pool = length(positive),
      n_negative_pool = length(reference), rule = "parent_crossing",
      details = "The parent signal is not separated from its reference pool."))
  }
  list(status = "CALLABLE", estimate = crossing, crossing = crossing, auc = auc,
    n_positive_pool = length(positive), n_negative_pool = length(reference),
    rule = "parent_crossing", details = "Separated parent and reference populations.")
}

.gk_state_localization <- function(prepared, marker) {
  loc <- prepared$localization[[marker]]
  if (is.null(loc)) {
    list(ratio = rep(1, nrow(prepared$cells)), evaluable = rep(TRUE, nrow(prepared$cells)),
      min_ratio = 0)
  } else {
    rule <- prepared$config$panel$localization[[marker]]
    list(ratio = loc$ratio, evaluable = loc$evaluable,
      min_ratio = rule$min_ratio %||% 0)
  }
}

#' Call state markers within configured parent sets
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Estimates a separate state-marker threshold for every image and parent set,
#' then returns a long table containing every cell by marker by parent
#' combination. Localisation requirements are evaluated on the raw selected
#' measurements. State calls are disabled for analysis by default and become
#' effective only after a review ledger enables them.
#'
#' @param prepared A [gk_prepare()] result.
#' @param thresholds A [gk_thresholds()] result for identity markers.
#' @param classification A [gk_classify()] result.
#' @param config The configuration used to prepare the data.
#'
#' @return An object of class `gk_state_calls` with long `calls`, per-parent
#' `state_thresholds`, and provenance hashes.
#'
#' @examples
#' prep <- gk_prepare(gk_example_path("example-slide"), gk_example_config(), quiet = TRUE)
#' th <- gk_thresholds(prep, gk_example_config(), seed = 1L)
#' cl <- gk_classify(prep, th, gk_example_config())
#' states <- gk_state_calls(prep, th, cl, gk_example_config())
#' head(states$calls)
#'
#' @family classification
#' @export
gk_state_calls <- function(prepared, thresholds, classification, config) {
  .gk_check_class(prepared, "gk_prepared")
  .gk_check_class(thresholds, "gk_thresholds")
  .gk_check_class(classification, "gk_classification")
  .gk_check_class(config, "gk_config")
  if (!identical(classification$config_sha256, prepared$config_sha256) ||
    !identical(prepared$config_sha256, gk_config_hash(config))) {
    .gk_abort("Inputs do not share the same configuration.", class = "state")
  }
  pm <- config$panel$markers
  states <- pm$marker[pm$role == "state"]
  cells <- prepared$cells
  score <- .gk_state_score(prepared, classification)
  labels <- classification$cells$cell_type
  rows <- list()
  threshold_rows <- list()
  for (img in unique(cells$image_id)) {
    image_idx <- which(cells$image_id == img)
    for (marker in states) {
      parents <- config$panel$parents[[marker]]
      method <- pm$threshold_method[pm$marker == marker][[1L]]
      args <- .gk_method_args(method, config$panel$threshold_args[[marker]], role = "state")
      loc <- .gk_state_localization(prepared, marker)
      parent_calls <- list()
      for (parent in parents) {
        parent_labels <- config$parent_sets[[parent]]
        in_parent <- labels %in% parent_labels
        estimate <- .gk_state_estimate(
          score[image_idx, marker], in_parent[image_idx], labels[image_idx],
          config, marker, parent, method, args,
          config$panel$min_support[[marker]]$min_auc
        )
        if (isTRUE(args$pooled) && length(parents) > 1L) {
          # A pooled estimate is computed once below; this marker/parent row
          # records the same cut for every configured parent.
          pooled_in <- Reduce(`|`, lapply(parents, function(p) labels %in% config$parent_sets[[p]]))
          estimate <- .gk_state_estimate(
            score[image_idx, marker], pooled_in[image_idx], labels[image_idx],
            config, marker, parent, method, args,
            config$panel$min_support[[marker]]$min_auc
          )
        }
        threshold_rows[[length(threshold_rows) + 1L]] <- data.frame(
          image_id = img, marker = marker, parent = parent, role = "state",
          method = method, status = estimate$status, estimate = estimate$estimate,
          crossing = estimate$crossing, negative_q99 = NA_real_, auc = estimate$auc,
          n_positive_pool = estimate$n_positive_pool,
          n_negative_pool = estimate$n_negative_pool,
          positive_populations = NA_character_, negative_populations = NA_character_,
          rule = estimate$rule, args_json = .gk_canonical_json(args),
          details = estimate$details, evidence_ref = NA_character_,
          stringsAsFactors = FALSE
        )
        enabled <- FALSE
        positive <- rep(FALSE, length(image_idx))
        if (is.finite(estimate$estimate)) {
          evaluable <- loc$evaluable[image_idx] & is.finite(score[image_idx, marker])
          positive <- evaluable & in_parent[image_idx] &
            loc$ratio[image_idx] >= loc$min_ratio &
            score[image_idx, marker] >= estimate$estimate
        } else {
          evaluable <- loc$evaluable[image_idx] & is.finite(score[image_idx, marker])
        }
        rows[[length(rows) + 1L]] <- data.frame(
          image_id = img, cell_id = cells$cell_id[image_idx], marker = marker,
          parent = parent, in_parent = in_parent[image_idx], evaluable = evaluable,
          score = score[image_idx, marker], estimate = estimate$estimate,
          localization_ratio = loc$ratio[image_idx], positive = positive,
          enabled = rep(enabled, length(image_idx)), stringsAsFactors = FALSE
        )
      }
    }
  }
  call_out <- do.call(rbind, rows)
  rownames(call_out) <- NULL
  threshold_out <- do.call(rbind, threshold_rows)
  rownames(threshold_out) <- NULL
  attr(threshold_out, "config_sha256") <- prepared$config_sha256
  attr(threshold_out, "source_sha256") <- prepared$source_sha256
  structure(
    list(
      calls = call_out, state_thresholds = structure(threshold_out,
        class = c("gk_thresholds", "data.frame")),
      prepared = prepared, classification = classification,
      config = config, config_sha256 = prepared$config_sha256,
      thresholds_sha256 = .gk_thresholds_hash(thresholds),
      source_sha256 = prepared$source_sha256
    ),
    class = "gk_state_calls"
  )
}

#' @export
print.gk_state_calls <- function(x, ...) {
  cli::cli_text("{.cls gk_state_calls}: {nrow(x$calls)} cell x marker x parent rows")
  cli::cli_bullets(c(
    "*" = "State markers: {.val {unique(x$calls$marker)}}",
    "*" = "Enabled calls: {sum(x$calls$enabled)}",
    "*" = "Positive calls: {sum(x$calls$positive)}"
  ))
  invisible(x)
}

#' @export
gk_callability.gk_state_calls <- function(x, ...) x$state_thresholds
