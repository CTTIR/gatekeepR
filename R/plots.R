# ggplot2 views over the same objects used by the batch and review paths.

#' @importFrom rlang .data
.gk_plot_require <- function() .gk_require("ggplot2", "gatekeepR plots")

.gk_plot_match_cells <- function(query, reference) {
  query <- .gk_cell_keys(query)
  reference <- .gk_cell_keys(reference)
  if (anyNA(query) || anyNA(reference) || anyDuplicated(query) || anyDuplicated(reference))
    .gk_abort("Plot inputs need unique image and cell identity pairs.", class = "state")
  index <- match(.gk_cell_key(query), .gk_cell_key(reference))
  if (length(index) != nrow(query) || anyNA(index))
    .gk_abort("Plot inputs contain different image and cell identities.", class = "state")
  index
}

#' Plot a threshold density and its evidence pools
#'
#' @param thresholds A gk_thresholds() result.
#' @param marker Marker to plot.
#' @param image_id Image to plot.
#' @param parent Parent set for a state threshold; NA for identity markers.
#' @return A ggplot object.
#' @family plots
#' @export
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' cfg <- gk_example_config()
#' prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), cfg, quiet = TRUE)
#' thresholds <- gk_thresholds(prep, cfg, seed = 7L)
#' gk_plot_density(thresholds, marker = "CD3e", image_id = "sim-01")
gk_plot_density <- function(thresholds, marker, image_id, parent = NA_character_) {
  .gk_plot_require()
  .gk_check_class(thresholds, "gk_thresholds")
  .gk_check_string(marker); .gk_check_string(image_id)
  hit <- .gk_threshold_row(thresholds, image_id, marker, parent)
  if (length(hit) != 1L) .gk_abort("No unique threshold result matches the requested marker and image.", class = "input")
  row <- thresholds[hit, , drop = FALSE]
  evidence_all <- attr(thresholds, "evidence")
  evidence <- if (!is.null(evidence_all) && !is.na(row$evidence_ref[[1L]])) {
    evidence_all[[row$evidence_ref[[1L]]]]
  } else {
    NULL
  }
  density_rows <- function(values, pool) {
    values <- values[is.finite(values)]
    if (length(values) < 2L) return(NULL)
    d <- stats::density(values)
    data.frame(value = d$x, density = d$y, pool = pool)
  }
  curves <- list()
  if (length(evidence$grid) && length(evidence$grid) == length(evidence$density)) {
    curves[["pooled"]] <- data.frame(value = evidence$grid,
      density = evidence$density, pool = "All observations")
  } else if (length(evidence$values)) {
    curves[["pooled"]] <- density_rows(evidence$values, "All observations")
  }
  curves[["positive"]] <- density_rows(evidence$positive_values, "Positive pool")
  curves[["negative"]] <- density_rows(evidence$negative_values, "Negative pool")
  dat <- if (length(curves)) do.call(rbind, curves) else
    data.frame(value = numeric(), density = numeric(), pool = character())
  p <- ggplot2::ggplot(dat, ggplot2::aes(x = .data[["value"]], y = .data[["density"]], colour = .data[["pool"]])) +
    ggplot2::geom_line(na.rm = TRUE) +
    ggplot2::labs(x = marker, y = "Density", title = paste(image_id, marker),
      subtitle = paste(row$status, row$method), caption = row$details, colour = "Evidence")
  if (!nrow(dat)) p <- p + ggplot2::annotate("text", x = if (is.finite(row$estimate[[1L]])) row$estimate[[1L]] else 0,
    y = 0, label = "No density evidence retained", vjust = -1)
  if (is.finite(row$estimate[[1L]])) p <- p + ggplot2::geom_vline(xintercept = row$estimate[[1L]], linetype = 2)
  p
}

