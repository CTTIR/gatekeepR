if (!requireNamespace("pkgload", quietly = TRUE)) {
  stop("Install the optional 'pkgload' package to run this benchmark.")
}
pkgload::load_all(".", quiet = TRUE)

if (!requireNamespace("bench", quietly = TRUE)) {
  stop("Install the optional 'bench' package to run this benchmark.")
}

cfg <- gk_example_config()
cells <- gk_simulate(cfg, n_cells = 1000L, seed = 1L)

result <- bench::mark(
  prep = gk_prepare(cells, config = cfg),
  iterations = 3L,
  check = FALSE
)
print(result)
