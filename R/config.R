# Study configuration: signal policy, panel, parent sets, hierarchy,
# overrides and refinements, with cross-component validation and a canonical
# hash.

.gk_config_schema_version <- "1.0.0"

#' Assemble a gating configuration
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' A configuration is the single source of truth for gating a study: which
#' measurement represents each marker, the marker panel, the named parent sets
#' used by state markers, the phenotype hierarchy, per-image threshold
#' overrides and state-based refinements. It is validated as a whole and
#' hashed canonically (see [gk_config_hash()]); the hash travels with every
#' result produced from it.
#'
#' @param signal_policy A [gk_signal_policy()] (or `cellspecR` signal
#'   policy) data frame.
#' @param panel A [gk_panel()].
#' @param parent_sets Named list of character vectors of cell-type labels,
#'   e.g. `list("T cells" = c("CD4 T cells", "CD8 T cells"))`.
#' @param hierarchy A [gk_hierarchy()].
#' @param overrides `NULL` or a list of [gk_override()] objects.
#' @param refinements `NULL` or a list of [gk_refinement()] objects.
#'
#' @return An object of class `gk_config`. Invalid combinations abort with a
#'   `gatekeepr_error_config` listing every failed check.
#'
#' @seealso [gk_validate_config()] for a check table without aborting;
#'   `vignette("configuration", package = "gatekeepR")`.
#'
#' @examples
#' cfg <- gk_example_config()
#' cfg
#' gk_config_hash(cfg)
#'
#' @family configuration
#' @export
gk_config <- function(signal_policy, panel, parent_sets = list(), hierarchy,
                      overrides = NULL, refinements = NULL) {
  config <- .gk_build_config(
    signal_policy = signal_policy, panel = panel, parent_sets = parent_sets,
    hierarchy = hierarchy, overrides = overrides, refinements = refinements
  )
  .gk_assert_config(config)
}

.gk_build_config <- function(signal_policy, panel, parent_sets, hierarchy, overrides,
                             refinements, call = rlang::caller_env()) {
  signal_policy <- .gk_validate_signal_policy(signal_policy, call = call)
  .gk_check_class(panel, "gk_panel", call = call, hint = "Build it with {.fn gk_panel}.")
  .gk_check_class(hierarchy, "gk_hierarchy",
    call = call,
    hint = "Build it with {.fn gk_hierarchy}."
  )
  if (!is.list(parent_sets) || (length(parent_sets) > 0L && (is.null(names(parent_sets)) ||
    any(!nzchar(names(parent_sets))) || anyDuplicated(names(parent_sets)) ||
    !all(vapply(parent_sets, function(p) is.character(p) && !anyNA(p), logical(1)))))) {
    .gk_abort(
      "{.arg parent_sets} must be a list of character vectors with unique names.",
      class = "config", call = call
    )
  }
  overrides <- overrides %||% list()
  refinements <- refinements %||% list()
  if (!is.list(overrides) || !all(vapply(overrides, inherits, logical(1), "gk_override"))) {
    .gk_abort("{.arg overrides} must be a list of {.fn gk_override} objects.",
      class = "config", call = call
    )
  }
  if (!is.list(refinements) ||
    !all(vapply(refinements, inherits, logical(1), "gk_refinement"))) {
    .gk_abort("{.arg refinements} must be a list of {.fn gk_refinement} objects.",
      class = "config", call = call
    )
  }
  names(overrides) <- NULL
  names(refinements) <- NULL
  structure(
    list(
      schema_version = .gk_config_schema_version,
      signal_policy = signal_policy,
      panel = panel,
      parent_sets = lapply(parent_sets, unique),
      hierarchy = hierarchy,
      overrides = overrides,
      refinements = refinements
    ),
    class = "gk_config"
  )
}

