# Phenotype hierarchy: ordered rules, flags with explicit policies,
# refinements by state calls and per-image threshold overrides.

.gk_decisions <- c("Tumor", "Benign", "Unresolved")
.gk_flag_policies <- c("exclude", "flag_only", "unresolved")
.gk_on_uncallable <- c("disable_rule", "treat_as_negative")

.gk_chr <- function(x, arg, call) {
  if (is.null(x) || length(x) == 0L) {
    return(character())
  }
  if (is.list(x)) {
    x <- unlist(x, use.names = FALSE)
  }
  if (!is.character(x) || anyNA(x) || any(!nzchar(x))) {
    .gk_abort("{.arg {arg}} must be a character vector of marker names.",
      class = "config", call = call
    )
  }
  unique(x)
}

#' Hierarchy rules, flags, refinements and overrides
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Building blocks of a phenotype hierarchy:
#'
#' * `gk_rule()` assigns `label` to cells positive for every marker in
#'   `all_of`, for at least one marker in `any_of` (ignored when empty) and
#'   negative for every marker in `none_of`. Rules are evaluated in order and
#'   the first match wins.
#' * `gk_flag()` is a named Boolean expression evaluated before the rules;
#'   its policy (`exclude`, `flag_only` or `unresolved`) is set in
#'   [gk_hierarchy()].
#' * `gk_refinement()` relabels cells of `from_label` that are positive for an
#'   enabled state call (`marker` within `parent`), e.g. CD4 T cells that are
#'   FOXP3-positive become Treg cells.
#' * `gk_override()` replaces the threshold method or arguments of one marker
#'   on one image, with a mandatory reason. Overrides are part of the
#'   configuration and its hash; they never live in code.
#'
#' @param rule_id Stable identifier, e.g. `"R010"`.
#' @param label Cell type assigned by the rule.
#' @param all_of,any_of,none_of Character vectors of marker names.
#' @param on_uncallable What to do with markers in `none_of` that are not
#'   callable on an image: `"disable_rule"` (default) or
#'   `"treat_as_negative"`. Markers in `all_of` or `any_of` that are not
#'   callable always disable the rule.
#' @param review `NULL`, or `"structure"`: matching cells start as
#'   `pending_label` until a structure decision exists (see
#'   [gk_decide_structure()]).
#' @param pending_label Label of cells awaiting a structure decision.
#' @param decisions Named list or character vector mapping each decision
#'   (`Tumor`, `Benign`, `Unresolved`) to a label.
#' @param marker,parent State marker and parent set of a refinement or
#'   override.
#' @param from_label,to_label Labels before and after refinement.
#' @param image_id Image the override applies to.
#' @param threshold_method,threshold_args Replacement method and arguments;
#'   `NULL` keeps the panel's.
#' @param reason Why the override exists (required, recorded).
#'
#' @return Objects of class `gk_rule`, `gk_flag`, `gk_refinement` or
#'   `gk_override`.
#'
#' @examples
#' gk_rule("R020", "CD8 T cells", all_of = c("CD45", "CD3e", "CD8"), none_of = "CD4")
#' gk_rule(
#'   "R010", "Epithelial cells",
#'   all_of = "PanCK", review = "structure",
#'   pending_label = "Unreviewed epithelial cells",
#'   decisions = c(
#'     Tumor = "Tumor cells", Benign = "Benign epithelial cells",
#'     Unresolved = "Unresolved epithelial cells"
#'   )
#' )
#' gk_flag(all_of = "PanCK", any_of = c("CD45", "CD3e"))
#' gk_refinement("RF10", "FOXP3", "CD4 T cells", "CD4 T cells", "Treg cells")
#' gk_override("slide-07", "CD3e",
#'   threshold_args = list(rule = "crossing"),
#'   reason = "Dim staining batch; q99 rule over-conservative (review 2026-03)"
#' )
#'
#' @family configuration
#' @name hierarchy-elements
NULL