#' Plot an embedding coloured by population or classification
#'
#' @param embedding A gk_embed() result.
#' @param classification Optional gk_classify() result.
#' @param colour_by Column in classification cells, or population.
#' @return A ggplot object.
#' @family plots
#' @export
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE) && requireNamespace("uwot", quietly = TRUE)
#' prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), gk_example_config(), quiet = TRUE)
#' embedding <- gk_embed(prep, n_pcs = 3L, grid = 40L, seed = 7L)
#' gk_plot_embedding(embedding)
gk_plot_embedding <- function(embedding, classification = NULL, colour_by = "population") {
  .gk_plot_require()
  .gk_check_class(embedding, "gk_embedding")
  dat <- data.frame(embedding$umap, population = as.character(embedding$population),
    cell_id = rownames(embedding$umap), stringsAsFactors = FALSE)
  if (!is.null(classification)) {
    .gk_check_class(classification, "gk_classification")
    if (!colour_by %in% names(classification$cells)) .gk_abort("Unknown colour_by column.", class = "input")
    if (is.null(embedding$cell_keys) || nrow(embedding$cell_keys) != nrow(dat) ||
        !identical(embedding$source_sha256, classification$source_sha256) ||
        !identical(embedding$config_sha256, classification$config_sha256))
      .gk_abort("Embedding and classification must retain matching source and cell identities.", class = "state")
    index <- .gk_plot_match_cells(embedding$cell_keys, classification$cells)
    dat$image_id <- embedding$cell_keys$image_id
    dat$colour <- classification$cells[[colour_by]][index]
  } else {
    if (!identical(colour_by, "population")) .gk_abort("Without classification, colour_by must be population.", class = "input")
    dat$colour <- dat$population
  }
  ggplot2::ggplot(dat, ggplot2::aes(x = .data[["UMAP1"]], y = .data[["UMAP2"]], colour = .data[["colour"]])) +
    ggplot2::geom_point(size = 0.5, alpha = 0.7) +
    ggplot2::labs(colour = colour_by, title = "Marker embedding")
}

#' Plot cell centroids on an image map
#'
#' @param x A gk_prepare(), gk_classify() or gk_replayed() result.
#' @param image_id Image to plot.
#' @param colour_by Cell column used for colour.
#' @param layers Reserved layer configuration.
#' @return A ggplot object.
#' @family plots
#' @export
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' cfg <- gk_example_config()
#' prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), cfg, quiet = TRUE)
#' thresholds <- gk_thresholds(prep, cfg, seed = 7L)
#' classification <- gk_classify(prep, thresholds, cfg)
#' gk_plot_map(classification, image_id = "sim-01")
gk_plot_map <- function(x, image_id, colour_by = "cell_type", layers = NULL) {
  .gk_plot_require()
  .gk_check_string(image_id)
  cells <- if (inherits(x, "gk_prepared")) x$cells else if (inherits(x, "gk_classification")) {
    extra <- x$cells[.gk_plot_match_cells(x$coordinates, x$cells),
      setdiff(names(x$cells), c("image_id", "cell_id")), drop = FALSE]
    cbind(x$coordinates, extra)
  } else if (inherits(x, "gk_replayed")) x$cells else
    .gk_abort("x must be prepared, classified or replayed data.", class = "input")
  if (!all(c("x", "y") %in% names(cells))) .gk_abort("The selected object has no centroid coordinates.", class = "structure")
  cells <- cells[cells$image_id == image_id, , drop = FALSE]
  if (!colour_by %in% names(cells)) cells[[colour_by]] <- "cells"
  ggplot2::ggplot(cells, ggplot2::aes(x = .data[["x"]], y = .data[["y"]], colour = .data[[colour_by]])) +
    ggplot2::geom_point(size = 0.5, alpha = 0.7) + ggplot2::coord_equal() +
    ggplot2::labs(colour = colour_by, title = image_id)
}

#' Plot marker means by classified cell type
#'
#' One point represents the mean of observed finite scores for one image,
#' marker and cell type. Point size is the number of contributing cells.
#' Scores use the same correction as the classification. Objects with
#' mismatched source data, row order or score space are rejected.
#'
#' @param prepared A gk_prepare() result.
#' @param classification A gk_classify() result.
#' @param thresholds A gk_thresholds() result.
#' @return A ggplot object.
#' @family plots
#' @export
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' cfg <- gk_example_config()
#' prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), cfg, quiet = TRUE)
#' thresholds <- gk_thresholds(prep, cfg, seed = 7L)
#' classification <- gk_classify(prep, thresholds, cfg)
#' gk_plot_dotplot(prep, classification, thresholds)
gk_plot_dotplot <- function(prepared, classification, thresholds) {
  .gk_plot_require()
  .gk_check_class(prepared, "gk_prepared")
  .gk_validate_classification(prepared, classification, thresholds)
  score <- .gk_score_matrix(prepared, classification$correction)
  markers <- unique(thresholds$marker)
  dat <- do.call(rbind, lapply(markers, function(marker) {
    values <- score[, marker]
    values[prepared$source[, marker] <= 0L | !is.finite(values)] <- NA_real_
    groups <- unique(classification$cells[, c("image_id", "cell_type"), drop = FALSE])
    do.call(rbind, lapply(seq_len(nrow(groups)), function(i) {
      keep <- classification$cells$image_id == groups$image_id[i] &
        classification$cells$cell_type == groups$cell_type[i]
      observed <- values[keep & !is.na(values)]
      data.frame(image_id = groups$image_id[i], marker = marker,
        cell_type = groups$cell_type[i], score = if (length(observed)) mean(observed) else NA_real_,
        n_observed = length(observed), stringsAsFactors = FALSE)
    }))
  }))
  ggplot2::ggplot(dat, ggplot2::aes(x = .data[["marker"]], y = .data[["cell_type"]], size = .data[["n_observed"]], colour = .data[["score"]])) +
    ggplot2::geom_point(alpha = 0.8, na.rm = TRUE) +
    ggplot2::scale_size_area(max_size = 6) +
    ggplot2::facet_wrap(~image_id) +
    ggplot2::labs(title = "Mean marker scores by cell type", x = "Marker", y = "Cell type",
      size = "Observed cells", colour = "Mean score",
      caption = "Means use the classification's score space; missing measurements do not contribute.")
}

