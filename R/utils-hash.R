# Canonical JSON and hashing.
#
# Hashes are computed over canonical JSON: object keys sorted (C locale),
# no insignificant whitespace, numbers written in their shortest round-trip
# form, whole numbers without a decimal point. The same R value therefore
# always hashes identically, whatever key order, whitespace or numeric
# spelling (1 vs 1.0 vs 1e0) the JSON it was read from used.
#
# Array/scalar ambiguity: an atomic vector of length 1 is written as a scalar
# unless it is wrapped in I(), which forces an array. Normalised objects
# (e.g. configurations) wrap every array-valued field in I().

.gk_json_number <- function(x) {
  out <- character(length(x))
  na <- is.na(x)
  out[na] <- "null"
  ok <- !na
  if (any(ok & !is.finite(x))) {
    .gk_abort("Cannot write a non-finite number to JSON.", class = "input")
  }
  v <- x[ok]
  whole <- v == trunc(v) & abs(v) < 2^53
  s <- character(length(v))
  s[whole] <- sprintf("%.0f", v[whole])
  s[!whole] <- .gk_format_double(v[!whole])
  s[s == "-0"] <- "0"
  out[ok] <- s
  out
}

.gk_json_string <- function(x) {
  out <- rep("null", length(x))
  ok <- !is.na(x)
  if (any(ok)) {
    enc <- enc2utf8(x[ok])
    out[ok] <- vapply(
      enc,
      function(s) as.character(jsonlite::toJSON(s, auto_unbox = TRUE)),
      character(1),
      USE.NAMES = FALSE
    )
  }
  out
}

.gk_json_atomic <- function(x) {
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (is.logical(x)) {
    s <- ifelse(is.na(x), "null", ifelse(x, "true", "false"))
  } else if (is.numeric(x)) {
    s <- .gk_json_number(as.double(x))
  } else if (is.character(x)) {
    s <- .gk_json_string(x)
  } else {
    .gk_abort(
      "Cannot write an object of type {.cls {typeof(x)}} to JSON.",
      class = "input"
    )
  }
  s
}

.gk_json_indent <- function(level, pretty) {
  if (pretty) strrep("  ", level) else ""
}

.gk_to_json <- function(x, pretty = FALSE, level = 0L) {
  nl <- if (pretty) "\n" else ""
  sep <- if (pretty) ": " else ":"
  if (is.null(x)) {
    return("null")
  }
  if (is.factor(x)) {
    x <- as.character(x)
  }
  if (is.data.frame(x)) {
    x <- .gk_df_to_rows(x)
  }
  if (is.list(x)) {
    nms <- names(x)
    named <- !is.null(nms) || inherits(x, "gk_json_object")
    if (length(x) == 0L) {
      return(if (named) "{}" else "[]")
    }
    inner <- .gk_json_indent(level + 1L, pretty)
    outer <- .gk_json_indent(level, pretty)
    if (named) {
      if (anyNA(nms) || any(!nzchar(nms)) || anyDuplicated(nms)) {
        .gk_abort("JSON object keys must be unique and non-empty.", class = "input")
      }
      ord <- order(nms, method = "radix")
      parts <- vapply(ord, function(i) {
        paste0(
          inner, .gk_json_string(nms[[i]]), sep,
          .gk_to_json(x[[i]], pretty = pretty, level = level + 1L)
        )
      }, character(1))
      return(paste0("{", nl, paste(parts, collapse = paste0(",", nl)), nl, outer, "}"))
    }
    parts <- vapply(x, function(el) {
      paste0(inner, .gk_to_json(el, pretty = pretty, level = level + 1L))
    }, character(1))
    return(paste0("[", nl, paste(parts, collapse = paste0(",", nl)), nl, outer, "]"))
  }
  force_array <- inherits(x, "AsIs")
  x <- unclass(x)
  attributes(x) <- NULL
  s <- .gk_json_atomic(x)
  if (!force_array && length(s) == 1L) {
    return(s)
  }
  if (length(s) == 0L) {
    return("[]")
  }
  if (pretty && length(s) > 0L) {
    return(paste0("[", paste(s, collapse = ", "), "]"))
  }
  paste0("[", paste(s, collapse = ","), "]")
}

# A data.frame becomes an array of row objects (column order irrelevant,
# because keys are sorted).
.gk_df_to_rows <- function(df) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  lapply(seq_len(nrow(df)), function(i) {
    row <- lapply(df, function(col) {
      v <- col[[i]]
      if (is.factor(v)) as.character(v) else v
    })
    names(row) <- names(df)
    row
  })
}

.gk_canonical_json <- function(x) {
  .gk_to_json(x, pretty = FALSE)
}

.gk_sha256_string <- function(x) {
  digest::digest(enc2utf8(x), algo = "sha256", serialize = FALSE)
}

.gk_sha256_file <- function(path) {
  digest::digest(file = path, algo = "sha256", serialize = FALSE)
}

.gk_sha256_object <- function(x) {
  .gk_sha256_string(.gk_canonical_json(x))
}

# Content hash of numeric matrices and identifier vectors, independent of R's
# serialisation format (which embeds the R version). Doubles are hashed as
# little-endian IEEE-754 bytes, strings as UTF-8 joined by newlines.
.gk_sha256_data <- function(...) {
  parts <- list(...)
  hashes <- vapply(parts, function(p) {
    if (is.null(p)) {
      return("null")
    }
    if (is.matrix(p) || is.numeric(p)) {
      dims <- paste(c(dim(p) %||% length(p), colnames(p)), collapse = "|")
      if (is.integer(p)) {
        bytes <- writeBin(as.integer(p), raw(), endian = "little")
      } else {
        bytes <- writeBin(as.double(p), raw(), endian = "little")
      }
      return(paste0(
        .gk_sha256_string(dims), ":",
        digest::digest(bytes, algo = "sha256", serialize = FALSE)
      ))
    }
    if (is.logical(p)) {
      v <- ifelse(is.na(p), 2L, as.integer(p))
      return(digest::digest(writeBin(v, raw(), endian = "little"),
        algo = "sha256", serialize = FALSE
      ))
    }
    v <- as.character(p)
    v[is.na(v)] <- "NA"
    .gk_sha256_string(paste(v, collapse = "\n"))
  }, character(1))
  .gk_sha256_string(paste(hashes, collapse = ";"))
}

#' Short display form of a SHA-256 based identifier
#' @noRd
.gk_short_hash <- function(x, n = 12L) {
  substr(x, 1L, n)
}
