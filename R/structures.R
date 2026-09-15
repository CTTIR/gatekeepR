# Spatial clusters that make structure-review cells reviewable as units.

.gk_structure_eps <- function(coords, eps_min, eps_max, min_pts) {
  if (nrow(coords) < 2L) return(eps_max)
  k <- min(max(1L, as.integer(min_pts) - 1L), nrow(coords) - 1L)
  distances <- dbscan::kNNdist(coords, k = k)
  q <- stats::quantile(distances, 0.95, names = FALSE, type = 7)
  min(eps_max, max(eps_min, q))
}

#' Find epithelial structures for review
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Runs deterministic centroid-based DBSCAN on cells awaiting a configured
#' structure decision. Epsilon is the 95th percentile of the `(min_pts - 1)`th
#' nearest-neighbour distance, bounded by `eps_min` and `eps_max`. Retained
#' structures are ordered by decreasing size and then centroid coordinates,
#' making IDs stable under input row permutation.
#'
#' @param classification A [gk_classify()] result.
#' @param prepared The matching [gk_prepare()] result.
#' @param eps_min,eps_max Lower and upper bounds for DBSCAN epsilon in the
#'   coordinate units of the cellspec.
#' @param min_pts DBSCAN minimum points.
#' @param min_cells Minimum cells for an exported structure.
#'
#' @return An object of class `gk_structures` with `structures`, `cell_structure`,
#'   parameters and provenance hashes.
#'
#' @examples
#' prep <- gk_prepare(gk_example_path("example-slide"), gk_example_config(), quiet = TRUE)
#' th <- gk_thresholds(prep, gk_example_config(), seed = 1L)
#' cl <- gk_classify(prep, th, gk_example_config())
#' if (requireNamespace("dbscan", quietly = TRUE)) gk_structures(cl, prep)
#'
#' @family classification
#' @export
gk_structures <- function(classification, prepared, eps_min = 15, eps_max = 30,
                          min_pts = 10L, min_cells = 20L) {
  .gk_check_class(classification, "gk_classification")
  .gk_check_class(prepared, "gk_prepared")
  .gk_check_number(eps_min, min = 0)
  .gk_check_number(eps_max, min = eps_min)
  min_pts <- .gk_check_count(min_pts, min = 2L)
  min_cells <- .gk_check_count(min_cells, min = 1L)
  .gk_require("dbscan", "gk_structures")
  if (!identical(classification$source_sha256, prepared$source_sha256)) {
    .gk_abort("{.arg classification} does not match the prepared data.", class = "state")
  }
  pending <- classification$cells$pending_review
  cell_structure <- data.frame(
    image_id = prepared$cells$image_id, cell_id = prepared$cells$cell_id,
    structure_id = NA_character_, stringsAsFactors = FALSE
  )
  structure_rows <- list()
  eps_by_image <- list()
  for (img in unique(prepared$cells$image_id)) {
    idx <- which(prepared$cells$image_id == img & pending)
    coords <- as.matrix(prepared$cells[idx, c("x", "y"), drop = FALSE])
    keep <- vapply(seq_len(nrow(coords)), function(i) all(is.finite(coords[i, ])), logical(1))
    idx <- idx[keep]
    coords <- coords[keep, , drop = FALSE]
    eps <- .gk_structure_eps(coords, eps_min, eps_max, min_pts)
    eps_by_image[[img]] <- eps
    if (nrow(coords) == 0L) next
    fit <- dbscan::dbscan(coords, eps = eps, minPts = min_pts)
    clusters <- sort(unique(fit$cluster[fit$cluster > 0L]))
    tab <- table(fit$cluster)
    clusters <- clusters[as.integer(tab[as.character(clusters)]) >= min_cells]
    if (length(clusters) == 0L) next
    stats <- lapply(clusters, function(cluster) {
      xy <- coords[fit$cluster == cluster, , drop = FALSE]
      data.frame(
        cluster = cluster, n_cells = nrow(xy), centroid_x = mean(xy[, 1L]),
        centroid_y = mean(xy[, 2L]), xmin = min(xy[, 1L]), xmax = max(xy[, 1L]),
        ymin = min(xy[, 2L]), ymax = max(xy[, 2L]), stringsAsFactors = FALSE
      )
    })
    stat <- do.call(rbind, stats)
    stat <- stat[order(-stat$n_cells, stat$centroid_x, stat$centroid_y), , drop = FALSE]
    stat$structure_id <- sprintf("E%02d", seq_len(nrow(stat)))
    stat$image_id <- img
    stat$decision <- NA_character_
    cluster_to_id <- stats::setNames(stat$structure_id, stat$cluster)
    stat <- stat[, c("image_id", "structure_id", "n_cells", "centroid_x",
      "centroid_y", "xmin", "xmax", "ymin", "ymax", "decision")]
    structure_rows[[length(structure_rows) + 1L]] <- stat
    mapped <- unname(cluster_to_id[as.character(fit$cluster)])
    cell_structure$structure_id[idx] <- mapped
  }
  structures <- if (length(structure_rows)) do.call(rbind, structure_rows) else {
    data.frame(image_id = character(), structure_id = character(), n_cells = integer(),
      centroid_x = double(), centroid_y = double(), xmin = double(), xmax = double(),
      ymin = double(), ymax = double(), decision = character(), stringsAsFactors = FALSE)
  }
  rownames(structures) <- NULL
  structure(
    list(
      structures = structures, cell_structure = cell_structure,
      eps = eps_by_image, parameters = list(eps_min = eps_min, eps_max = eps_max,
        min_pts = min_pts, min_cells = min_cells), classification = classification,
      prepared = prepared, config_sha256 = prepared$config_sha256,
      source_sha256 = prepared$source_sha256
    ),
    class = "gk_structures"
  )
}

#' @export
print.gk_structures <- function(x, ...) {
  cli::cli_text("{.cls gk_structures}: {nrow(x$structures)} structure{?s}")
  if (nrow(x$structures)) print(x$structures, row.names = FALSE)
  invisible(x)
}
