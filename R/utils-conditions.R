# Condition helpers. Every error carries the parent class `gatekeepr_error`
# plus one specific class from the documented table (see ?gatekeepR-conditions),
# so callers can catch a precise failure. Messages use cli bullets.

.gk_error_classes <- c(
  "config", "structure", "ledger", "confirm", "locked", "verify",
  "input", "lockfile", "dependency", "state"
)

.gk_abort <- function(message, class, ..., call = rlang::caller_env(),
                      .envir = parent.frame()) {
  class <- match.arg(class, .gk_error_classes)
  cli::cli_abort(
    message,
    class = c(paste0("gatekeepr_error_", class), "gatekeepr_error"),
    ...,
    call = call,
    .envir = .envir
  )
}

.gk_warn <- function(message, class, ..., .envir = parent.frame()) {
  cli::cli_warn(
    message,
    class = c(paste0("gatekeepr_warning_", class), "gatekeepr_warning"),
    ...,
    .envir = .envir
  )
}

# Abort when a Suggests package is missing. `pkgs` may list several packages;
# all missing ones are reported in one message.
.gk_require <- function(pkgs, what, call = rlang::caller_env()) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0L) {
    .gk_abort(
      c(
        "{what} needs {cli::qty(length(missing))}package{?s} {.pkg {missing}}.",
        "i" = "Install with {.code install.packages({deparse(missing)})}."
      ),
      class = "dependency",
      call = call
    )
  }
  invisible(TRUE)
}

#' Conditions signalled by gatekeepR
#'
#' @description
#' All errors raised by gatekeepR inherit from `gatekeepr_error` and carry one
#' specific class, so that code can react to a particular failure with
#' [tryCatch()] or [rlang::try_fetch()]. Warnings inherit from
#' `gatekeepr_warning`.
#'
#' | Class | When |
#' |---|---|
#' | `gatekeepr_error_config` | invalid panel, hierarchy, policy or configuration |
#' | `gatekeepr_error_structure` | required markers or features missing from the cell table |
#' | `gatekeepr_error_input` | an argument has the wrong type or value |
#' | `gatekeepr_error_ledger` | an invalid ledger row or target |
#' | `gatekeepr_error_confirm` | a destructive operation without `confirm = TRUE` |
#' | `gatekeepr_error_locked` | an attempt to modify a locked snapshot |
#' | `gatekeepr_error_lockfile` | a review working directory is held by another session |
#' | `gatekeepr_error_verify` | export verification failed |
#' | `gatekeepr_error_dependency` | a suggested package needed for this step is missing |
#' | `gatekeepr_error_state` | an object is not in the state a step needs |
#' | `gatekeepr_warning_uncallable` | markers not callable on an image (with list) |
#' | `gatekeepr_warning_disabled_rules` | rules disabled on an image (with list) |
#'
#' @name gatekeepR-conditions
#' @family package
#' @keywords internal
NULL
