# PCA, UMAP and density basins used by population-based threshold methods.

.gk_embedding_matrix <- function(prepared, correction) {
  score <- if (is.null(correction)) {
    prepared$score
  } else if (inherits(correction, "gk_corrected")) {
    correction$matrix
  } else if (is.list(correction) && is.matrix(correction$matrix)) {
    correction$matrix
  } else {
    .gk_abort(
      "{.arg correction} must be the result of {.fn gk_correct}.",
      class = "input"
    )
  }
  markers <- prepared$config$panel$markers$marker[
    prepared$config$panel$markers$role %in% .gk_gating_roles
  ]
  callable <- .gk_correction_callable(prepared, markers)
  markers <- markers[callable]
  if (length(markers) == 0L) {
    .gk_abort(
      c(
        "No callable identity markers are available for the embedding.",
        "i" = "Check {.fn gk_callability} or supply a slide with signal."
      ),
      class = "state"
    )
  }
  x <- score[, markers, drop = FALSE]
  for (j in seq_len(ncol(x))) {
    bad <- !is.finite(x[, j])
    if (any(bad)) {
      x[bad, j] <- stats::median(x[, j], na.rm = TRUE)
    }
  }
  list(matrix = x, markers = markers)
}

.gk_embedding_kde <- function(umap, grid, bg) {
  x <- umap[, 1L]
  y <- umap[, 2L]
  lims <- c(range(x), range(y))
  if (lims[[2L]] <= lims[[1L]]) lims[1:2] <- lims[1:2] + c(-0.5, 0.5)
  if (lims[[4L]] <= lims[[3L]]) lims[3:4] <- lims[3:4] + c(-0.5, 0.5)
  bandwidth <- c(MASS::bandwidth.nrd(x), MASS::bandwidth.nrd(y))
  bandwidth[!is.finite(bandwidth) | bandwidth <= 0] <- 1
  kde <- MASS::kde2d(x, y, n = grid, h = bandwidth, lims = lims)
  maximum <- max(kde$z, na.rm = TRUE)
  density <- if (is.finite(maximum) && maximum > 0) kde$z / maximum else kde$z * 0
  density[!is.finite(density) | density < bg] <- 0
  list(x = kde$x, y = kde$y, density = density, bandwidth = bandwidth)
}

.gk_grid_neighbours <- function(index, nrow, ncol) {
  row <- ((index - 1L) %% nrow) + 1L
  col <- ((index - 1L) %/% nrow) + 1L
  rr <- max(1L, row - 1L):min(nrow, row + 1L)
  cc <- max(1L, col - 1L):min(ncol, col + 1L)
  as.vector(outer(rr - 1L, cc - 1L, function(r, c) r + c * nrow) + 1L)
}

.gk_hillclimb_basins <- function(density) {
  nr <- nrow(density)
  nc <- ncol(density)
  values <- as.vector(density)
  labels <- rep(NA_integer_, length(values))
  maxima <- integer()
  for (start in which(values > 0)) {
    current <- start
    repeat {
      neighbours <- .gk_grid_neighbours(current, nr, nc)
      higher <- neighbours[values[neighbours] > values[current]]
      if (length(higher) == 0L) break
      current <- higher[which.max(values[higher])]
    }
    if (!current %in% maxima) maxima <- c(maxima, current)
    labels[start] <- match(current, maxima)
  }
  list(labels = matrix(labels, nr, nc), maxima = maxima)
}

.gk_watershed_basins <- function(kde, method, tolerance) {
  if (identical(method, "hillclimb")) {
    return(.gk_hillclimb_basins(kde$density))
  }
  .gk_require("EBImage", "The EBImage basin method")
  image <- EBImage::as.Image(kde$density)
  segmentation <- EBImage::watershed(image, tolerance = tolerance, ext = 1)
  labels <- EBImage::imageData(segmentation)
  list(labels = as.matrix(labels), maxima = sort(unique(as.vector(labels))))
}

