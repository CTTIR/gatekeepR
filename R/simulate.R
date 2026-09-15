#' Simulate a multiplexed tissue slide
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Generates a synthetic slide matching [gk_example_config()], with known
#' ground truth, for examples, tests and method checks. The slide contains:
#'
#' * lineage populations (epithelial nests, CD8 and CD4 T cells including
#'   FOXP3-positive regulatory cells, B cells, macrophages, other immune
#'   cells, endothelial and stromal cells);
#' * spatial epithelial nests (tumour-like and small benign-like ducts) and
#'   scattered single epithelial cells;
#' * epithelial-immune contact objects co-positive for PanCK and CD45;
#' * a rare CD4/CD8 double-positive T-cell population;
#' * nuclear state markers (FOXP3, Ki67) with nuclear and cytoplasmic
#'   measurements, including cytoplasmic FOXP3 artefacts that fail the
#'   localisation rule;
#' * a shared per-cell brightness component;
#' * an absent channel (all zeros) and a shuffled marker.
#'
#' Intensities are raw arbitrary units rounded to two decimals, as tool
#' exports typically are. Ground truth is stored in the extra cell columns
#' `sim_population` and `sim_structure`.
#'
#' @param n_cells Number of cells.
#' @param markers `NULL` for all twelve example markers, or a subset.
#' @param absent Markers whose channel is entirely zero.
#' @param shuffled Markers whose values are permuted across cells, destroying
#'   any relation to cell identity.
#' @param rare_fraction Fraction of cells in the rare double-positive
#'   population.
#' @param separation Multiplier of the positive-population signal on the log
#'   scale; values below 1 make gating harder.
#' @param image_id Image identifier.
#' @param seed Random seed. The caller's random number state is restored.
#'
#' @return A `cellspec` object (see [gk_cellspec()]).
#'
#' @examples
#' x <- gk_simulate(n_cells = 2000, seed = 3)
#' x
#' table(x$cells$sim_population)
#'
#' @family example data
#' @export
gk_simulate <- function(n_cells = 8000L, markers = NULL, absent = "CD21",
                        shuffled = "SMA", rare_fraction = 0.003, separation = 1,
                        image_id = "sim-01", seed = 1L) {
  all_markers <- c(
    "PanCK", "CD45", "CD3e", "CD4", "CD8", "CD20", "CD68", "CD31",
    "CD21", "SMA", "FOXP3", "Ki67"
  )
  n_cells <- .gk_check_count(n_cells, min = 200L)
  markers <- markers %||% all_markers
  .gk_check_character(markers, min_length = 1L, unique = TRUE)
  unknown <- setdiff(c(markers, absent, shuffled), all_markers)
  if (length(unknown) > 0L) {
    .gk_abort(
      c(
        "The simulator does not know marker{?s} {.val {unknown}}.",
        "i" = "Available: {.val {all_markers}}."
      ),
      class = "input"
    )
  }
  .gk_check_number(rare_fraction, min = 0, max = 0.1)
  .gk_check_number(separation, min = 0.1, max = 5)
  .gk_check_string(image_id)
  .gk_check_count(seed)
  .gk_with_seed(seed, .gk_simulate_impl(
    n_cells, markers, absent, shuffled, rare_fraction, separation, image_id
  ))
}

