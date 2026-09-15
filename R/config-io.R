# Configuration <-> JSON. The list form produced by .gk_config_to_list() is
# both what is written to disk and what is hashed; every array-valued field is
# wrapped in I() so that length-one arrays stay arrays.

.gk_obj <- function(x) {
  if (is.null(x) || length(x) == 0L) {
    return(structure(list(), names = character()))
  }
  x
}

.gk_arr <- function(x) I(as.character(x %||% character()))

# Normalise method arguments for JSON: vectors become arrays, scalars stay.
.gk_args_to_list <- function(args) {
  if (length(args) == 0L) {
    return(.gk_obj(NULL))
  }
  out <- lapply(args, function(v) {
    if (is.list(v)) {
      .gk_args_to_list(v)
    } else if (length(v) != 1L) {
      I(v)
    } else {
      v
    }
  })
  names(out) <- names(args)
  out
}

.gk_config_to_list <- function(config) {
  pol <- config$signal_policy
  panel <- config$panel
  h <- config$hierarchy
  list(
    schema = "gatekeepr-config",
    schema_version = config$schema_version,
    signal_policy = lapply(seq_len(nrow(pol)), function(i) {
      list(
        marker = pol$marker[[i]],
        compartment = pol$compartment[[i]],
        statistic = pol$statistic[[i]],
        fallback_compartment = pol$fallback_compartment[[i]],
        min_value = pol$min_value[[i]]
      )
    }),
    panel = lapply(seq_len(nrow(panel$markers)), function(i) {
      mk <- panel$markers$marker[[i]]
      ms <- panel$min_support[[mk]]
      loc <- panel$localization[[mk]]
      list(
        marker = mk,
        role = panel$markers$role[[i]],
        transform = panel$markers$transform[[i]],
        cofactor = panel$markers$cofactor[[i]],
        threshold_method = panel$markers$threshold_method[[i]],
        threshold_args = .gk_args_to_list(panel$threshold_args[[mk]]),
        parents = .gk_arr(panel$parents[[mk]]),
        localization = if (is.null(loc)) NULL else loc[c("numerator", "denominator", "min_ratio", "statistic")],
        optional = panel$markers$optional[[i]],
        min_support = unclass(ms)
      )
    }),
    parent_sets = .gk_obj(
      lapply(
        if (length(config$parent_sets) > 0L && !is.null(names(config$parent_sets))) {
          config$parent_sets[order(names(config$parent_sets))]
        } else {
          config$parent_sets
        },
        .gk_arr
      )
    ),
    hierarchy = list(
      version = h$version,
      rationale = h$rationale,
      undefined_label = h$undefined_label,
      excluded_label = h$excluded_label,
      unresolved_label = h$unresolved_label,
      flags = .gk_obj(lapply(h$flags, function(f) {
        list(all_of = .gk_arr(f$all_of), any_of = .gk_arr(f$any_of), none_of = .gk_arr(f$none_of))
      })),
      flag_policy = .gk_obj(h$flag_policy),
      rules = lapply(h$rules, function(r) {
        list(
          rule_id = r$rule_id,
          label = r$label,
          all_of = .gk_arr(r$all_of),
          any_of = .gk_arr(r$any_of),
          none_of = .gk_arr(r$none_of),
          on_uncallable = r$on_uncallable,
          review = r$review,
          pending_label = r$pending_label,
          decisions = r$decisions
        )
      })
    ),
    overrides = lapply(config$overrides, function(o) {
      list(
        image_id = o$image_id,
        marker = o$marker,
        parent = o$parent,
        threshold_method = o$threshold_method,
        threshold_args = if (is.null(o$threshold_args)) NULL else .gk_args_to_list(o$threshold_args),
        reason = o$reason
      )
    }),
    refinements = lapply(config$refinements, function(r) {
      list(
        rule_id = r$rule_id, marker = r$marker, parent = r$parent,
        from_label = r$from_label, to_label = r$to_label
      )
    })
  )
}

# JSON arrays of scalars arrive as lists; turn them back into vectors.
.gk_unlist_scalar <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  if (is.list(x) && is.null(names(x)) &&
    all(vapply(x, function(v) is.atomic(v) && length(v) == 1L, logical(1)))) {
    return(unlist(x, use.names = FALSE))
  }
  x
}

.gk_list_args <- function(args) {
  if (is.null(args) || length(args) == 0L) {
    return(list())
  }
  out <- lapply(args, function(v) {
    if (is.list(v) && !is.null(names(v))) .gk_list_args(v) else .gk_unlist_scalar(v)
  })
  names(out) <- names(args)
  out
}

