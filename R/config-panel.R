# Marker panel: roles, transforms, threshold methods, parents, localisation
# and callability rules per marker.

.gk_roles <- c("identity", "state", "context", "conditional_identity")
.gk_gating_roles <- c("identity", "conditional_identity")
.gk_transforms <- c("asinh", "log1p", "none")

#' Callability rules for a marker
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Sets the checks that decide whether a marker can be called on an image
#' before and after threshold estimation (see [gk_callability()]).
#'
#' @param min_cells Minimum number of available cells, and minimum cells per
#'   positive and negative pool.
#' @param max_unavailable Largest fraction of cells whose signal is
#'   unavailable (missing or below the policy's `min_value`) before the marker
#'   is `NOT_CALLABLE_UNAVAILABLE`.
#' @param min_auc Minimum AUC between positive and negative pools for the
#'   crossing methods. The AUC describes internally selected pools and is not
#'   a validated accuracy.
#' @param near_constant_mode_fraction A marker whose median absolute deviation
#'   is zero and whose most frequent value covers at least this fraction of
#'   available cells is `NOT_CALLABLE_ABSENT`.
#'
#' @return A list of class `gk_min_support`.
#'
#' @examples
#' gk_min_support(min_auc = 0.6)
#'
#' @family configuration
#' @export
gk_min_support <- function(min_cells = 20L, max_unavailable = 0.2, min_auc = 0.65,
                           near_constant_mode_fraction = 0.99) {
  .gk_check_count(min_cells, min = 1L)
  .gk_check_number(max_unavailable, min = 0, max = 1)
  .gk_check_number(min_auc, min = 0, max = 1)
  .gk_check_number(near_constant_mode_fraction, min = 0, max = 1)
  structure(
    list(
      min_cells = as.integer(min_cells),
      max_unavailable = as.double(max_unavailable),
      min_auc = as.double(min_auc),
      near_constant_mode_fraction = as.double(near_constant_mode_fraction)
    ),
    class = "gk_min_support"
  )
}

#' @export
print.gk_min_support <- function(x, ...) {
  cli::cli_text(
    "{.cls gk_min_support}: min_cells = {x$min_cells}, ",
    "max_unavailable = {x$max_unavailable}, min_auc = {x$min_auc}, ",
    "near_constant_mode_fraction = {x$near_constant_mode_fraction}"
  )
  invisible(x)
}

.gk_as_min_support <- function(x, call = rlang::caller_env()) {
  if (inherits(x, "gk_min_support")) {
    return(x)
  }
  if (!is.list(x) || is.null(names(x)) ||
    !all(names(x) %in% names(formals(gk_min_support)))) {
    .gk_abort(
      c(
        "{.field min_support} must be built with {.fn gk_min_support}.",
        "x" = "Unknown field{?s}: {.val {setdiff(names(x), names(formals(gk_min_support)))}}."
      ),
      class = "config", call = call
    )
  }
  tryCatch(
    do.call(gk_min_support, x),
    gatekeepr_error_input = function(e) {
      .gk_abort(c("Invalid {.field min_support}.", "x" = conditionMessage(e)),
        class = "config", call = call
      )
    }
  )
}

