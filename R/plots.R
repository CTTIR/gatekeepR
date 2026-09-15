# ggplot2 views over the same objects used by the batch and review paths.

.gk_plot_require <- function() .gk_require("ggplot2", "gatekeepR plots")

#' Plot a threshold density and its evidence pools
#'
#' @param thresholds A gk_thresholds() result.
#' @param marker Marker to plot.
#' @param image_id Image to plot.
#' @param parent Parent set for a state threshold; NA for identity markers.
#' @return A ggplot object.
#' @family plots
#' @export
gk_plot_density <- function(thresholds, marker, image_id, parent = NA_character_) {
  .gk_plot_require()
  .gk_check_class(thresholds, "gk_thresholds")
  .gk_check_string(marker); .gk_check_string(image_id)
  hit <- .gk_threshold_row(thresholds, image_id, marker, parent)
  if (length(hit) != 1L) .gk_abort("No unique threshold result matches the requested marker and image.", class = "input")
  row <- thresholds[hit, , drop = FALSE]
  evidence <- attr(thresholds, "evidence")[[row$evidence_ref[[1L]]]]
  if (!is.null(evidence$grid)) {
    dat <- data.frame(value = evidence$grid, density = evidence$density)
  } else if (!is.null(evidence$values)) {
    d <- stats::density(evidence$values)
    dat <- data.frame(value = d$x, density = d$y)
  } else {
    dat <- data.frame(value = numeric(), density = numeric())
  }
  p <- ggplot2::ggplot(dat, ggplot2::aes(x = rlang::.data[["value"]], y = rlang::.data[["density"]])) +
    ggplot2::geom_line(na.rm = TRUE) +
    ggplot2::labs(x = marker, y = "Density", title = paste(image_id, marker),
      subtitle = paste(row$status, row$method), caption = row$details)
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
gk_plot_embedding <- function(embedding, classification = NULL, colour_by = "population") {
  .gk_plot_require()
  .gk_check_class(embedding, "gk_embedding")
  dat <- data.frame(embedding$umap, population = as.character(embedding$population),
    cell_id = rownames(embedding$umap), stringsAsFactors = FALSE)
  if (!is.null(classification)) {
    .gk_check_class(classification, "gk_classification")
    if (!colour_by %in% names(classification$cells)) .gk_abort("Unknown colour_by column.", class = "input")
    dat$colour <- classification$cells[[colour_by]][match(dat$cell_id, classification$cells$cell_id)]
  } else {
    if (!identical(colour_by, "population")) .gk_abort("Without classification, colour_by must be population.", class = "input")
    dat$colour <- dat$population
  }
  ggplot2::ggplot(dat, ggplot2::aes(x = rlang::.data[["UMAP1"]], y = rlang::.data[["UMAP2"]], colour = rlang::.data[["colour"]])) +
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
gk_plot_map <- function(x, image_id, colour_by = "cell_type", layers = NULL) {
  .gk_plot_require()
  .gk_check_string(image_id)
  cells <- if (inherits(x, "gk_prepared")) x$cells else if (inherits(x, "gk_classification")) {
    extra <- x$cells[match(x$coordinates$cell_id, x$cells$cell_id),
      setdiff(names(x$cells), c("image_id", "cell_id")), drop = FALSE]
    cbind(x$coordinates, extra)
  } else if (inherits(x, "gk_replayed")) x$cells else
    .gk_abort("x must be prepared, classified or replayed data.", class = "input")
  if (!all(c("x", "y") %in% names(cells))) .gk_abort("The selected object has no centroid coordinates.", class = "structure")
  cells <- cells[cells$image_id == image_id, , drop = FALSE]
  if (!colour_by %in% names(cells)) cells[[colour_by]] <- "cells"
  ggplot2::ggplot(cells, ggplot2::aes(x = rlang::.data[["x"]], y = rlang::.data[["y"]], colour = rlang::.data[[colour_by]])) +
    ggplot2::geom_point(size = 0.5, alpha = 0.7) + ggplot2::coord_equal() +
    ggplot2::labs(colour = colour_by, title = image_id)
}

#' Plot marker means by classified cell type
#'
#' @param prepared A gk_prepare() result.
#' @param classification A gk_classify() result.
#' @param thresholds A gk_thresholds() result.
#' @return A ggplot object.
#' @family plots
#' @export
gk_plot_dotplot <- function(prepared, classification, thresholds) {
  .gk_plot_require()
  .gk_check_class(prepared, "gk_prepared"); .gk_check_class(classification, "gk_classification")
  .gk_check_class(thresholds, "gk_thresholds")
  markers <- thresholds$marker
  dat <- do.call(rbind, lapply(markers, function(marker) {
    data.frame(marker = marker, cell_type = classification$cells$cell_type,
      score = prepared$score[, marker], stringsAsFactors = FALSE)
  }))
  ggplot2::ggplot(dat, ggplot2::aes(x = rlang::.data[["marker"]], y = rlang::.data[["cell_type"]], size = abs(rlang::.data[["score"]]), colour = rlang::.data[["score"]])) +
    ggplot2::geom_point(alpha = 0.7, na.rm = TRUE) + ggplot2::labs(title = "Marker dot plot")
}

#' Plot thresholds for one image
#' @param thresholds A gk_thresholds() result.
#' @param image_id Image to plot.
#' @return A ggplot object.
#' @family plots
#' @export
gk_plot_thresholds <- function(thresholds, image_id) {
  .gk_plot_require(); .gk_check_class(thresholds, "gk_thresholds"); .gk_check_string(image_id)
  dat <- thresholds[thresholds$image_id == image_id, , drop = FALSE]
  ggplot2::ggplot(dat, ggplot2::aes(x = rlang::.data[["marker"]], y = rlang::.data[["estimate"]], colour = rlang::.data[["status"]])) +
    ggplot2::geom_point(na.rm = TRUE) + ggplot2::coord_flip() + ggplot2::labs(title = image_id)
}

#' Plot state calls for one image
#' @param state_calls A gk_state_calls() result.
#' @param image_id Image to plot.
#' @return A ggplot object.
#' @family plots
#' @export
gk_plot_states <- function(state_calls, image_id) {
  .gk_plot_require(); .gk_check_class(state_calls, "gk_state_calls"); .gk_check_string(image_id)
  dat <- state_calls$calls[state_calls$calls$image_id == image_id, , drop = FALSE]
  ggplot2::ggplot(dat, ggplot2::aes(x = rlang::.data[["score"]], fill = rlang::.data[["positive"]])) +
    ggplot2::geom_histogram(bins = 40L, na.rm = TRUE) + ggplot2::facet_grid(marker ~ parent) +
    ggplot2::labs(title = image_id)
}

#' Make a compact overview
#' @param x A prepared, classified or replayed object.
#' @param image_id Image to plot.
#' @return A patchwork object when patchwork is installed, otherwise the map.
#' @family plots
#' @export
gk_plot_overview <- function(x, image_id) {
  .gk_plot_require()
  map <- gk_plot_map(x, image_id)
  if (!requireNamespace("patchwork", quietly = TRUE)) return(map)
  patchwork::wrap_plots(map, ncol = 2L)
}