.gk_assign_basins <- function(umap, kde, basins, small_basins, min_abs, min_frac) {
  nr <- nrow(basins$labels)
  nc <- ncol(basins$labels)
  ix <- pmin(pmax(findInterval(umap[, 1L], kde$x), 1L), nr)
  iy <- pmin(pmax(findInterval(umap[, 2L], kde$y), 1L), nc)
  raw <- as.integer(basins$labels[cbind(ix, iy)])
  raw[!is.finite(raw) | raw <= 0] <- NA_integer_
  counts <- table(raw, useNA = "no")
  threshold <- max(as.integer(min_abs), ceiling(min_frac * nrow(umap)))
  keep <- as.integer(names(counts)[counts >= threshold])
  if (length(keep) == 0L && length(counts) > 0L) {
    keep <- as.integer(names(counts)[which.max(counts)])
  }
  centres <- if (length(keep) > 0L) {
    t(vapply(keep, function(id) {
      colMeans(umap[raw == id, , drop = FALSE])
    }, numeric(2)))
  } else {
    matrix(numeric(), ncol = 2L)
  }
  result <- rep(NA_integer_, length(raw))
  if (length(keep) > 0L) {
    remap <- stats::setNames(seq_along(keep), keep)
    retained <- raw %in% keep
    result[retained] <- unname(remap[as.character(raw[retained])])
    small <- which(!retained & is.finite(raw))
    if (identical(small_basins, "merge") && length(small) > 0L) {
      result[small] <- vapply(small, function(i) {
        which.min(rowSums((centres -
          matrix(umap[i, ], nrow(centres), 2L, byrow = TRUE))^2))
      }, integer(1))
    }
  }
  list(
    population = result,
    raw_population = raw,
    centres = centres,
    threshold = threshold,
    retained_basins = keep,
    small_basins = which(!raw %in% keep & is.finite(raw))
  )
}