.gk_config_from_list <- function(x, call = rlang::caller_env()) {
  if (!is.list(x)) {
    .gk_abort("A configuration must be a JSON object.", class = "config", call = call)
  }
  version <- x$schema_version %||% NA_character_
  if (!identical(sub("\\..*$", "", version), "1")) {
    .gk_abort(
      c(
        "Unsupported configuration schema version {.val {version}}.",
        "i" = "This version of gatekeepR reads schema 1.x."
      ),
      class = "config", call = call
    )
  }
  need <- c("signal_policy", "panel", "hierarchy")
  miss <- setdiff(need, names(x))
  if (length(miss) > 0L) {
    .gk_abort("Configuration lacks {.field {miss}}.", class = "config", call = call)
  }
  pol_rows <- x$signal_policy
  field <- function(rows, nm, default) {
    vapply(rows, function(r) {
      v <- r[[nm]]
      if (is.null(v) || length(v) != 1L) {
        return(default)
      }
      storage.mode(v) <- storage.mode(default)
      v
    }, default)
  }
  policy <- gk_signal_policy(
    marker = field(pol_rows, "marker", NA_character_),
    compartment = field(pol_rows, "compartment", NA_character_),
    statistic = field(pol_rows, "statistic", NA_character_),
    fallback_compartment = field(pol_rows, "fallback_compartment", NA_character_),
    min_value = field(pol_rows, "min_value", 0)
  )
  pr <- x$panel
  markers <- field(pr, "marker", NA_character_)
  loc <- stats::setNames(lapply(pr, function(r) {
    if (is.null(r$localization)) NULL else lapply(r$localization, .gk_unlist_scalar)
  }), markers)
  loc <- loc[!vapply(loc, is.null, logical(1))]
  roles <- field(pr, "role", NA_character_)
  panel <- gk_panel(
    marker = markers,
    role = roles,
    transform = field(pr, "transform", "asinh"),
    cofactor = field(pr, "cofactor", 5),
    threshold_method = field(pr, "threshold_method", "mixture"),
    threshold_args = stats::setNames(lapply(pr, function(r) .gk_list_args(r$threshold_args)), markers),
    parents = stats::setNames(
      lapply(pr[roles == "state"], function(r) as.character(unlist(r$parents))),
      markers[roles == "state"]
    ),
    localization = if (length(loc)) loc else NULL,
    optional = field(pr, "optional", FALSE),
    min_support = stats::setNames(lapply(pr, function(r) {
      .gk_as_min_support(r$min_support %||% list(), call = call)
    }), markers)
  )
  h <- x$hierarchy
  rules <- lapply(h$rules, function(r) {
    gk_rule(
      rule_id = r$rule_id, label = r$label,
      all_of = unlist(r$all_of), any_of = unlist(r$any_of), none_of = unlist(r$none_of),
      on_uncallable = r$on_uncallable %||% "disable_rule",
      review = r$review, pending_label = r$pending_label,
      decisions = if (is.null(r$decisions)) NULL else unlist(r$decisions)
    )
  })
  flags <- lapply(h$flags %||% list(), function(f) {
    gk_flag(all_of = unlist(f$all_of), any_of = unlist(f$any_of), none_of = unlist(f$none_of))
  })
  hierarchy <- gk_hierarchy(
    rules = rules,
    flags = flags,
    flag_policy = lapply(h$flag_policy %||% list(), unlist),
    undefined_label = h$undefined_label %||% "Undefined",
    excluded_label = h$excluded_label %||% "Excluded",
    unresolved_label = h$unresolved_label %||% "Unresolved",
    version = h$version %||% NA_character_,
    rationale = h$rationale %||% ""
  )
  overrides <- lapply(x$overrides %||% list(), function(o) {
    gk_override(
      image_id = o$image_id, marker = o$marker, parent = o$parent %||% NA_character_,
      threshold_method = o$threshold_method,
      threshold_args = if (is.null(o$threshold_args)) NULL else .gk_list_args(o$threshold_args),
      reason = o$reason %||% ""
    )
  })
  refinements <- lapply(x$refinements %||% list(), function(r) {
    gk_refinement(r$rule_id, r$marker, r$parent, r$from_label, r$to_label)
  })
  parent_sets <- lapply(x$parent_sets %||% list(), function(p) as.character(unlist(p)))
  .gk_build_config(
    signal_policy = policy, panel = panel, parent_sets = parent_sets,
    hierarchy = hierarchy, overrides = overrides, refinements = refinements, call = call
  )
}

#' Read and write configuration files
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' `gk_write_config()` writes a configuration as pretty-printed canonical JSON
#' (sorted keys) following `inst/schema/gatekeepr-config-1.0.0.schema.json`.
#' `gk_read_config()` parses a file with `jsonlite` (no code is evaluated),
#' rebuilds the configuration through the constructors and aborts with a
#' `gatekeepr_error_config` listing every failed check.
#'
#' @param config A [gk_config()].
#' @param path File path.
#'
#' @return `gk_write_config()` returns `config` invisibly; `gk_read_config()`
#'   returns a `gk_config`.
#'
#' @examples
#' path <- tempfile(fileext = ".json")
#' gk_write_config(gk_example_config(), path)
#' cfg <- gk_read_config(path)
#' identical(gk_config_hash(cfg), gk_config_hash(gk_example_config()))
#' unlink(path)
#'
#' @family configuration
#' @export
gk_write_config <- function(config, path) {
  .gk_check_class(config, "gk_config")
  .gk_check_string(path)
  parent <- dirname(path)
  if (!dir.exists(parent)) {
    dir.create(parent, recursive = TRUE, showWarnings = FALSE)
  }
  .gk_write_json(.gk_config_to_list(config), path, pretty = TRUE)
  invisible(config)
}

#' @rdname gk_write_config
#' @export
gk_read_config <- function(path) {
  .gk_check_file_exists(path)
  x <- .gk_read_json(path)
  config <- .gk_config_from_list(x)
  .gk_assert_config(config)
}
