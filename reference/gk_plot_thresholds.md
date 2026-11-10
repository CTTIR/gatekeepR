# Plot thresholds for one image

Plot thresholds for one image

## Usage

``` r
gk_plot_thresholds(thresholds, image_id)
```

## Arguments

- thresholds:

  A gk_thresholds() result.

- image_id:

  Image to plot.

## Value

A ggplot object.

## See also

Other plots: [`gk_plot_density()`](gk_plot_density.md),
[`gk_plot_dotplot()`](gk_plot_dotplot.md),
[`gk_plot_embedding()`](gk_plot_embedding.md),
[`gk_plot_map()`](gk_plot_map.md),
[`gk_plot_overview()`](gk_plot_overview.md),
[`gk_plot_states()`](gk_plot_states.md)

## Examples

``` r
cfg <- gk_example_config()
prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), cfg, quiet = TRUE)
thresholds <- gk_thresholds(prep, cfg, seed = 7L)
gk_plot_thresholds(thresholds, image_id = "sim-01")
```
