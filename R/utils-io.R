# File input/output helpers: exact TSV round trips, atomic writes, local seeds.

# Short decimal representation that reads back to the identical double on
# platforms whose C libraries use slightly different decimal conversion.
# data.table::fwrite() writes 15 significant digits, which does not round-trip;
# exported scores must, because verification replays calls from them.
.gk_format_double <- function(x) {
  x <- as.double(x)
  out <- sprintf("%.15g", x)
  fin <- is.finite(x)
  back <- suppressWarnings(as.double(out))
  bad <- fin & (is.na(back) | back != x)
  for (digits in c(17L, 20L, 22L)) {
    if (!any(bad)) break
    out[bad] <- sprintf(paste0("%.", digits, "g"), x[bad])
    back[bad] <- suppressWarnings(as.double(out[bad]))
    bad <- fin & (is.na(back) | back != x)
  }
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
# unnamed columns stay character. Doubles are parsed with R's strtod so the
# round trip is exact.
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
      double = suppressWarnings(as.double(df[[nm]])),
      integer = suppressWarnings(as.integer(df[[nm]])),
      logical = as.logical(df[[nm]]),
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
