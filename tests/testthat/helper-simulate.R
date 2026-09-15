# Shared fixtures. Everything is simulated in code; no private data.

# Small cellspec object with fully controlled marker values. `values` is a
# named list of numeric vectors (one per marker, cell compartment); extra
# compartments can be given as "compartment:marker" names.
gk_test_cellspec <- function(values, image_id = "img-1", x = NULL, y = NULL) {
  n <- length(values[[1L]])
  ids <- names(values)
  feature <- ifelse(grepl(":", ids, fixed = TRUE), paste0(ids, ":mean"), paste0("cell:", ids, ":mean"))
  m <- do.call(cbind, values)
  colnames(m) <- feature
  cells <- data.frame(
    cell_id = sprintf("c%04d", seq_len(n)),
    image_id = image_id,
    x = x %||% seq_len(n),
    y = y %||% rep(1, n),
    stringsAsFactors = FALSE
  )
  gk_cellspec(cells, m)
}

# Minimal valid configuration over identity markers A, B, C (cell compartment).
gk_test_config <- function(markers = c("A", "B", "C"), method = "mixture", ...) {
  gk_config(
    signal_policy = gk_signal_policy(markers),
    panel = gk_panel(markers, role = "identity", threshold_method = method, ...),
    hierarchy = gk_hierarchy(
      rules = list(gk_rule("R1", "A cells", all_of = markers[[1L]])),
      version = "test"
    )
  )
}

# Cached example objects (built once per test run).
gk_test_env <- new.env(parent = emptyenv())

gk_example_slide <- function() {
  if (is.null(gk_test_env$slide)) {
    gk_test_env$slide <- gk_read_cellspec(gk_example_path("example-slide"))
  }
  gk_test_env$slide
}

gk_example_prepared <- function() {
  if (is.null(gk_test_env$prepared)) {
    gk_test_env$prepared <- gk_prepare(gk_example_slide(), gk_example_config(), quiet = TRUE)
  }
  gk_test_env$prepared
}

gk_example_review <- function() {
  if (is.null(gk_test_env$review)) {
    prep <- gk_example_prepared()
    cfg <- gk_example_config()
    th <- gk_thresholds(prep, cfg, seed = 1L)
    cl <- suppressWarnings(gk_classify(prep, th, cfg))
    st <- gk_state_calls(prep, th, cl, cfg)
    ss <- gk_structures(cl, prep, min_cells = 20L)
    gk_test_env$review <- gk_review(cl, st, ss, th, prep)
  }
  gk_test_env$review
}

`%||%` <- function(x, y) if (is.null(x)) y else x
