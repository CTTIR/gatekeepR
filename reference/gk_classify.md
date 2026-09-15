# Classify cells with the configured ordered hierarchy

**\[experimental\]**

Evaluates flags and ordered hierarchy rules against per-image
thresholds. This is the only phenotype evaluator in gatekeepR: the
review application and batch code both call it. A rule that depends on a
non-callable required marker is disabled and recorded; no missing marker
is silently treated as positive. Structure-review rules receive their
configured pending label until a later review decision is replayed.

## Usage

``` r
gk_classify(prepared, thresholds, config, correction = NULL)
```

## Arguments

- prepared:

  A
  [`gk_prepare()`](https://github.com/CTTIR/gatekeepR/reference/gk_prepare.md)
  result.

- thresholds:

  A
  [`gk_thresholds()`](https://github.com/CTTIR/gatekeepR/reference/gk_thresholds.md)
  result.

- config:

  The configuration used to prepare the data.

- correction:

  `NULL` or a
  [`gk_correct()`](https://github.com/CTTIR/gatekeepR/reference/gk_correct.md)
  result.

## Value

An object of class `gk_classification` with `cells`, `calls`,
`disabled_rules`, the configuration and threshold hashes, and the source
hashes needed for review and export.

## See also

Other classification:
[`gk_state_calls()`](https://github.com/CTTIR/gatekeepR/reference/gk_state_calls.md),
[`gk_structures()`](https://github.com/CTTIR/gatekeepR/reference/gk_structures.md)

## Examples

``` r
prep <- gk_prepare(gk_example_path("example-slide"), gk_example_config(), quiet = TRUE)
th <- gk_thresholds(prep, gk_example_config(), seed = 1L)
cl <- gk_classify(prep, th, gk_example_config())
#> Warning: 1 hierarchy rule disabled because required markers are not callable.
summary(cl)
#>      image_id                            cell_type    n proportion
#> 1  example-01                              B cells  480   0.060000
#> 2  example-01                          CD4 T cells  793   0.099125
#> 3  example-01                          CD8 T cells  638   0.079750
#> 4  example-01                    Endothelial cells  399   0.049875
#> 5  example-01                          Macrophages  637   0.079625
#> 6  example-01                        Other T cells   33   0.004125
#> 7  example-01                   Other immune cells  322   0.040250
#> 8  example-01                            Undefined 2377   0.297125
#> 9  example-01 Unresolved epithelial-immune contact   86   0.010750
#> 10 example-01          Unreviewed epithelial cells 2235   0.279375
```
