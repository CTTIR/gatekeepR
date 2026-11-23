# ggplot2 views over the same objects used by the batch and review paths.

#' @importFrom rlang .data
.gk_plot_require <- function() .gk_require("ggplot2", "gatekeepR plots")

# Shared look of every gatekeepR plot: ggplot2's minimal theme at the default
# base size, titles aligned with the plot edge and left-aligned captions.
.gk_plot_theme <- function() {
  ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(plot.title.position = "plot",
      plot.caption = ggplot2::element_text(hjust = 0),
      plot.caption.position = "plot")
}

# Qualitative colours that remain distinguishable with colour vision
# deficiency: the Okabe-Ito palette shipped with R (grDevices::palette.colors())
# for up to nine classes, ordered so that the low-contrast yellow comes last.
# No qualitative palette is colour-blind safe beyond that, so longer legends
# use palettes built for distinct neighbours (Tableau 10, Polychrome 36).
.gk_plot_discrete_colours <- function(values) {
  classes <- if (is.factor(values)) levels(droplevels(values)) else
    sort(unique(as.character(values[!is.na(values)])))
  n <- length(classes)
  colours <- if (n <= 9L) {
    okabe_ito <- unname(grDevices::palette.colors(9L, "Okabe-Ito"))
    okabe_ito[c(6L, 2L, 4L, 8L, 3L, 7L, 1L, 9L, 5L)][seq_len(n)]
  } else if (n == 10L) {
    unname(grDevices::palette.colors(10L, "Tableau 10"))
  } else if (n <= 36L) {
    unname(grDevices::palette.colors(n, "Polychrome 36"))
  } else {
    grDevices::hcl.colors(n, "Dark 3")
  }
  stats::setNames(colours, classes)
}

.gk_plot_is_discrete <- function(values) {
  is.character(values) || is.factor(values) || is.logical(values)
}

# Colour scale for a cell-level column: the qualitative palette with enlarged
# legend keys for classes, viridis for numbers.
.gk_plot_colour_scale <- function(values) {
  if (!.gk_plot_is_discrete(values)) return(list(ggplot2::scale_colour_viridis_c()))
  list(
    ggplot2::scale_colour_manual(values = .gk_plot_discrete_colours(values), na.value = "grey50"),
    ggplot2::guides(colour = ggplot2::guide_legend(override.aes = list(size = 3, alpha = 1)))
  )
}

# "cell_type" -> "Cell type" for axis and legend titles.
.gk_plot_label <- function(x) {
  x <- gsub("_", " ", x, fixed = TRUE)
  paste0(toupper(substring(x, 1L, 1L)), substring(x, 2L))
}

.gk_plot_image_rows <- function(data, image_id, call = rlang::caller_env()) {
  keep <- !is.na(data$image_id) & data$image_id == image_id
  if (!any(keep)) {
    available <- unique(data$image_id)
    .gk_abort(c("No rows for image {.val {image_id}}.",
      "i" = "Available image{?s}: {.val {available}}."), class = "input", call = call)
  }
  data[keep, , drop = FALSE]
}

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
#' @details
#' All plot helpers use [ggplot2::theme_minimal()] and colours that remain
#' distinguishable with colour vision deficiency: Okabe-Ito for up to nine
#' classes and viridis for numbers. With ten or more classes no qualitative
#' palette is colour-blind safe; the plots then use palettes with distinct
#' neighbours (Tableau 10, Polychrome 36), which are best combined with
#' facets or direct labels. All helpers return ordinary ggplot objects, so a
#' theme or scale added by the caller replaces these defaults.
#' @return A ggplot object. The dashed vertical line marks the threshold
#'   estimate, which is also stated in the subtitle.
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
  estimate <- row$estimate[[1L]]
  subtitle <- paste0(row$status, ", method ", row$method,
    if (is.finite(estimate)) paste0(", threshold ", format(signif(estimate, 3L))) else "")
  pool_colours <- c("All observations" = "#000000", "Negative pool" = "#0072B2",
    "Positive pool" = "#D55E00")
  p <- ggplot2::ggplot(dat, ggplot2::aes(x = .data[["value"]], y = .data[["density"]], colour = .data[["pool"]])) +
    ggplot2::geom_line(linewidth = 0.7, na.rm = TRUE) +
    ggplot2::labs(x = paste(marker, "score"), y = "Density", title = paste(image_id, marker),
      subtitle = subtitle, caption = row$details, colour = "Evidence") +
    .gk_plot_theme()
  p <- p + if (nrow(dat)) ggplot2::scale_colour_manual(values = pool_colours) else
    ggplot2::annotate("text", x = if (is.finite(estimate)) estimate else 0,
      y = 0, label = "No density evidence retained", vjust = -1)
  if (is.finite(estimate)) p <- p + ggplot2::geom_vline(xintercept = estimate, linetype = 2)
  p
}

