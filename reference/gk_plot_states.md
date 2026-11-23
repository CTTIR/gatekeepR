# Plot state calls for one image

Histograms of the state-marker score for the cells of each parent set,
one panel per marker and parent. Cells outside the parent set are not
drawn, because a state call only applies within its parent. The dashed
line marks the state threshold. Cells without a state threshold or
without an evaluable measurement are shown as "Not called" rather than
as negative. A cell above the threshold stays negative when it fails the
marker's localisation rule.

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

## Details

All plot helpers use
[`ggplot2::theme_minimal()`](https://ggplot2.tidyverse.org/reference/ggtheme.html)
and colours that remain distinguishable with colour vision deficiency:
Okabe-Ito for up to nine classes and viridis for numbers. With ten or
more classes no qualitative palette is colour-blind safe; the plots then
use palettes with distinct neighbours (Tableau 10, Polychrome 36), which
are best combined with facets or direct labels. All helpers return
ordinary ggplot objects, so a theme or scale added by the caller
replaces these defaults.

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
