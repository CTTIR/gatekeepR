# Plot state calls for one image

Plot state calls for one image

## Usage

``` r
gk_plot_states(state_calls, image_id)
```

## Arguments

- state_calls:

  A gk_state_calls() result.

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
[`gk_plot_thresholds()`](gk_plot_thresholds.md)

## Examples

``` r
cfg <- gk_example_config()
prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), cfg, quiet = TRUE)
thresholds <- gk_thresholds(prep, cfg, seed = 7L)
classification <- gk_classify(prep, thresholds, cfg)
#> Warning: 4 hierarchy rules disabled because required markers are not callable.
states <- gk_state_calls(prep, thresholds, classification, cfg)
gk_plot_states(states, image_id = "sim-01")
```
