# Plot marker means by classified cell type

One point represents the mean of observed finite scores for one image,
marker and cell type. Point size is the number of contributing cells.
Scores use the same correction as the classification. Objects with
mismatched source data, row order or score space are rejected.

## Usage

``` r
gk_plot_dotplot(prepared, classification, thresholds)
```

## Arguments

- prepared:

  A gk_prepare() result.

- classification:

  A gk_classify() result.

- thresholds:

  A gk_thresholds() result.

## Value

A ggplot object.

## See also

Other plots: [`gk_plot_density()`](gk_plot_density.md),
[`gk_plot_embedding()`](gk_plot_embedding.md),
[`gk_plot_map()`](gk_plot_map.md),
[`gk_plot_overview()`](gk_plot_overview.md),
[`gk_plot_states()`](gk_plot_states.md),
[`gk_plot_thresholds()`](gk_plot_thresholds.md)

## Examples

``` r
cfg <- gk_example_config()
prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), cfg, quiet = TRUE)
thresholds <- gk_thresholds(prep, cfg, seed = 7L)
classification <- gk_classify(prep, thresholds, cfg)
#> Warning: 4 hierarchy rules disabled because required markers are not callable.
gk_plot_dotplot(prep, classification, thresholds)
```
