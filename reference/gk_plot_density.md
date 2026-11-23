# Plot a threshold density and its evidence pools

Plot a threshold density and its evidence pools

## Usage

``` r
gk_plot_density(thresholds, marker, image_id, parent = NA_character_)
```

## Arguments

- thresholds:

  A gk_thresholds() result.

- marker:

  Marker to plot.

- image_id:

  Image to plot.

- parent:

  Parent set for a state threshold; NA for identity markers.

## Value

A ggplot object. The dashed vertical line marks the threshold estimate,
which is also stated in the subtitle.

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

Other plots: [`gk_plot_dotplot()`](gk_plot_dotplot.md),
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
gk_plot_density(thresholds, marker = "CD3e", image_id = "sim-01")
```