#' Compute a reproducible marker embedding and density populations
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Computes a sign-canonicalised PCA, a deterministic two-dimensional UMAP,
#' and density basins used by `population_crossing` thresholds. The default
#' basin implementation is pure R. `small_basins = "uncertain"` retains cells
#' while assigning their population as `NA`; `"merge"` assigns them to the
#' nearest retained basin.
#'
#' @param prepared A [gk_prepare()] result.
#' @param correction `NULL` or a [gk_correct()] result.
#' @param n_pcs Number of principal components to retain.
#' @param n_neighbors UMAP neighbourhood size.
#' @param min_dist UMAP minimum distance.
#' @param grid Number of KDE grid points in each dimension.
#' @param bg Relative density below which KDE cells are background.
#' @param tolerance Basin merge or watershed tolerance.
#' @param basin_method `"hillclimb"` or optional `"ebimage"`.
#' @param small_basins Whether small basins become uncertain or merge.
#' @param min_abs Minimum cells for a retained basin.
#' @param min_frac Minimum fraction for a retained basin.
#' @param seed Random seed used by UMAP.
#'
#' @return An object of class `gk_embedding` with `pca`, `umap`,
#'   `population`, KDE data, basin information, parameters and provenance
#'   hashes.
#'
#' @examples
#' if (requireNamespace("uwot", quietly = TRUE)) {
#'   prep <- gk_prepare(gk_example_path("example-slide"), gk_example_config(), quiet = TRUE)
#'   emb <- gk_embed(prep, n_pcs = 3L, grid = 40L, seed = 7L)
#'   emb
#' }
#'
#' @family thresholds
#' @export
gk_embed <- function(prepared, correction = NULL, n_pcs = 10L,
                     n_neighbors = 20L, min_dist = 0.15, grid = 400L,
                     bg = 0.03, tolerance = 0.03,
                     basin_method = c("hillclimb", "ebimage"),
                     small_basins = c("uncertain", "merge"), min_abs = 30L,
                     min_frac = 0.002, seed = 42L) {
  .gk_check_class(prepared, "gk_prepared")
  n_pcs <- .gk_check_count(n_pcs, min = 1L)
  n_neighbors <- .gk_check_count(n_neighbors, min = 2L)
  min_dist <- .gk_check_number(min_dist, min = 0)
  grid <- .gk_check_count(grid, min = 10L)
  bg <- .gk_check_number(bg, min = 0, max = 1)
  tolerance <- .gk_check_number(tolerance, min = 0)
  basin_method <- rlang::arg_match(basin_method)
  small_basins <- rlang::arg_match(small_basins)
  min_abs <- .gk_check_count(min_abs, min = 1L)
  .gk_check_number(min_frac, min = 0, max = 1)
  seed <- .gk_check_count(seed)
  .gk_require("uwot", "gk_embed")
  input <- .gk_embedding_matrix(prepared, correction)
  x <- input$matrix
  n_neighbors <- min(n_neighbors, nrow(x) - 1L)
  pca <- if (ncol(x) == 1L) {
    z <- x[, 1L] - mean(x[, 1L])
    structure(list(x = matrix(z, ncol = 1L, dimnames = list(NULL, "PC1")),
      rotation = matrix(1, nrow = 1L, dimnames = list(colnames(x), "PC1")),
      center = mean(x[, 1L]), scale = FALSE), class = "prcomp")
  } else {
    ncomp <- min(n_pcs, ncol(x), nrow(x) - 1L)
    .gk_canonicalize_pca(stats::prcomp(x, center = TRUE, scale. = FALSE,
      rank. = ncomp
    ))
  }
  pc <- pca$x[, seq_len(min(n_pcs, ncol(pca$x))), drop = FALSE]
  if (nrow(pc) < 4L) {
    .gk_abort("At least four cells are needed for an embedding.", class = "input")
  }
  umap <- .gk_with_seed(seed, uwot::umap(
    pc, n_neighbors = n_neighbors, min_dist = min_dist, n_components = 2L,
    init = "spectral", n_threads = 1L, n_sgd_threads = 1L,
    fast_sgd = FALSE, seed = seed, verbose = FALSE
  ))
  umap <- as.matrix(umap)
  colnames(umap) <- c("UMAP1", "UMAP2")
  rownames(umap) <- prepared$cells$cell_id
  kde <- .gk_embedding_kde(umap, grid, bg)
  basins <- .gk_watershed_basins(kde, basin_method, tolerance)
  assigned <- .gk_assign_basins(
    umap, kde, basins, small_basins, min_abs, min_frac
  )
  names(assigned$population) <- prepared$cells$cell_id
  structure(
    list(
      pca = pca, umap = umap, population = assigned$population,
      raw_population = assigned$raw_population,
      population_centres = assigned$centres, kde = kde,
      basin_labels = basins$labels, threshold = assigned$threshold,
      retained_basins = assigned$retained_basins,
      small_basin_cells = assigned$small_basins,
      markers = input$markers,
      parameters = list(
        n_pcs = n_pcs, n_neighbors = n_neighbors, min_dist = min_dist,
        grid = grid, bg = bg, tolerance = tolerance,
        basin_method = basin_method, small_basins = small_basins,
        min_abs = min_abs, min_frac = min_frac, seed = seed,
        uwot_version = .gk_package_version("uwot")
      ),
      config_sha256 = prepared$config_sha256,
      source_sha256 = prepared$source_sha256,
      created_utc = .gk_utc_now()
    ),
    class = "gk_embedding"
  )
}

#' @export
print.gk_embedding <- function(x, ...) {
  tab <- table(x$population, useNA = "ifany")
  cli::cli_text(
    "{.cls gk_embedding}: {nrow(x$umap)} cells, {length(x$markers)} markers, ",
    "{length(tab)} population{?s}"
  )
  cli::cli_bullets(c(
    "*" = "Basin method: {.val {x$parameters$basin_method}}; threshold: {x$threshold}",
    "*" = "Small basin handling: {.val {x$parameters$small_basins}}",
    "*" = "Populations: {.val {paste(names(tab), as.integer(tab), sep = '=', collapse = ', ')}}"
  ))
  invisible(x)
}