#' Declare a marker panel
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A panel lists the markers used for gating, their role and how their signal
#' is transformed and thresholded. Arguments are vectorised over `marker`;
#' scalar arguments are recycled.
#'
#' Roles:
#' * `identity`: used in hierarchy rules.
#' * `conditional_identity`: used in rules only on images where it is
#'   callable; when it is not callable, rules requiring it are disabled and it
#'   is treated as negative where rules exclude it.
#' * `state`: called within parent cell types (see [gk_state_calls()]).
#' * `context`: measured and displayed, never used in rules.
#'
#' @param marker Character vector of unique marker names; each must appear
#'   in the signal policy of the configuration.
#' @param role Role per marker (see above).
#' @param transform `"asinh"` (`asinh(x / cofactor)`), `"log1p"` or `"none"`.
#' @param cofactor Positive cofactor for `asinh`.
#' @param threshold_method Method per marker, see [gk_threshold_methods()].
#' @param threshold_args Method arguments: either one list used for every
#'   marker, or a list named by marker whose elements are lists.
#' @param parents State markers only: the parent sets (names from
#'   `parent_sets` in [gk_config()]) within which the marker is estimated and
#'   called. Either a character vector used for every state marker, or a list
#'   named by marker.
#' @param localization `NULL`, or a list named by marker whose elements are
#'   lists with `numerator` and `denominator` compartments, `min_ratio` and
#'   optionally `statistic` (default `"mean"`), e.g.
#'   `list(FOXP3 = list(numerator = "nucleus", denominator = "cytoplasm",
#'   min_ratio = 1.5))`.
#' @param optional Logical per marker. A non-callable optional marker only
#'   disables its own rules; a non-callable required marker additionally
#'   raises a `gatekeepr_warning_uncallable` warning. Neither blocks an image.
#' @param min_support A [gk_min_support()] object used for every marker, or a
#'   list of them named by marker.
#'
#' @return An object of class `gk_panel`: a list with `markers` (a data frame
#'   with `marker`, `role`, `transform`, `cofactor`, `threshold_method`,
#'   `optional`) and per-marker named lists `threshold_args`, `parents`,
#'   `localization` and `min_support`.
#'
#' @examples
#' gk_panel(
#'   marker = c("CD45", "CD3e", "FOXP3"),
#'   role = c("identity", "identity", "state"),
#'   threshold_method = c("mixture", "mixture", "parent_crossing"),
#'   parents = list(FOXP3 = "T cells"),
#'   localization = list(
#'     FOXP3 = list(numerator = "nucleus", denominator = "cytoplasm", min_ratio = 1.5)
#'   )
#' )
#'
#' @family configuration
#' @export
gk_panel <- function(marker, role, transform = "asinh", cofactor = 5,
                     threshold_method = "mixture", threshold_args = list(),
                     parents = list(), localization = NULL, optional = FALSE,
                     min_support = gk_min_support()) {
  call <- rlang::current_env()
  .gk_check_character(marker, min_length = 1L, unique = TRUE)
  n <- length(marker)
  recycle <- function(x, arg) {
    if (length(x) == 1L) {
      return(rep(x, n))
    }
    if (length(x) != n) {
      .gk_abort(
        "{.arg {arg}} must have length 1 or {n} (the number of markers).",
        class = "config", call = call
      )
    }
    x
  }
  role <- recycle(role, "role")
  transform <- recycle(transform, "transform")
  cofactor <- recycle(cofactor, "cofactor")
  threshold_method <- recycle(threshold_method, "threshold_method")
  optional <- recycle(optional, "optional")

  markers <- data.frame(
    marker = as.character(marker),
    role = as.character(role),
    transform = as.character(transform),
    cofactor = as.double(cofactor),
    threshold_method = as.character(threshold_method),
    optional = as.logical(optional),
    stringsAsFactors = FALSE
  )
  panel <- structure(
    list(
      markers = markers,
      threshold_args = .gk_panel_args(threshold_args, marker, call = call),
      parents = .gk_panel_parents(parents, marker, role, call = call),
      localization = .gk_panel_localization(localization, marker, call = call),
      min_support = .gk_per_marker_min_support(min_support, marker, call = call)
    ),
    class = "gk_panel"
  )
  .gk_validate_panel(panel, call = call)
}

.gk_named_by <- function(x, markers) {
  is.list(x) && length(x) > 0L && !is.null(names(x)) &&
    all(nzchar(names(x))) && all(names(x) %in% markers)
}

# threshold_args: a list named by marker (elements are lists), or one list
# of arguments shared by every marker.
.gk_panel_args <- function(x, markers, call) {
  out <- stats::setNames(rep(list(list()), length(markers)), markers)
  if (!is.list(x)) {
    .gk_abort("{.arg threshold_args} must be a list.", class = "config", call = call)
  }
  if (length(x) == 0L) {
    return(out)
  }
  if (.gk_named_by(x, markers) && all(vapply(x, is.list, logical(1)))) {
    for (nm in names(x)) {
      out[[nm]] <- x[[nm]]
    }
    return(out)
  }
  if (is.null(names(x)) || any(!nzchar(names(x)))) {
    .gk_abort(
      "{.arg threshold_args} must be a named list of arguments or a list named by marker.",
      class = "config", call = call
    )
  }
  for (nm in markers) {
    out[[nm]] <- x
  }
  out
}

