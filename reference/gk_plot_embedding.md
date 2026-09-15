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

## See also

Other plots:
[`gk_plot_density()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_density.md),
[`gk_plot_dotplot()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_dotplot.md),
[`gk_plot_map()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_map.md),
[`gk_plot_overview()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_overview.md),
[`gk_plot_states()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_states.md),
[`gk_plot_thresholds()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_thresholds.md)
