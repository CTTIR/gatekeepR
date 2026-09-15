# Call state markers within configured parent sets

**\[experimental\]**

Estimates a separate state-marker threshold for every image and parent
set, then returns a long table containing every cell by marker by parent
combination. Localisation requirements are evaluated on the raw selected
measurements. State calls are disabled for analysis by default and
become effective only after a review ledger enables them.

## Usage

``` r
gk_state_calls(prepared, thresholds, classification, config)
```

## Arguments

- prepared:

  A
  [`gk_prepare()`](https://github.com/CTTIR/gatekeepR/reference/gk_prepare.md)
  result.

- thresholds:

  A
  [`gk_thresholds()`](https://github.com/CTTIR/gatekeepR/reference/gk_thresholds.md)
  result for identity markers.

- classification:

  A
  [`gk_classify()`](https://github.com/CTTIR/gatekeepR/reference/gk_classify.md)
  result.

- config:

  The configuration used to prepare the data.

## Value

An object of class `gk_state_calls` with long `calls`, per-parent
`state_thresholds`, and provenance hashes.

## See also

Other classification:
[`gk_classify()`](https://github.com/CTTIR/gatekeepR/reference/gk_classify.md),
[`gk_structures()`](https://github.com/CTTIR/gatekeepR/reference/gk_structures.md)

## Examples

``` r
prep <- gk_prepare(gk_example_path("example-slide"), gk_example_config(), quiet = TRUE)
th <- gk_thresholds(prep, gk_example_config(), seed = 1L)
cl <- gk_classify(prep, th, gk_example_config())
#> Warning: 1 hierarchy rule disabled because required markers are not callable.
states <- gk_state_calls(prep, th, cl, gk_example_config())
head(states$calls)
#>     image_id cell_id marker      parent in_parent evaluable     score estimate
#> 1 example-01 c000001  FOXP3 CD4 T cells     FALSE      TRUE 1.0723392       NA
#> 2 example-01 c000002  FOXP3 CD4 T cells     FALSE      TRUE 0.6011354       NA
#> 3 example-01 c000003  FOXP3 CD4 T cells     FALSE      TRUE 1.2844815       NA
#> 4 example-01 c000004  FOXP3 CD4 T cells     FALSE      TRUE 0.9637337       NA
#> 5 example-01 c000005  FOXP3 CD4 T cells     FALSE      TRUE 3.8195993       NA
#> 6 example-01 c000006  FOXP3 CD4 T cells     FALSE      TRUE 1.1168778       NA
#>   localization_ratio positive enabled
#> 1           3.909091    FALSE   FALSE
#> 2           4.691176    FALSE   FALSE
#> 3           3.220077    FALSE   FALSE
#> 4           3.612903    FALSE   FALSE
#> 5           4.780109    FALSE   FALSE
#> 6           3.157407    FALSE   FALSE
```
