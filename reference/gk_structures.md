# Find epithelial structures for review

**\[experimental\]**

Runs deterministic centroid-based DBSCAN on cells awaiting a configured
structure decision. Epsilon is the 95th percentile of the
`(min_pts - 1)`th nearest-neighbour distance, bounded by `eps_min` and
`eps_max`. Retained structures are ordered by decreasing size and then
centroid coordinates, making IDs stable under input row permutation.

## Usage

``` r
gk_structures(
  classification,
  prepared,
  eps_min = 15,
  eps_max = 30,
  min_pts = 10L,
  min_cells = 20L
)
```

## Arguments

- classification:

  A
  [`gk_classify()`](https://github.com/CTTIR/gatekeepR/reference/gk_classify.md)
  result.

- prepared:

  The matching
  [`gk_prepare()`](https://github.com/CTTIR/gatekeepR/reference/gk_prepare.md)
  result.

- eps_min, eps_max:

  Lower and upper bounds for DBSCAN epsilon in the coordinate units of
  the cellspec.

- min_pts:

  DBSCAN minimum points.

- min_cells:

  Minimum cells for an exported structure.

## Value

An object of class `gk_structures` with `structures`, `cell_structure`,
parameters and provenance hashes.

## See also

Other classification:
[`gk_classify()`](https://github.com/CTTIR/gatekeepR/reference/gk_classify.md),
[`gk_state_calls()`](https://github.com/CTTIR/gatekeepR/reference/gk_state_calls.md)

## Examples

``` r
prep <- gk_prepare(gk_example_path("example-slide"), gk_example_config(), quiet = TRUE)
th <- gk_thresholds(prep, gk_example_config(), seed = 1L)
cl <- gk_classify(prep, th, gk_example_config())
#> Warning: 1 hierarchy rule disabled because required markers are not callable.
if (requireNamespace("dbscan", quietly = TRUE)) gk_structures(cl, prep)
#> <gk_structures>: 7 structures
#>    image_id structure_id n_cells centroid_x centroid_y   xmin   xmax   ymin
#>  example-01          E01     497   506.2590   931.4646  373.3  625.1  801.3
#>  example-01          E02     453  1038.7876   752.3581  934.3 1149.7  647.4
#>  example-01          E03     385   829.8748   288.7078  737.4  929.5  194.4
#>  example-01          E04     321  1185.9950   441.3726 1085.1 1277.5  335.2
#>  example-01          E05     272   440.4879   412.4540  359.6  521.5  331.7
#>  example-01          E06     112   982.7964  1278.5929  935.9 1035.7 1222.9
#>  example-01          E07      44   712.2318   660.0955  676.9  736.7  634.8
#>    ymax decision
#>  1040.0     <NA>
#>   860.0     <NA>
#>   391.3     <NA>
#>   539.9     <NA>
#>   496.7     <NA>
#>  1325.3     <NA>
#>   694.0     <NA>
```
