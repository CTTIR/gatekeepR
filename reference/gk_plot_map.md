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

Other plots:
[`gk_plot_density()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_density.md),
[`gk_plot_dotplot()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_dotplot.md),
[`gk_plot_embedding()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_embedding.md),
[`gk_plot_overview()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_overview.md),
[`gk_plot_states()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_states.md),
[`gk_plot_thresholds()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_thresholds.md)