#' @rdname hierarchy-elements
#' @export
gk_rule <- function(rule_id, label, all_of = character(), any_of = character(),
                    none_of = character(), on_uncallable = "disable_rule",
                    review = NULL, pending_label = NULL, decisions = NULL) {
  call <- rlang::current_env()
  .gk_check_string(rule_id)
  .gk_check_string(label)
  .gk_check_choice(on_uncallable, .gk_on_uncallable)
  all_of <- .gk_chr(all_of, "all_of", call)
  any_of <- .gk_chr(any_of, "any_of", call)
  none_of <- .gk_chr(none_of, "none_of", call)
  clash <- intersect(c(all_of, any_of), none_of)
  if (length(clash) > 0L) {
    .gk_abort(
      "Rule {.val {rule_id}} requires and excludes {.val {clash}} at the same time.",
      class = "config", call = call
    )
  }
  if (!is.null(review)) {
    .gk_check_choice(review, "structure")
    if (is.null(pending_label) || !is.character(pending_label) ||
      length(pending_label) != 1L || !nzchar(pending_label)) {
      .gk_abort(
        "Review rule {.val {rule_id}} needs a {.field pending_label}.",
        class = "config", call = call
      )
    }
    if (is.null(decisions)) {
      .gk_abort(
        c(
          "Review rule {.val {rule_id}} has no {.field decisions}.",
          "i" = "Map {.val {(.gk_decisions)}} to labels."
        ),
        class = "config", call = call
      )
    }
    decisions <- as.list(decisions)
    if (is.null(names(decisions)) || !setequal(names(decisions), .gk_decisions) ||
      !all(vapply(decisions, function(d) is.character(d) && length(d) == 1L && nzchar(d), logical(1)))) {
      .gk_abort(
        c(
          "Review rule {.val {rule_id}} must map exactly {.val {(.gk_decisions)}} to labels.",
          "x" = "Got {.val {names(decisions)}}."
        ),
        class = "config", call = call
      )
    }
    decisions <- decisions[.gk_decisions]
  } else if (!is.null(pending_label) || !is.null(decisions)) {
    .gk_abort(
      "Rule {.val {rule_id}} sets {.field pending_label} or {.field decisions} without {.code review = \"structure\"}.",
      class = "config", call = call
    )
  }
  structure(
    list(
      rule_id = rule_id, label = label, all_of = all_of, any_of = any_of,
      none_of = none_of, on_uncallable = on_uncallable, review = review,
      pending_label = pending_label, decisions = decisions
    ),
    class = "gk_rule"
  )
}

#' @rdname hierarchy-elements
#' @export
gk_flag <- function(all_of = character(), any_of = character(), none_of = character()) {
  call <- rlang::current_env()
  all_of <- .gk_chr(all_of, "all_of", call)
  any_of <- .gk_chr(any_of, "any_of", call)
  none_of <- .gk_chr(none_of, "none_of", call)
  if (length(c(all_of, any_of)) == 0L) {
    .gk_abort("A flag needs at least one marker in {.arg all_of} or {.arg any_of}.",
      class = "config", call = call
    )
  }
  structure(list(all_of = all_of, any_of = any_of, none_of = none_of), class = "gk_flag")
}

#' @rdname hierarchy-elements
#' @export
gk_refinement <- function(rule_id, marker, parent, from_label, to_label) {
  .gk_check_string(rule_id)
  .gk_check_string(marker)
  .gk_check_string(parent)
  .gk_check_string(from_label)
  .gk_check_string(to_label)
  structure(
    list(
      rule_id = rule_id, marker = marker, parent = parent,
      from_label = from_label, to_label = to_label
    ),
    class = "gk_refinement"
  )
}

