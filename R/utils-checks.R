# Internal input-validation helpers. All take `arg` (the argument name as the
# user wrote it) and `call` (the user-facing call environment) so that the
# resulting message points at the user's code, not at this helper.

.gk_check_string <- function(x, arg = rlang::caller_arg(x),
                             call = rlang::caller_env(), allow_empty = FALSE) {
  ok <- is.character(x) && length(x) == 1L && !is.na(x) &&
    (allow_empty || nzchar(x))
  if (!ok) {
    .gk_abort(
      c(
        "{.arg {arg}} must be a single non-empty string.",
        "x" = "Got {.obj_type_friendly {x}}."
      ),
      class = "input", call = call
    )
  }
  invisible(x)
}

.gk_check_character <- function(x, arg = rlang::caller_arg(x),
                                call = rlang::caller_env(), min_length = 0L,
                                unique = FALSE) {
  ok <- is.character(x) && !anyNA(x) && all(nzchar(x)) &&
    length(x) >= min_length
  if (!ok) {
    .gk_abort(
      c(
        "{.arg {arg}} must be a character vector without missing or empty values.",
        "x" = "Got {.obj_type_friendly {x}}."
      ),
      class = "input", call = call
    )
  }
  if (unique && anyDuplicated(x)) {
    dup <- unique(x[duplicated(x)])
    .gk_abort(
      c(
        "{.arg {arg}} must not contain duplicates.",
        "x" = "Duplicated: {.val {dup}}."
      ),
      class = "input", call = call
    )
  }
  invisible(x)
}

.gk_check_flag <- function(x, arg = rlang::caller_arg(x),
                           call = rlang::caller_env()) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    .gk_abort(
      "{.arg {arg}} must be {.code TRUE} or {.code FALSE}.",
      class = "input", call = call
    )
  }
  invisible(x)
}

.gk_check_number <- function(x, arg = rlang::caller_arg(x),
                             call = rlang::caller_env(), min = -Inf,
                             max = Inf, allow_na = FALSE) {
  if (allow_na && length(x) == 1L && is.na(x) && !is.nan(x)) {
    return(invisible(x))
  }
  ok <- is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x) &&
    x >= min && x <= max
  if (!ok) {
    .gk_abort(
      c(
        "{.arg {arg}} must be a single finite number in [{min}, {max}].",
        "x" = "Got {.obj_type_friendly {x}}."
      ),
      class = "input", call = call
    )
  }
  invisible(x)
}

.gk_check_count <- function(x, arg = rlang::caller_arg(x),
                            call = rlang::caller_env(), min = 0L) {
  ok <- is.numeric(x) && length(x) == 1L && !is.na(x) && is.finite(x) &&
    x == round(x) && x >= min
  if (!ok) {
    .gk_abort(
      c(
        "{.arg {arg}} must be a single whole number >= {min}.",
        "x" = "Got {.obj_type_friendly {x}}."
      ),
      class = "input", call = call
    )
  }
  invisible(as.integer(x))
}

.gk_check_choice <- function(x, choices, arg = rlang::caller_arg(x),
                             call = rlang::caller_env()) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !x %in% choices) {
    .gk_abort(
      c(
        "{.arg {arg}} must be one of {.or {.val {choices}}}.",
        "x" = "Got {.val {x}}."
      ),
      class = "input", call = call
    )
  }
  invisible(x)
}

.gk_check_class <- function(x, class, arg = rlang::caller_arg(x),
                            call = rlang::caller_env(), hint = NULL) {
  if (!inherits(x, class)) {
    msg <- c(
      "{.arg {arg}} must be a {.cls {class[[1L]]}} object.",
      "x" = "Got {.obj_type_friendly {x}}."
    )
    if (!is.null(hint)) {
      msg <- c(msg, "i" = hint)
    }
    .gk_abort(msg, class = "input", call = call)
  }
  invisible(x)
}

.gk_check_dir_exists <- function(path, arg = rlang::caller_arg(path),
                                 call = rlang::caller_env()) {
  .gk_check_string(path, arg = arg, call = call)
  if (!dir.exists(path)) {
    .gk_abort(
      c(
        "{.arg {arg}} must be an existing directory.",
        "x" = "{.path {path}} does not exist."
      ),
      class = "input", call = call
    )
  }
  invisible(path)
}

.gk_check_file_exists <- function(path, arg = rlang::caller_arg(path),
                                  call = rlang::caller_env()) {
  .gk_check_string(path, arg = arg, call = call)
  if (!file.exists(path) || dir.exists(path)) {
    .gk_abort(
      c(
        "{.arg {arg}} must be an existing file.",
        "x" = "{.path {path}} does not exist."
      ),
      class = "input", call = call
    )
  }
  invisible(path)
}

# Reviewer identifiers are free text; documentation recommends pseudonymous
# IDs because ledgers hold them. Tabs and newlines would break TSV ledgers.
.gk_check_reviewer <- function(reviewer, arg = rlang::caller_arg(reviewer),
                               call = rlang::caller_env()) {
  .gk_check_string(reviewer, arg = arg, call = call)
  if (grepl("[\t\r\n]", reviewer) || nchar(reviewer, type = "bytes") > 200L) {
    .gk_abort(
      c(
        "{.arg {arg}} must be a short identifier without tabs or line breaks.",
        "i" = "Use a pseudonymous reviewer ID such as {.val reviewer-01}."
      ),
      class = "input", call = call
    )
  }
  invisible(reviewer)
}

# Reasons are stored in ledgers (max 1,000 bytes, no control characters that
# would break a TSV row). `required = TRUE` forbids the empty string.
.gk_check_reason <- function(reason, required = TRUE,
                             arg = rlang::caller_arg(reason),
                             call = rlang::caller_env()) {
  .gk_check_string(reason, arg = arg, call = call, allow_empty = !required)
  if (required && !nzchar(trimws(reason))) {
    .gk_abort(
      "{.arg {arg}} must give a reason; this action is recorded in the ledger.",
      class = "input", call = call
    )
  }
  if (grepl("[\t\r\n]", reason)) {
    .gk_abort(
      "{.arg {arg}} must not contain tabs or line breaks.",
      class = "input", call = call
    )
  }
  if (nchar(reason, type = "bytes") > 1000L) {
    .gk_abort(
      c(
        "{.arg {arg}} must be at most 1,000 bytes.",
        "x" = "Got {nchar(reason, type = 'bytes')} bytes."
      ),
      class = "input", call = call
    )
  }
  invisible(reason)
}

# NULL-coalescing without relying on base R >= 4.4.
`%||%` <- function(x, y) if (is.null(x)) y else x