# parents: a character vector shared by every state marker, or a list named
# by state marker.
.gk_panel_parents <- function(x, markers, role, call) {
  state <- markers[role == "state"]
  out <- stats::setNames(rep(list(character()), length(state)), state)
  if (length(x) == 0L) {
    return(out)
  }
  if (is.character(x)) {
    for (nm in state) {
      out[[nm]] <- x
    }
    return(out)
  }
  if (is.list(x) && !is.null(names(x)) && all(vapply(x, is.character, logical(1)))) {
    not_state <- setdiff(names(x), state)
    if (length(not_state) > 0L) {
      .gk_abort(
        "{.arg parents} names {.val {not_state}}, which {?is not a state marker/are not state markers}.",
        class = "config", call = call
      )
    }
    for (nm in names(x)) {
      out[[nm]] <- x[[nm]]
    }
    return(out)
  }
  .gk_abort(
    "{.arg parents} must be a character vector or a list of them named by state marker.",
    class = "config", call = call
  )
}

.gk_panel_localization <- function(x, markers, call) {
  out <- stats::setNames(rep(list(NULL), length(markers)), markers)
  if (length(x) == 0L) {
    return(out)
  }
  if (!.gk_named_by(x, markers) || !all(vapply(x, is.list, logical(1)))) {
    .gk_abort(
      "{.arg localization} must be a list of rules named by panel marker.",
      class = "config", call = call
    )
  }
  for (nm in names(x)) {
    out[nm] <- list(x[[nm]])
  }
  out
}

.gk_per_marker_min_support <- function(x, markers, call) {
  if (inherits(x, "gk_min_support")) {
    return(stats::setNames(rep(list(x), length(markers)), markers))
  }
  out <- stats::setNames(rep(list(gk_min_support()), length(markers)), markers)
  if (!is.list(x) || is.null(names(x)) || !all(names(x) %in% markers)) {
    .gk_abort(
      "{.arg min_support} must be a {.fn gk_min_support} object or a list of them named by marker.",
      class = "config", call = call
    )
  }
  for (nm in names(x)) {
    out[[nm]] <- .gk_as_min_support(x[[nm]], call = call)
  }
  out
}

