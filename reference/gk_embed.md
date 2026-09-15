# Compute a reproducible marker embedding and density populations

**\[experimental\]**

Computes a sign-canonicalised PCA, a deterministic two-dimensional UMAP,
and density basins used by `population_crossing` thresholds. The default
basin implementation is pure R. `small_basins = "uncertain"` retains
cells while assigning their population as `NA`; `"merge"` assigns them
to the nearest retained basin.

## Usage

``` r
gk_embed(
  prepared,
  correction = NULL,
  n_pcs = 10L,
  n_neighbors = 20L,
  min_dist = 0.15,
  grid = 400L,
  bg = 0.03,
  tolerance = 0.03,
  basin_method = c("hillclimb", "ebimage"),
  small_basins = c("uncertain", "merge"),
  min_abs = 30L,
  min_frac = 0.002,
  seed = 42L
)
```

## Arguments

- prepared:

  A
  [`gk_prepare()`](https://github.com/CTTIR/gatekeepR/reference/gk_prepare.md)
  result.

- correction:

  `NULL` or a
  [`gk_correct()`](https://github.com/CTTIR/gatekeepR/reference/gk_correct.md)
  result.

- n_pcs:

  Number of principal components to retain.

- n_neighbors:

  UMAP neighbourhood size.

- min_dist:

  UMAP minimum distance.

- grid:

  Number of KDE grid points in each dimension.

- bg:

  Relative density below which KDE cells are background.

- tolerance:

  Basin merge or watershed tolerance.

- basin_method:

  `"hillclimb"` or optional `"ebimage"`.

- small_basins:

  Whether small basins become uncertain or merge.

- min_abs:

  Minimum cells for a retained basin.

- min_frac:

  Minimum fraction for a retained basin.

- seed:

  Random seed used by UMAP.

## Value

An object of class `gk_embedding` with `pca`, `umap`, `population`, KDE
data, basin information, parameters and provenance hashes.

## See also

Other thresholds:
[`gk_threshold_methods()`](https://github.com/CTTIR/gatekeepR/reference/gk_threshold_methods.md),
[`gk_thresholds()`](https://github.com/CTTIR/gatekeepR/reference/gk_thresholds.md)

## Examples

``` r
if (requireNamespace("uwot", quietly = TRUE)) {
  prep <- gk_prepare(gk_example_path("example-slide"), gk_example_config(), quiet = TRUE)
  emb <- gk_embed(prep, n_pcs = 3L, grid = 40L, seed = 7L)
  emb
}
#> <gk_embedding>: 8000 cells, 8 markers, 4 populations
#> • Basin method: "hillclimb"; threshold: 30
#> • Small basin handling: "uncertain"
#> • Populations: "1=1465, 2=2320, 3=1430, 4=2785"
```