#' Plot an embedding coloured by population or classification
#'
#' @param embedding A gk_embed() result.
#' @param classification Optional gk_classify() result.
#' @param colour_by Column in classification cells, or population.
#' @inherit gk_plot_density details
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
    .gk_plot_colour_scale(dat$colour) +
    ggplot2::labs(x = "UMAP 1", y = "UMAP 2", colour = .gk_plot_label(colour_by),
      title = "Marker embedding") +
    .gk_plot_theme()
}

#' Plot cell centroids on an image map
#'
#' @param x A gk_prepare(), gk_classify() or gk_replayed() result.
#' @param image_id Image to plot.
#' @param colour_by Cell column used for colour.
#' @param layers Reserved layer configuration.
#' @inherit gk_plot_density details
#' @return A ggplot object. Axes are the centroid coordinates in the units of
#'   the source cell table, drawn with equal scaling.
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
  .gk_check_string(image_id); .gk_check_string(colour_by)
  cells <- if (inherits(x, "gk_prepared")) x$cells else if (inherits(x, "gk_classification")) {
    extra <- x$cells[.gk_plot_match_cells(x$coordinates, x$cells),
      setdiff(names(x$cells), c("image_id", "cell_id")), drop = FALSE]
    cbind(x$coordinates, extra)
  } else if (inherits(x, "gk_replayed")) x$cells else
    .gk_abort("x must be prepared, classified or replayed data.", class = "input")
  if (!all(c("x", "y") %in% names(cells))) .gk_abort("The selected object has no centroid coordinates.", class = "structure")
  cells <- .gk_plot_image_rows(cells, image_id)
  if (!colour_by %in% names(cells)) cells[[colour_by]] <- "cells"
  ggplot2::ggplot(cells, ggplot2::aes(x = .data[["x"]], y = .data[["y"]], colour = .data[[colour_by]])) +
    ggplot2::geom_point(size = 0.5, alpha = 0.7) + ggplot2::coord_equal() +
    .gk_plot_colour_scale(cells[[colour_by]]) +
    ggplot2::labs(x = "Centroid x", y = "Centroid y", colour = .gk_plot_label(colour_by),
      title = image_id) +
    .gk_plot_theme()
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
#' @inherit gk_plot_density details
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
    ggplot2::scale_colour_viridis_c() +
    ggplot2::facet_wrap(~image_id) +
    ggplot2::labs(title = "Mean marker scores by cell type", x = "Marker", y = "Cell type",
      size = "Observed cells", colour = "Mean score",
      caption = "Means use the classification's score space; missing measurements do not contribute.") +
    .gk_plot_theme() +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, vjust = 1))
}

#' Plot thresholds for one image
#'
#' One point per marker at its threshold estimate, coloured by status. A marker
#' without an estimate (not callable, or not separated) has no point; its
#' status is written in its row instead, so that it is not mistaken for a
#' marker that was left out.
#'
#' @param thresholds A gk_thresholds() result.
#' @param image_id Image to plot.
#' @inherit gk_plot_density details
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
  dat <- .gk_plot_image_rows(as.data.frame(thresholds), image_id)
  missing <- dat[!is.finite(dat$estimate), , drop = FALSE]
  # Without any estimate there is no score axis to anchor the labels to.
  missing$anchor <- rep(if (nrow(missing) < nrow(dat)) -Inf else 0, nrow(missing))
  ggplot2::ggplot(dat, ggplot2::aes(x = .data[["marker"]], y = .data[["estimate"]], colour = .data[["status"]])) +
    ggplot2::geom_point(size = 2.5, na.rm = TRUE) +
    ggplot2::geom_text(data = missing,
      ggplot2::aes(y = .data[["anchor"]], label = .data[["status"]]),
      hjust = -0.05, size = 3, show.legend = FALSE) +
    ggplot2::scale_colour_manual(values = .gk_plot_discrete_colours(dat$status)) +
    ggplot2::coord_flip() +
    ggplot2::labs(x = "Marker", y = "Threshold estimate (score units)", colour = "Status",
      title = image_id) +
    .gk_plot_theme()
}

