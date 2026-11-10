# Plot cell centroids on an image map

Plot cell centroids on an image map

## Usage

``` r
gk_plot_map(x, image_id, colour_by = "cell_type", layers = NULL)
```

## Arguments

- x:

  A gk_prepare(), gk_classify() or gk_replayed() result.

- image_id:

  Image to plot.

- colour_by:

  Cell column used for colour.

- layers:

  Reserved layer configuration.

## Value

A ggplot object.

## See also

Other plots: [`gk_plot_density()`](gk_plot_density.md),
[`gk_plot_dotplot()`](gk_plot_dotplot.md),
[`gk_plot_embedding()`](gk_plot_embedding.md),
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
gk_plot_map(classification, image_id = "sim-01")
```