#' @rdname hierarchy-elements
#' @export
gk_override <- function(image_id, marker, parent = NA_character_,
                        threshold_method = NULL, threshold_args = NULL, reason) {
  call <- rlang::current_env()
  .gk_check_string(image_id)
  .gk_check_string(marker)
  if (!(length(parent) == 1L && (is.na(parent) || (is.character(parent) && nzchar(parent))))) {
    .gk_abort("{.arg parent} must be one parent set name or {.code NA}.",
      class = "config", call = call
    )
  }
  if (missing(reason) || !is.character(reason) || length(reason) != 1L ||
    is.na(reason) || !nzchar(trimws(reason))) {
    .gk_abort(
      "Override for {.val {marker}} on {.val {image_id}} needs a {.arg reason}.",
      class = "config", call = call
    )
  }
  if (is.null(threshold_method) && is.null(threshold_args)) {
    .gk_abort(
      "Override for {.val {marker}} on {.val {image_id}} changes nothing.",
      class = "config", call = call
    )
  }
  if (!is.null(threshold_method)) {
    .gk_check_string(threshold_method)
  }
  if (!is.null(threshold_args) && (!is.list(threshold_args) || is.null(names(threshold_args)))) {
    .gk_abort("{.arg threshold_args} must be a named list.", class = "config", call = call)
  }
  structure(
    list(
      image_id = image_id, marker = marker, parent = as.character(parent),
      threshold_method = threshold_method, threshold_args = threshold_args,
      reason = reason
    ),
    class = "gk_override"
  )
}

#' Declare a phenotype hierarchy
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' An ordered set of [gk_rule()]s (first match wins), flags evaluated before
#' the rules with an explicit policy each, and the labels used for cells that
#' match no rule, that are excluded by a flag, or that are unresolved.
#'
#' Flag policies:
#' * `exclude`: the cell is labelled `excluded_label` and not analysed.
#' * `unresolved`: the cell is labelled `unresolved_label`.
#' * `flag_only`: the flag is recorded and the cell continues through the
#'   rules.
#'
#' The chosen policy is part of the configuration hash and applies identically
#' in batch code and in the review app.
#'
#' @param rules List of [gk_rule()] objects, in evaluation order.
#' @param flags Named list of [gk_flag()] objects.
#' @param flag_policy Named list or character vector giving the policy of
#'   every flag.
#' @param undefined_label,excluded_label,unresolved_label Labels for cells
#'   matching no rule, excluded by a flag, or unresolved by a flag.
#' @param version Version string of the hierarchy (required).
#' @param rationale Free text recorded with the hierarchy.
#'
#' @return An object of class `gk_hierarchy`.
#'
#' @examples
#' gk_hierarchy(
#'   rules = list(
#'     gk_rule("R010", "T cells", all_of = c("CD45", "CD3e")),
#'     gk_rule("R020", "Other immune cells", all_of = "CD45")
#'   ),
#'   flags = list(mixed = gk_flag(all_of = "PanCK", any_of = "CD45")),
#'   flag_policy = c(mixed = "unresolved"),
#'   version = "1.0"
#' )
#'
#' @family configuration
#' @export
gk_hierarchy <- function(rules, flags = list(), flag_policy = list(),
                         undefined_label = "Undefined", excluded_label = "Excluded",
                         unresolved_label = "Unresolved", version, rationale = "") {
  call <- rlang::current_env()
  if (missing(version)) {
    .gk_abort("A hierarchy needs a {.arg version}.", class = "config", call = call)
  }
  .gk_check_string(version)
  .gk_check_string(rationale, allow_empty = TRUE)
  .gk_check_string(undefined_label)
  .gk_check_string(excluded_label)
  .gk_check_string(unresolved_label)
  if (!is.list(rules) || length(rules) == 0L ||
    !all(vapply(rules, inherits, logical(1), "gk_rule"))) {
    .gk_abort(
      "{.arg rules} must be a non-empty list of {.fn gk_rule} objects.",
      class = "config", call = call
    )
  }
  ids <- vapply(rules, `[[`, character(1), "rule_id")
  if (anyDuplicated(ids)) {
    .gk_abort(
      "Duplicate rule_id{?s} {.val {unique(ids[duplicated(ids)])}} in the hierarchy.",
      class = "config", call = call
    )
  }
  if (length(flags) > 0L && (is.null(names(flags)) || any(!nzchar(names(flags))) ||
    anyDuplicated(names(flags)) || !all(vapply(flags, inherits, logical(1), "gk_flag")))) {
    .gk_abort(
      "{.arg flags} must be a list of {.fn gk_flag} objects with unique names.",
      class = "config", call = call
    )
  }
  flag_policy <- as.list(flag_policy)
  missing_policy <- setdiff(names(flags), names(flag_policy))
  if (length(missing_policy) > 0L) {
    .gk_abort(
      c(
        "Flag{?s} {.val {missing_policy}} ha{?s/ve} no policy.",
        "i" = "Set {.arg flag_policy} to one of {.val {(.gk_flag_policies)}} for every flag."
      ),
      class = "config", call = call
    )
  }
  extra_policy <- setdiff(names(flag_policy), names(flags))
  if (length(extra_policy) > 0L) {
    .gk_abort("{.arg flag_policy} names undefined flag{?s} {.val {extra_policy}}.",
      class = "config", call = call
    )
  }
  bad <- names(flag_policy)[!vapply(flag_policy, function(p) {
    is.character(p) && length(p) == 1L && p %in% .gk_flag_policies
  }, logical(1))]
  if (length(bad) > 0L) {
    .gk_abort(
      c(
        "Invalid policy for flag{?s} {.val {bad}}.",
        "i" = "Policies are {.val {(.gk_flag_policies)}}."
      ),
      class = "config", call = call
    )
  }
  flag_policy <- flag_policy[names(flags)]
  names(rules) <- NULL
  structure(
    list(
      rules = rules, flags = flags, flag_policy = flag_policy,
      undefined_label = undefined_label, excluded_label = excluded_label,
      unresolved_label = unresolved_label, version = version, rationale = rationale
    ),
    class = "gk_hierarchy"
  )
}

