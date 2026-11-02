# File input/output helpers: exact TSV round trips, atomic writes, local seeds.

# Parse decimal doubles with jsonlite's correctly rounded parser. R's decimal
# conversion and fread can differ by ULPs on some platforms; those changes can
# alter a call at a threshold. Nonfinite TSV spellings are handled explicitly.
.gk_parse_double <- function(x, allow_overflow = FALSE) {
  out <- rep(NA_real_, length(x))
  out[!is.na(x) & x == "Inf"] <- Inf
  out[!is.na(x) & x == "-Inf"] <- -Inf
  finite <- !is.na(x) & !x %in% c("NA", "NaN", "Inf", "-Inf")
  if (any(finite)) {
    values <- x[finite]
    valid <- grepl("^-?(0|[1-9][0-9]*)(\\.[0-9]+)?([eE][+-]?[0-9]+)?$", values)
    if (!all(valid)) .gk_abort("Invalid numeric value in table.", class = "input")
    parsed <- jsonlite::fromJSON(paste0("[", paste(values, collapse = ","), "]"))
    if (!allow_overflow && any(!is.finite(parsed)))
      .gk_abort("Numeric value exceeds double range.", class = "input")
    out[finite] <- parsed
  }
  out
}

.gk_parse_integer <- function(x) {
  present <- !is.na(x)
  if (any(!grepl("^-?(0|[1-9][0-9]*)$", x[present])))
    .gk_abort("Invalid integer value in table.", class = "input")
  values <- .gk_parse_double(x)
  if (any(abs(values[present]) > .Machine$integer.max))
    .gk_abort("Integer value exceeds supported range.", class = "input")
  as.integer(values)
}

.gk_parse_logical <- function(x) {
  if (any(!is.na(x) & !x %in% c("TRUE", "FALSE")))
    .gk_abort("Invalid logical value in table.", class = "input")
  as.logical(x)
}

# Short decimal representation that reads back to the identical double using
# the same correctly rounded parser as the TSV reader.
.gk_format_double <- function(x) {
  x <- as.double(x)
  out <- sprintf("%.15g", x)
  fin <- is.finite(x)
  back <- .gk_parse_double(out, allow_overflow = TRUE)
  bad <- fin & (is.na(back) | back != x)
  for (digits in c(17L, 20L, 22L, 25L, 30L)) {
    if (!any(bad)) break
    out[bad] <- sprintf(paste0("%.", digits, "g"), x[bad])
    back[bad] <- .gk_parse_double(out[bad], allow_overflow = TRUE)
    bad <- fin & (is.na(back) | back != x)
  }
  if (any(bad)) .gk_abort("Could not represent table values without numerical loss.", class = "input")
  out[is.na(x)] <- "NA"
  out[x %in% Inf] <- "Inf"
  out[x %in% -Inf] <- "-Inf"
  out
}

# Write a data.frame as UTF-8 TSV (gzip when the path ends in .gz). Double
# columns are formatted exactly; logical columns as TRUE/FALSE; NA as "NA".
.gk_write_tsv <- function(df, path) {
  df <- as.data.frame(df, stringsAsFactors = FALSE)
  out <- lapply(df, function(col) {
    if (is.double(col)) {
      .gk_format_double(col)
    } else if (is.factor(col)) {
      as.character(col)
    } else {
      col
    }
  })
  out <- data.table::as.data.table(out)
  data.table::setnames(out, names(df))
  compress <- if (grepl("\\.gz$", path)) "gzip" else "none"
  data.table::fwrite(
    out, path,
    sep = "\t", na = "NA", quote = "auto", compress = compress,
    showProgress = FALSE, eol = "\n", bom = FALSE
  )
  invisible(path)
}