.gk_simulate_impl <- function(n, markers, absent, shuffled, rare_fraction,
                              separation, image_id) {
  side <- sqrt(n / 0.0035)
  fractions <- c(
    epithelial = 0.28, contact = 0.01, cd8_t = 0.08, cd4_t = 0.10,
    rare_dp_t = rare_fraction, b_cell = 0.06, macrophage = 0.08,
    other_immune = 0.04, endothelial = 0.05
  )
  fractions <- c(fractions, stromal = 1 - sum(fractions))
  counts <- floor(fractions * n)
  counts[["stromal"]] <- n - sum(counts[names(counts) != "stromal"])
  pop <- rep(names(counts), counts)

  # Epithelial nests: 5 tumour-like nests and 2 small benign-like ducts,
  # plus ~8% scattered single epithelial cells.
  n_epi <- counts[["epithelial"]]
  n_scatter <- round(0.08 * n_epi)
  nest_sizes <- c(0.22, 0.2, 0.17, 0.14, 0.12, 0.05, 0.02)
  nest_n <- floor(nest_sizes / sum(nest_sizes) * (n_epi - n_scatter))
  n_scatter <- n_epi - sum(nest_n)
  margin <- 0.15 * side
  centres <- cbind(
    stats::runif(length(nest_n), margin, side - margin),
    stats::runif(length(nest_n), margin, side - margin)
  )
  for (k in seq_len(nrow(centres))[-1L]) {
    for (attempt in 1:50) {
      d <- sqrt(rowSums((centres[seq_len(k - 1L), , drop = FALSE] -
        matrix(centres[k, ], k - 1L, 2L, byrow = TRUE))^2))
      if (all(d > 0.22 * side)) {
        break
      }
      centres[k, ] <- stats::runif(2L, margin, side - margin)
    }
  }
  structure_id <- rep(NA_character_, n)
  x <- stats::runif(n, 0, side)
  y <- stats::runif(n, 0, side)
  epi_idx <- which(pop == "epithelial")
  start <- 1L
  nest_type <- c(rep("tumour", 5L), rep("benign", 2L))
  for (k in seq_along(nest_n)) {
    ids <- epi_idx[start:(start + nest_n[[k]] - 1L)]
    start <- start + nest_n[[k]]
    radius <- sqrt(nest_n[[k]] / (pi * 0.012))
    r <- radius * sqrt(stats::runif(length(ids)))
    theta <- stats::runif(length(ids), 0, 2 * pi)
    x[ids] <- centres[k, 1L] + r * cos(theta)
    y[ids] <- centres[k, 2L] + r * sin(theta)
    structure_id[ids] <- sprintf("%s-%d", nest_type[[k]], k)
  }
  contact_idx <- which(pop == "contact")
  if (length(contact_idx) > 0L) {
    k <- sample.int(5L, length(contact_idx), replace = TRUE)
    radius <- sqrt(nest_n[k] / (pi * 0.012))
    theta <- stats::runif(length(contact_idx), 0, 2 * pi)
    x[contact_idx] <- centres[k, 1L] + radius * cos(theta)
    y[contact_idx] <- centres[k, 2L] + radius * sin(theta)
  }
  x <- pmin(pmax(x, 0), side)
  y <- pmin(pmax(y, 0), side)

  pos <- .gk_sim_positivity(pop, n)
  brightness <- exp(stats::rnorm(n, 0, 0.2))
  bg <- 8
  hi <- stats::setNames(
    c(260, 180, 150, 120, 140, 160, 200, 170, 150, 190, 120, 140),
    c("PanCK", "CD45", "CD3e", "CD4", "CD8", "CD20", "CD68", "CD31", "CD21", "SMA", "FOXP3", "Ki67")
  )
  draw <- function(is_pos, level) {
    mu <- ifelse(is_pos, log(bg) + separation * (log(level) - log(bg)), log(bg))
    exp(stats::rnorm(n, mu, 0.45)) * brightness
  }
  cols <- list()
  for (mk in markers) {
    cell <- draw(pos[[mk]], hi[[mk]])
    if (mk %in% c("PanCK", "CD68")) {
      cyto <- cell * exp(stats::rnorm(n, 0.15, 0.1))
      nuc <- cell * exp(stats::rnorm(n, -0.9, 0.2))
      cols[[paste0("cytoplasm:", mk, ":mean")]] <- cyto
      cols[[paste0("nucleus:", mk, ":mean")]] <- nuc
    }
    if (mk %in% c("FOXP3", "Ki67")) {
      nuc <- draw(pos[[mk]], hi[[mk]] * 1.4)
      cyto <- nuc * exp(stats::rnorm(n, -1.2, 0.25))
      if (identical(mk, "FOXP3")) {
        art <- pop == "epithelial" & stats::runif(n) < 0.06
        nuc[art] <- exp(stats::rnorm(sum(art), log(hi[["FOXP3"]]), 0.3)) * brightness[art]
        cyto[art] <- nuc[art] * exp(stats::rnorm(sum(art), -0.05, 0.1))
      }
      cell <- 0.6 * nuc + 0.4 * cyto
      cols[[paste0("nucleus:", mk, ":mean")]] <- nuc
      cols[[paste0("cytoplasm:", mk, ":mean")]] <- cyto
    }
    cols[[paste0("cell:", mk, ":mean")]] <- cell
  }
  m <- do.call(cbind, cols)
  for (mk in intersect(absent, markers)) {
    m[, grepl(paste0(":", mk, ":"), colnames(m), fixed = TRUE)] <- 0
  }
  perm <- sample.int(n)
  for (mk in intersect(shuffled, markers)) {
    j <- grepl(paste0(":", mk, ":"), colnames(m), fixed = TRUE)
    m[, j] <- m[perm, j, drop = FALSE]
  }
  m <- round(m, 2L)
  ord <- order(colnames(m), method = "radix")
  m <- m[, ord, drop = FALSE]
  cells <- data.frame(
    cell_id = sprintf("c%06d", seq_len(n)),
    image_id = image_id,
    sample_id = image_id,
    x = round(x, 1L),
    y = round(y, 1L),
    area = round(exp(stats::rnorm(n, log(80), 0.3)), 1L),
    sim_population = pop,
    sim_structure = structure_id,
    stringsAsFactors = FALSE
  )
  dictionary <- .gk_dictionary_from_ids(colnames(m))
  images <- data.frame(
    image_id = image_id, sample_id = image_id, pixel_size = 0.5,
    width_px = as.integer(ceiling(side / 0.5)), height_px = as.integer(ceiling(side / 0.5)),
    platform = "simulated", stringsAsFactors = FALSE
  )
  gk_cellspec(
    cells, m,
    dictionary = dictionary, images = images,
    provenance = list(
      producer = list(tool = "gatekeepR::gk_simulate", version = .gk_package_version()),
      created_utc = "1970-01-01T00:00:00Z",
      parameters = list(
        n_cells = n, absent = I(absent), shuffled = I(shuffled),
        rare_fraction = rare_fraction, separation = separation
      )
    )
  )
}

# True positivity per marker for each simulated population.
.gk_sim_positivity <- function(pop, n) {
  is <- function(...) pop %in% c(...)
  u <- stats::runif(n)
  treg <- pop == "cd4_t" & u < 0.2
  list(
    PanCK = is("epithelial", "contact"),
    CD45 = is("contact", "cd8_t", "cd4_t", "rare_dp_t", "b_cell", "macrophage", "other_immune"),
    CD3e = is("cd8_t", "cd4_t", "rare_dp_t"),
    CD4 = is("cd4_t", "rare_dp_t"),
    CD8 = is("cd8_t", "rare_dp_t"),
    CD20 = is("b_cell"),
    CD68 = is("macrophage"),
    CD31 = is("endothelial"),
    CD21 = is("b_cell") & stats::runif(n) < 0.3,
    SMA = is("stromal"),
    FOXP3 = treg | (pop == "epithelial" & stats::runif(n) < 0.03),
    Ki67 = (pop == "epithelial" & stats::runif(n) < 0.3) |
      (is("cd8_t", "cd4_t", "b_cell") & stats::runif(n) < 0.1)
  )
}