# All labels a hierarchy (plus refinements) can assign.
.gk_hierarchy_labels <- function(hierarchy, refinements = list()) {
  rule_labels <- unlist(lapply(hierarchy$rules, function(r) {
    if (is.null(r$review)) r$label else c(r$pending_label, unlist(r$decisions))
  }), use.names = FALSE)
  unique(c(
    rule_labels, vapply(refinements, `[[`, character(1), "to_label"),
    hierarchy$undefined_label, hierarchy$excluded_label, hierarchy$unresolved_label
  ))
}

# Rule table used for printing and in the app's Rules tab.
.gk_rule_table <- function(hierarchy) {
  data.frame(
    rule_id = vapply(hierarchy$rules, `[[`, character(1), "rule_id"),
    label = vapply(hierarchy$rules, `[[`, character(1), "label"),
    all_of = vapply(hierarchy$rules, function(r) paste(r$all_of, collapse = ", "), character(1)),
    any_of = vapply(hierarchy$rules, function(r) paste(r$any_of, collapse = ", "), character(1)),
    none_of = vapply(hierarchy$rules, function(r) paste(r$none_of, collapse = ", "), character(1)),
    on_uncallable = vapply(hierarchy$rules, `[[`, character(1), "on_uncallable"),
    review = vapply(hierarchy$rules, function(r) r$review %||% "", character(1)),
    stringsAsFactors = FALSE
  )
}

#' @export
print.gk_hierarchy <- function(x, ...) {
  cli::cli_text(
    "{.cls gk_hierarchy} version {.val {x$version}}: {length(x$rules)} rule{?s}, ",
    "{length(x$flags)} flag{?s}"
  )
  print(.gk_rule_table(x), row.names = FALSE)
  for (nm in names(x$flags)) {
    f <- x$flags[[nm]]
    cli::cli_text(
      "Flag {.field {nm}} ({.val {x$flag_policy[[nm]]}}): all_of {.val {f$all_of}}; ",
      "any_of {.val {f$any_of}}; none_of {.val {f$none_of}}"
    )
  }
  invisible(x)
}

#' @export
print.gk_rule <- function(x, ...) {
  cli::cli_text("{.cls gk_rule} {.val {x$rule_id}} -> {.val {x$label}}")
  cli::cli_bullets(c(
    " " = "all_of: {.val {x$all_of}}",
    " " = "any_of: {.val {x$any_of}}",
    " " = "none_of: {.val {x$none_of}}",
    " " = "on_uncallable: {.val {x$on_uncallable}}"
  ))
  if (!is.null(x$review)) {
    cli::cli_bullets(c(" " = "review: structure, pending as {.val {x$pending_label}}"))
  }
  invisible(x)
}