# Read a TSV written by .gk_write_tsv(). `types` is a named character vector
# mapping column names to "character", "double", "integer" or "logical";
# unnamed columns stay character. Doubles use the correctly rounded JSON
# number parser, retaining an exact round trip for threshold replay.
.gk_read_tsv <- function(path, types = character()) {
  fread_args <- list(
    sep = "\t", colClasses = "character", na.strings = "NA",
    encoding = "UTF-8", showProgress = FALSE, strip.white = FALSE,
    quote = "\""
  )
  if (grepl("\\.gz$", path)) {
    con <- gzfile(path, open = "rt", encoding = "UTF-8")
    on.exit(close(con), add = TRUE)
    txt <- paste(readLines(con, warn = FALSE), collapse = "\n")
    dt <- do.call(data.table::fread, c(list(text = txt), fread_args))
  } else {
    dt <- do.call(data.table::fread, c(list(input = path), fread_args))
  }
  df <- as.data.frame(dt, stringsAsFactors = FALSE)
  # data.table preserves doubled quotes in quoted fields when all columns are
  # requested as character. Decode the RFC 4180 representation used by
  # fwrite so JSON-valued fields round trip byte-for-byte.
  for (j in which(vapply(df, is.character, logical(1)))) {
    df[[j]] <- gsub('""', '"', df[[j]], fixed = TRUE)
  }
  for (nm in intersect(names(types), names(df))) {
    df[[nm]] <- switch(types[[nm]],
      double = .gk_parse_double(df[[nm]]),
      integer = .gk_parse_integer(df[[nm]]),
      logical = .gk_parse_logical(df[[nm]]),
      df[[nm]]
    )
  }
  df
}

# Write text through a temporary file in the same directory, then rename, so
# readers never see a half-written file.
.gk_write_atomic <- function(path, writer) {
  dir <- dirname(path)
  tmp <- tempfile(pattern = paste0(".", basename(path), "-"), tmpdir = dir)
  on.exit(unlink(tmp), add = TRUE)
  writer(tmp)
  if (!file.rename(tmp, path)) {
    ok <- file.copy(tmp, path, overwrite = TRUE)
    if (!ok) {
      .gk_abort("Could not write {.path {path}}.", class = "input")
    }
  }
  invisible(path)
}

.gk_write_json <- function(x, path, pretty = TRUE) {
  txt <- .gk_to_json(x, pretty = pretty)
  .gk_write_atomic(path, function(tmp) {
    con <- file(tmp, open = "wb")
    on.exit(close(con), add = TRUE)
    writeBin(charToRaw(enc2utf8(paste0(txt, "\n"))), con)
  })
}

.gk_read_json <- function(path, tolerate_trailing = FALSE,
                          call = rlang::caller_env()) {
  txt <- tryCatch(
    suppressWarnings(paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")),
    error = function(e) {
      .gk_abort(
        c("Could not read {.path {path}}.", "x" = conditionMessage(e)),
        class = "input", call = call
      )
    }
  )
  parsed <- tryCatch(
    jsonlite::fromJSON(txt, simplifyVector = FALSE),
    error = identity
  )
  if (!inherits(parsed, "error")) {
    return(parsed)
  }
  if (isTRUE(tolerate_trailing)) {
    valid <- jsonlite::validate(txt)
    offset <- attr(valid, "offset")
    if (isFALSE(valid) && length(offset) == 1L && is.finite(offset)) {
      prefix <- trimws(substr(txt, 1L, offset - 1L))
      parsed <- tryCatch(
        jsonlite::fromJSON(prefix, simplifyVector = FALSE),
        error = identity
      )
      if (!inherits(parsed, "error")) {
        return(parsed)
      }
    }
  }
  .gk_abort(
    c(
      "{.path {path}} is not valid JSON.",
      "x" = .gk_cli_escape(conditionMessage(parsed))
    ),
    class = "input", call = call
  )
}

# Evaluate `code` with a fixed seed and the default RNG kinds, then restore
# the caller's RNG state (like withr::with_seed, without the dependency).
.gk_with_seed <- function(seed, code) {
  env <- globalenv()
  had_seed <- exists(".Random.seed", envir = env, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = env) else NULL
  old_kind <- RNGkind()
  on.exit({
    RNGkind(old_kind[[1L]], old_kind[[2L]], old_kind[[3L]])
    if (had_seed) {
      assign(".Random.seed", old_seed, envir = env)
    } else if (exists(".Random.seed", envir = env, inherits = FALSE)) {
      rm(".Random.seed", envir = env)
    }
  }, add = TRUE)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(seed)
  force(code)
}

.gk_utc_now <- function() {
  format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
}

.gk_package_version <- function(pkg = "gatekeepR") {
  v <- tryCatch(as.character(utils::packageVersion(pkg)), error = function(e) NA_character_)
  v
}