#' Plot state calls for one image
#'
#' Histograms of the state-marker score for the cells of each parent set, one
#' panel per marker and parent. Cells outside the parent set are not drawn,
#' because a state call only applies within its parent. The dashed line marks
#' the state threshold. Cells without a state threshold or without an
#' evaluable measurement are shown as "Not called" rather than as negative. A
#' cell above the threshold stays negative when it fails the marker's
#' localisation rule.
#'
#' @param state_calls A gk_state_calls() result.
#' @param image_id Image to plot.
#' @inherit gk_plot_density details
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
  dat <- .gk_plot_image_rows(state_calls$calls, image_id)
  dat <- dat[dat$in_parent %in% TRUE, , drop = FALSE]
  called <- is.finite(dat$estimate) & dat$evaluable %in% TRUE & !is.na(dat$positive)
  dat$call <- ifelse(dat$positive %in% TRUE, "Positive", "Negative")
  dat$call[!called] <- "Not called"
  dat$call <- factor(dat$call, levels = c("Negative", "Positive", "Not called"))
  dat$panel <- if (nrow(dat)) paste(dat$marker, "in", dat$parent) else character()
  cuts <- unique(dat[is.finite(dat$estimate), c("panel", "estimate"), drop = FALSE])
  p <- ggplot2::ggplot(dat, ggplot2::aes(x = .data[["score"]], fill = .data[["call"]])) +
    ggplot2::geom_histogram(bins = 40L, na.rm = TRUE) +
    ggplot2::labs(x = "State marker score", y = "Cells in parent set", fill = "State call",
      title = image_id, caption = paste(
        "Dashed line: state threshold. Only cells of the parent set are shown;",
        "a positive call also needs the configured localisation.", sep = "\n")) +
    .gk_plot_theme()
  if (!nrow(dat)) {
    return(p + ggplot2::annotate("text", x = 0, y = 0, label = "No cells in a parent set"))
  }
  p + ggplot2::geom_vline(data = cuts, ggplot2::aes(xintercept = .data[["estimate"]]),
    linetype = 2) +
    ggplot2::scale_fill_manual(values = c(Negative = "#0072B2", Positive = "#D55E00",
      "Not called" = "#999999")) +
    ggplot2::facet_wrap(~panel, scales = "free_y")
}

#' Make a compact overview
#'
#' The cell map of one image next to the number of cells per class of the
#' colour variable, in the same colours.
#'
#' @param x A prepared, classified or replayed object.
#' @param image_id Image to plot.
#' @inherit gk_plot_density details
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
  classes <- map$data[["cell_type"]]
  counts <- as.data.frame(table(class = as.character(classes), useNA = "no"),
    responseName = "n", stringsAsFactors = FALSE)
  counts$class <- factor(counts$class, levels = counts$class[order(counts$n)])
  bars <- ggplot2::ggplot(counts,
    ggplot2::aes(x = .data[["class"]], y = .data[["n"]], fill = .data[["class"]])) +
    ggplot2::geom_col(show.legend = FALSE) +
    ggplot2::scale_fill_manual(values = .gk_plot_discrete_colours(classes)) +
    ggplot2::coord_flip() +
    ggplot2::labs(x = NULL, y = "Cells", title = "Cells per class") +
    .gk_plot_theme()
  patchwork::wrap_plots(map + ggplot2::theme(legend.position = "none"), bars,
    ncol = 2L, widths = c(3, 2))
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