.gk_assert_config <- function(config, call = rlang::caller_env()) {
  checks <- .gk_config_checks(config)
  failed <- checks[checks$status == "fail", , drop = FALSE]
  if (nrow(failed) > 0L) {
    bullets <- .gk_cli_escape(failed$message)
    names(bullets) <- rep("x", length(bullets))
    .gk_abort(
      c(
        "Invalid gatekeepR configuration ({nrow(failed)} failed check{?s}).",
        bullets
      ),
      class = "config", call = call
    )
  }
  config
}

.gk_cli_escape <- function(x) {
  gsub("\\}", "}}", gsub("\\{", "{{", x))
}

# Cross-component checks. Returns a data frame (check, status, message);
# every failed check names the rule, flag, marker or parent set involved.
.gk_config_checks <- function(config) {
  rows <- list()
  add <- function(check, failures) {
    if (length(failures) == 0L) {
      rows[[length(rows) + 1L]] <<- data.frame(
        check = check, status = "pass", message = "", stringsAsFactors = FALSE
      )
    } else {
      rows[[length(rows) + 1L]] <<- data.frame(
        check = check, status = "fail", message = failures, stringsAsFactors = FALSE
      )
    }
  }
  pm <- config$panel$markers
  roles <- stats::setNames(pm$role, pm$marker)
  gating <- pm$marker[pm$role %in% .gk_gating_roles]
  state <- pm$marker[pm$role == "state"]
  h <- config$hierarchy
  labels <- .gk_hierarchy_labels(h, config$refinements)

  add("panel_markers_in_signal_policy", sprintf(
    "Panel marker '%s' has no entry in the signal policy.",
    setdiff(pm$marker, config$signal_policy$marker)
  ))

  rule_fail <- character()
  for (r in h$rules) {
    used <- c(r$all_of, r$any_of, r$none_of)
    unknown <- setdiff(used, pm$marker)
    rule_fail <- c(rule_fail, sprintf(
      "Rule '%s' refers to unknown marker '%s'.", rep(r$rule_id, length(unknown)), unknown
    ))
    wrong <- used[used %in% pm$marker & !used %in% gating]
    rule_fail <- c(rule_fail, sprintf(
      "Rule '%s' uses %s marker '%s'; only identity and conditional_identity markers enter rules.",
      rep(r$rule_id, length(wrong)), roles[wrong], wrong
    ))
  }
  add("rule_markers_known", rule_fail)

  flag_fail <- character()
  for (nm in names(h$flags)) {
    f <- h$flags[[nm]]
    used <- c(f$all_of, f$any_of, f$none_of)
    unknown <- setdiff(used, pm$marker)
    flag_fail <- c(flag_fail, sprintf(
      "Flag '%s' refers to unknown marker '%s'.", rep(nm, length(unknown)), unknown
    ))
    wrong <- used[used %in% pm$marker & !used %in% gating]
    flag_fail <- c(flag_fail, sprintf(
      "Flag '%s' uses %s marker '%s'; only identity and conditional_identity markers enter flags.",
      rep(nm, length(wrong)), roles[wrong], wrong
    ))
  }
  add("flag_markers_known", flag_fail)

  parent_fail <- character()
  for (mk in state) {
    undefined <- setdiff(config$panel$parents[[mk]], names(config$parent_sets))
    parent_fail <- c(parent_fail, sprintf(
      "State marker '%s' refers to undefined parent set '%s'.",
      rep(mk, length(undefined)), undefined
    ))
    args <- config$panel$threshold_args[[mk]]
    if (identical(pm$threshold_method[pm$marker == mk], "parent_crossing") &&
      !is.null(args$reference) && !identical(args$reference, "rest") &&
      !args$reference %in% names(config$parent_sets)) {
      parent_fail <- c(parent_fail, sprintf(
        "State marker '%s' uses undefined reference set '%s'.", mk, args$reference
      ))
    }
  }
  add("state_parents_defined", parent_fail)

  set_fail <- character()
  for (nm in names(config$parent_sets)) {
    unknown <- setdiff(config$parent_sets[[nm]], labels)
    set_fail <- c(set_fail, sprintf(
      "Parent set '%s' contains label '%s', which the hierarchy never assigns.",
      rep(nm, length(unknown)), unknown
    ))
    empty <- length(config$parent_sets[[nm]]) == 0L
    if (empty) {
      set_fail <- c(set_fail, sprintf("Parent set '%s' is empty.", nm))
    }
  }
  add("parent_set_labels_known", set_fail)

  ref_fail <- character()
  rule_ids <- vapply(h$rules, `[[`, character(1), "rule_id")
  ref_ids <- vapply(config$refinements, `[[`, character(1), "rule_id")
  dup <- unique(c(ref_ids[duplicated(ref_ids)], intersect(ref_ids, rule_ids)))
  ref_fail <- c(ref_fail, sprintf("Refinement rule_id '%s' is not unique.", dup))
  for (rf in config$refinements) {
    if (!rf$marker %in% state) {
      ref_fail <- c(ref_fail, sprintf(
        "Refinement '%s' uses '%s', which is not a state marker.", rf$rule_id, rf$marker
      ))
    } else if (!rf$parent %in% config$panel$parents[[rf$marker]]) {
      ref_fail <- c(ref_fail, sprintf(
        "Refinement '%s': '%s' is not a parent set of state marker '%s'.",
        rf$rule_id, rf$parent, rf$marker
      ))
    }
    if (!rf$from_label %in% labels) {
      ref_fail <- c(ref_fail, sprintf(
        "Refinement '%s' starts from label '%s', which the hierarchy never assigns.",
        rf$rule_id, rf$from_label
      ))
    }
  }
  add("refinements_valid", ref_fail)

  ov_fail <- character()
  reg <- .gk_method_registry()
  keys <- vapply(config$overrides, function(o) {
    paste(o$image_id, o$marker, o$parent, sep = "\r")
  }, character(1))
  if (anyDuplicated(keys)) {
    ov_fail <- c(ov_fail, "Two overrides target the same image, marker and parent.")
  }
  for (o in config$overrides) {
    if (!o$marker %in% c(gating, state)) {
      ov_fail <- c(ov_fail, sprintf(
        "Override for image '%s' targets '%s', which is not a gated panel marker.",
        o$image_id, o$marker
      ))
      next
    }
    role <- roles[[o$marker]]
    if (identical(role, "state") && !is.na(o$parent) &&
      !o$parent %in% config$panel$parents[[o$marker]]) {
      ov_fail <- c(ov_fail, sprintf(
        "Override for '%s' on image '%s' names parent '%s', which the marker does not use.",
        o$marker, o$image_id, o$parent
      ))
    }
    if (!identical(role, "state") && !is.na(o$parent)) {
      ov_fail <- c(ov_fail, sprintf(
        "Override for identity marker '%s' on image '%s' must not name a parent.",
        o$marker, o$image_id
      ))
    }
    method <- o$threshold_method %||% pm$threshold_method[pm$marker == o$marker]
    if (!method %in% names(reg)) {
      ov_fail <- c(ov_fail, sprintf(
        "Override for '%s' on image '%s' uses unknown method '%s'.", o$marker, o$image_id, method
      ))
      next
    }
    if (!role %in% reg[[method]]$roles) {
      ov_fail <- c(ov_fail, sprintf(
        "Override for '%s' on image '%s': method '%s' is not allowed for %s markers.",
        o$marker, o$image_id, method, role
      ))
    }
    allowed <- names(reg[[method]]$args)
    if (identical(role, "state")) {
      allowed <- c(allowed, names(.gk_state_common_args))
    }
    unknown <- setdiff(names(o$threshold_args), allowed)
    ov_fail <- c(ov_fail, sprintf(
      "Override for '%s' on image '%s' uses unknown argument '%s' for method '%s'.",
      rep(o$marker, length(unknown)), rep(o$image_id, length(unknown)), unknown,
      rep(method, length(unknown))
    ))
  }
  add("overrides_valid", ov_fail)

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' Validate a gating configuration
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Runs every configuration check and returns them as a table instead of
#' aborting. Accepts a [gk_config()] object, a path to a configuration JSON
#' file, or a list as parsed from such a file. Construction errors (for
#' example a duplicated `rule_id`) are reported as a failed `construction`
#' check.
#'
#' @param config A `gk_config`, a path to a JSON file, or a parsed list.
#'
#' @return A data frame of class `gk_config_checks` with columns `check`,
#'   `status` (`"pass"` or `"fail"`) and `message`.
#'
#' @examples
#' gk_validate_config(gk_example_config())
#'
#' @family configuration
#' @export
gk_validate_config <- function(config) {
  built <- tryCatch(
    {
      if (inherits(config, "gk_config")) {
        config
      } else if (is.character(config) && length(config) == 1L) {
        .gk_check_file_exists(config, arg = "config")
        .gk_config_from_list(.gk_read_json(config))
      } else if (is.list(config)) {
        .gk_config_from_list(config)
      } else {
        .gk_abort("{.arg config} must be a {.cls gk_config}, a path or a list.", class = "input")
      }
    },
    gatekeepr_error = function(e) e
  )
  if (inherits(built, "gatekeepr_error")) {
    out <- data.frame(
      check = "construction", status = "fail",
      message = paste(cli::ansi_strip(conditionMessage(built)), collapse = " "),
      stringsAsFactors = FALSE
    )
  } else {
    out <- rbind(
      data.frame(check = "construction", status = "pass", message = "", stringsAsFactors = FALSE),
      .gk_config_checks(built)
    )
  }
  class(out) <- c("gk_config_checks", "data.frame")
  out
}

#' @export
print.gk_config_checks <- function(x, ...) {
  n_fail <- sum(x$status == "fail")
  if (n_fail == 0L) {
    cli::cli_alert_success("Configuration valid ({nrow(x)} check{?s} passed).")
  } else {
    cli::cli_alert_danger("Configuration invalid: {n_fail} failed check{?s}.")
    failed <- x[x$status == "fail", , drop = FALSE]
    for (i in seq_len(nrow(failed))) {
      cli::cli_bullets(c("x" = "{failed$check[[i]]}: {failed$message[[i]]}"))
    }
  }
  invisible(x)
}

#' @export
print.gk_config <- function(x, ...) {
  pm <- x$panel$markers
  role_counts <- table(factor(pm$role, levels = .gk_roles))
  cli::cli_text("{.cls gk_config} (schema {x$schema_version})")
  cli::cli_bullets(c(
    "*" = "Panel: {nrow(pm)} marker{?s} ({paste(names(role_counts), role_counts, sep = ' ', collapse = ', ')})",
    "*" = "Hierarchy {.val {x$hierarchy$version}}: {length(x$hierarchy$rules)} rule{?s}, {length(x$hierarchy$flags)} flag{?s}",
    "*" = "Parent sets: {length(x$parent_sets)}; refinements: {length(x$refinements)}; overrides: {length(x$overrides)}",
    "*" = "SHA-256: {.val {gk_config_hash(x)}}"
  ))
  invisible(x)
}

#' Canonical hash of a configuration
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' SHA-256 of the canonical JSON form of a configuration: object keys sorted,
#' no insignificant whitespace, numbers in shortest round-trip form. The hash
#' is therefore identical for configurations that differ only in key order,
#' whitespace or numeric spelling in their JSON files, and changes whenever a
#' rule, threshold setting, flag policy, override or refinement changes.
#'
#' @param config A [gk_config()].
#'
#' @return A 64-character lowercase hexadecimal string.
#'
#' @examples
#' gk_config_hash(gk_example_config())
#'
#' @family configuration
#' @export
gk_config_hash <- function(config) {
  .gk_check_class(config, "gk_config")
  .gk_sha256_object(.gk_config_to_list(config))
}
