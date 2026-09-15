# Callability: can a marker be called on an image at all?
#
# Stage 1 (gk_prepare): support checks on the raw selected signal, before any
# correction, so an absent channel can never acquire variance (audit F1).
# Stage 2 (gk_thresholds / gk_state_calls): the threshold method itself may
# find no population, no separation or too few cells in a pool.

.gk_status_levels <- c(
  "CALLABLE", "MANUAL", "PENDING_THRESHOLD", "NOT_GATED",
  "NOT_CALLABLE_ABSENT", "NOT_CALLABLE_UNAVAILABLE", "NOT_CALLABLE_NO_POPULATION",
  "NOT_CALLABLE_UNDERPOWERED", "NOT_CALLABLE_NO_SEPARATION"
)

.gk_is_callable_status <- function(status) {
  status %in% c("CALLABLE", "MANUAL")
}

.gk_support_callability <- function(prepared) {
  cells <- prepared$cells
  pm <- prepared$config$panel$markers
  images <- unique(cells$image_id)
  rows <- list()
  for (img in images) {
    idx <- which(cells$image_id == img)
    for (j in seq_len(nrow(pm))) {
      mk <- pm$marker[[j]]
      ms <- prepared$config$panel$min_support[[mk]]
      raw <- prepared$signal_raw[idx, j]
      src <- prepared$source[idx, j]
      rows[[length(rows) + 1L]] <- .gk_marker_support(
        img, mk, pm$role[[j]], raw, src, ms
      )
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.gk_marker_support <- function(image_id, marker, role, raw, source, min_support) {
  n <- length(raw)
  available <- source > 0L & is.finite(raw)
  v <- raw[available]
  n_avail <- length(v)
  frac_unavail <- if (n > 0L) 1 - n_avail / n else 1
  sd_v <- if (n_avail > 1L) stats::sd(v) else NA_real_
  mad_v <- if (n_avail > 0L) stats::mad(v, constant = 1) else NA_real_
  frac_mode <- NA_real_
  if (n_avail > 0L && isTRUE(mad_v == 0)) {
    frac_mode <- max(tabulate(match(v, unique(v)))) / n_avail
  }
  q <- if (n_avail > 0L) {
    stats::quantile(v, c(0.01, 0.5, 0.99), names = FALSE, type = 7)
  } else {
    rep(NA_real_, 3L)
  }
  if (frac_unavail > min_support$max_unavailable) {
    support <- "mostly_unavailable"
    status <- "NOT_CALLABLE_UNAVAILABLE"
    details <- sprintf(
      "%.1f%% of cells have no usable signal (limit %.1f%%).",
      100 * frac_unavail, 100 * min_support$max_unavailable
    )
  } else if (n_avail < 2L || isTRUE(sd_v == 0) || is.na(sd_v)) {
    support <- "constant"
    status <- "NOT_CALLABLE_ABSENT"
    details <- "Signal is constant across cells."
  } else if (isTRUE(mad_v == 0) &&
    isTRUE(frac_mode >= min_support$near_constant_mode_fraction)) {
    support <- "near_constant"
    status <- "NOT_CALLABLE_ABSENT"
    details <- sprintf("%.1f%% of cells share one value.", 100 * frac_mode)
  } else if (n_avail < min_support$min_cells) {
    support <- "few_cells"
    status <- "NOT_CALLABLE_UNDERPOWERED"
    details <- sprintf(
      "Only %d cells with signal (minimum %d).", n_avail, min_support$min_cells
    )
  } else {
    support <- "ok"
    status <- if (identical(role, "context")) "NOT_GATED" else "PENDING_THRESHOLD"
    details <- if (identical(role, "context")) {
      "Context marker: displayed, never used in rules."
    } else {
      "Signal supports threshold estimation."
    }
  }
  data.frame(
    image_id = image_id, marker = marker, role = role, status = status,
    support = support, details = details, n_cells = n, n_available = n_avail,
    fraction_unavailable = frac_unavail, sd = sd_v, mad = mad_v,
    fraction_mode = frac_mode, q01 = q[[1L]], q50 = q[[2L]], q99 = q[[3L]],
    stringsAsFactors = FALSE
  )
}

#' Callability of markers per image
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reports, for every image and marker, whether the marker can be called and
#' why not. Checks on the raw selected signal run in [gk_prepare()] before any
#' correction or threshold; threshold estimation adds its own outcomes.
#'
#' | Status | Meaning |
#' |---|---|
#' | `NOT_CALLABLE_ABSENT` | constant or near-constant signal |
#' | `NOT_CALLABLE_UNAVAILABLE` | too many cells without usable signal |
#' | `NOT_CALLABLE_UNDERPOWERED` | too few cells, or too few in a pool |
#' | `NOT_CALLABLE_NO_POPULATION` | the method finds no positive population |
#' | `NOT_CALLABLE_NO_SEPARATION` | positive and negative are not separated |
#' | `PENDING_THRESHOLD` | supported; threshold not yet estimated |
#' | `NOT_GATED` | context marker with usable signal |
#' | `CALLABLE` | finite threshold, all checks passed |
#' | `MANUAL` | cut set by a reviewer or the configuration |
#'
#' A marker that is not callable never produces positive calls, and rules
#' requiring it are disabled and listed.
#'
#' @param x A `gk_prepared` object, or a later result carrying callability
#'   (thresholds, classification, review).
#' @param ... Unused.
#'
#' @return A data frame with `image_id`, `marker`, `role`, `status`,
#'   `details` and support statistics (`n_cells`, `n_available`,
#'   `fraction_unavailable`, `sd`, `mad`, `fraction_mode`, `q01`, `q50`,
#'   `q99`).
#'
#' @examples
#' prep <- gk_prepare(gk_example_path("example-slide"), gk_example_config(), quiet = TRUE)
#' cb <- gk_callability(prep)
#' cb[cb$status != "PENDING_THRESHOLD", c("image_id", "marker", "status", "details")]
#'
#' @family preparation
#' @export
gk_callability <- function(x, ...) {
  UseMethod("gk_callability")
}

#' @export
gk_callability.default <- function(x, ...) {
  .gk_abort(
    c(
      "Cannot report callability for {.obj_type_friendly {x}}.",
      "i" = "Use the result of {.fn gk_prepare}, {.fn gk_thresholds} or {.fn gk_classify}."
    ),
    class = "input"
  )
}

#' @export
gk_callability.gk_prepared <- function(x, ...) {
  x$callability
}