.gk_validate_panel <- function(panel, call = rlang::caller_env()) {
  m <- panel$markers
  bad <- !m$role %in% .gk_roles
  if (any(bad)) {
    .gk_abort(
      c(
        "Unknown role for marker{?s} {.val {m$marker[bad]}}.",
        "i" = "Roles are {.val {(.gk_roles)}}."
      ),
      class = "config", call = call
    )
  }
  bad <- !m$transform %in% .gk_transforms
  if (any(bad)) {
    .gk_abort(
      c(
        "Unknown transform for marker{?s} {.val {m$marker[bad]}}.",
        "i" = "Transforms are {.val {(.gk_transforms)}}."
      ),
      class = "config", call = call
    )
  }
  bad <- m$transform == "asinh" & (!is.finite(m$cofactor) | m$cofactor <= 0)
  if (any(bad)) {
    .gk_abort("Marker{?s} {.val {m$marker[bad]}} need{?s/} a positive {.field cofactor}.",
      class = "config", call = call
    )
  }
  if (anyNA(m$optional)) {
    .gk_abort("{.field optional} must be TRUE or FALSE for every marker.",
      class = "config", call = call
    )
  }
  reg <- .gk_method_registry()
  for (i in seq_len(nrow(m))) {
    mk <- m$marker[[i]]
    method <- m$threshold_method[[i]]
    role <- m$role[[i]]
    if (identical(role, "context")) {
      next
    }
    if (is.na(method) || !method %in% names(reg)) {
      .gk_abort(
        c(
          "Marker {.val {mk}} uses unknown threshold method {.val {method}}.",
          "i" = "See {.fn gk_threshold_methods}."
        ),
        class = "config", call = call
      )
    }
    if (!role %in% reg[[method]]$roles) {
      .gk_abort(
        "Threshold method {.val {method}} is not allowed for {.val {role}} marker {.val {mk}}.",
        class = "config", call = call
      )
    }
    args <- panel$threshold_args[[mk]]
    allowed <- names(reg[[method]]$args)
    if (identical(role, "state")) {
      allowed <- c(allowed, names(.gk_state_common_args))
    }
    unknown <- setdiff(names(args), allowed)
    if (length(unknown) > 0L) {
      .gk_abort(
        c(
          "Marker {.val {mk}}: unknown argument{?s} {.val {unknown}} for method {.val {method}}.",
          "i" = "Allowed: {.val {allowed}}."
        ),
        class = "config", call = call
      )
    }
    req <- reg[[method]]$required
    miss <- req[!req %in% names(args)]
    if (length(miss) > 0L) {
      .gk_abort(
        "Marker {.val {mk}}: method {.val {method}} requires {.field {miss}}.",
        class = "config", call = call
      )
    }
    if (identical(method, "manual") && !(is.numeric(args$value) &&
      length(args$value) == 1L && is.finite(args$value))) {
      .gk_abort("Marker {.val {mk}}: manual {.field value} must be one finite number.",
        class = "config", call = call
      )
    }
    if (identical(method, "population_crossing") && !is.null(args$rule) &&
      !args$rule %in% c("crossing", "max_crossing_q99")) {
      .gk_abort(
        "Marker {.val {mk}}: {.field rule} must be {.val crossing} or {.val max_crossing_q99}.",
        class = "config", call = call
      )
    }
  }
  state <- m$marker[m$role == "state"]
  no_parent <- state[vapply(state, function(s) length(panel$parents[[s]]) == 0L, logical(1))]
  if (length(no_parent) > 0L) {
    .gk_abort(
      c(
        "State marker{?s} {.val {no_parent}} ha{?s/ve} no parent sets.",
        "i" = "Give {.arg parents}, e.g. {.code parents = list({no_parent[[1]]} = \"T cells\")}."
      ),
      class = "config", call = call
    )
  }
  for (mk in names(panel$localization)) {
    loc <- panel$localization[[mk]]
    if (is.null(loc)) {
      next
    }
    need <- c("numerator", "denominator", "min_ratio")
    ok <- all(need %in% names(loc)) &&
      all(names(loc) %in% c(need, "statistic")) &&
      isTRUE(loc$numerator %in% .gk_compartments) &&
      isTRUE(loc$denominator %in% .gk_compartments) &&
      !identical(loc$numerator, loc$denominator) &&
      is.numeric(loc$min_ratio) && length(loc$min_ratio) == 1L &&
      is.finite(loc$min_ratio) && loc$min_ratio > 0
    if (!ok) {
      .gk_abort(
        c(
          "Marker {.val {mk}} has an invalid localisation rule.",
          "i" = "Use {.code list(numerator = \"nucleus\", denominator = \"cytoplasm\", min_ratio = 1.5)}."
        ),
        class = "config", call = call
      )
    }
    panel$localization[[mk]]$statistic <- loc$statistic %||% "mean"
  }
  panel
}

#' @export
print.gk_panel <- function(x, ...) {
  m <- x$markers
  cli::cli_text("{.cls gk_panel} with {nrow(m)} marker{?s}")
  shown <- m
  shown$parents <- vapply(m$marker, function(mk) {
    paste(x$parents[[mk]] %||% character(), collapse = "; ")
  }, character(1))
  shown$localization <- vapply(m$marker, function(mk) {
    loc <- x$localization[[mk]]
    if (is.null(loc)) "" else sprintf("%s/%s >= %s", loc$numerator, loc$denominator, loc$min_ratio)
  }, character(1))
  print(shown, row.names = FALSE)
  invisible(x)
}

#' @export
c.gk_panel <- function(...) {
  panels <- list(...)
  ok <- vapply(panels, inherits, logical(1), "gk_panel")
  if (!all(ok)) {
    .gk_abort("Only {.cls gk_panel} objects can be combined.", class = "config")
  }
  out <- structure(
    list(
      markers = do.call(rbind, lapply(panels, `[[`, "markers")),
      threshold_args = do.call(c, lapply(panels, `[[`, "threshold_args")),
      parents = do.call(c, lapply(panels, `[[`, "parents")),
      localization = do.call(c, lapply(panels, `[[`, "localization")),
      min_support = do.call(c, lapply(panels, `[[`, "min_support"))
    ),
    class = "gk_panel"
  )
  if (anyDuplicated(out$markers$marker)) {
    dup <- unique(out$markers$marker[duplicated(out$markers$marker)])
    .gk_abort("Combined panels repeat marker{?s} {.val {dup}}.", class = "config")
  }
  rownames(out$markers) <- NULL
  .gk_validate_panel(out)
}