#' Plot thresholds for one image
#' @param thresholds A gk_thresholds() result.
#' @param image_id Image to plot.
#' @return A ggplot object.
#' @family plots
#' @export
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' cfg <- gk_example_config()
#' prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), cfg, quiet = TRUE)
#' thresholds <- gk_thresholds(prep, cfg, seed = 7L)
#' gk_plot_thresholds(thresholds, image_id = "sim-01")
gk_plot_thresholds <- function(thresholds, image_id) {
  .gk_plot_require(); .gk_check_class(thresholds, "gk_thresholds"); .gk_check_string(image_id)
  dat <- thresholds[thresholds$image_id == image_id, , drop = FALSE]
  ggplot2::ggplot(dat, ggplot2::aes(x = .data[["marker"]], y = .data[["estimate"]], colour = .data[["status"]])) +
    ggplot2::geom_point(na.rm = TRUE) + ggplot2::coord_flip() + ggplot2::labs(title = image_id)
}

#' Plot state calls for one image
#' @param state_calls A gk_state_calls() result.
#' @param image_id Image to plot.
#' @return A ggplot object.
#' @family plots
#' @export
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' cfg <- gk_example_config()
#' prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), cfg, quiet = TRUE)
#' thresholds <- gk_thresholds(prep, cfg, seed = 7L)
#' classification <- gk_classify(prep, thresholds, cfg)
#' states <- gk_state_calls(prep, thresholds, classification, cfg)
#' gk_plot_states(states, image_id = "sim-01")
gk_plot_states <- function(state_calls, image_id) {
  .gk_plot_require(); .gk_check_class(state_calls, "gk_state_calls"); .gk_check_string(image_id)
  dat <- state_calls$calls[state_calls$calls$image_id == image_id, , drop = FALSE]
  ggplot2::ggplot(dat, ggplot2::aes(x = .data[["score"]], fill = .data[["positive"]])) +
    ggplot2::geom_histogram(bins = 40L, na.rm = TRUE) + ggplot2::facet_grid(marker ~ parent) +
    ggplot2::labs(title = image_id)
}

#' Make a compact overview
#' @param x A prepared, classified or replayed object.
#' @param image_id Image to plot.
#' @return A patchwork object when patchwork is installed, otherwise the map.
#' @family plots
#' @export
#' @examplesIf requireNamespace("ggplot2", quietly = TRUE)
#' cfg <- gk_example_config()
#' prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), cfg, quiet = TRUE)
#' thresholds <- gk_thresholds(prep, cfg, seed = 7L)
#' classification <- gk_classify(prep, thresholds, cfg)
#' gk_plot_overview(classification, image_id = "sim-01")
gk_plot_overview <- function(x, image_id) {
  .gk_plot_require()
  map <- gk_plot_map(x, image_id)
  if (!requireNamespace("patchwork", quietly = TRUE)) return(map)
  patchwork::wrap_plots(map, ncol = 2L)
}

#' @export
plot.gk_review <- function(x, y = NULL, ...) {
  replayed <- gk_replay(x)
  gk_plot_map(replayed, image_id = unique(replayed$cells$image_id)[[1L]], ...)
}

#' @export
plot.gk_snapshot <- function(x, y = NULL, ...) {
  gk_plot_map(x$replayed, image_id = unique(x$replayed$cells$image_id)[[1L]], ...)
}

#' @export
plot.gk_export <- function(x, y = NULL, ...) {
  cells <- x$cells
  gk_plot_map(structure(list(cells = cells), class = "gk_replayed"),
    image_id = unique(cells$image_id)[[1L]], ...)
}
