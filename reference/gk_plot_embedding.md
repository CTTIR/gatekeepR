# Plot an embedding coloured by population or classification

Plot an embedding coloured by population or classification

## Usage

``` r
gk_plot_embedding(embedding, classification = NULL, colour_by = "population")
```

## Arguments

- embedding:

  A gk_embed() result.

- classification:

  Optional gk_classify() result.

- colour_by:

  Column in classification cells, or population.

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
[`gk_plot_map()`](gk_plot_map.md),
[`gk_plot_overview()`](gk_plot_overview.md),
[`gk_plot_states()`](gk_plot_states.md),
[`gk_plot_thresholds()`](gk_plot_thresholds.md)

## Examples

``` r
prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), gk_example_config(), quiet = TRUE)
embedding <- gk_embed(prep, n_pcs = 3L, grid = 40L, seed = 7L)
gk_plot_embedding(embedding)
```
