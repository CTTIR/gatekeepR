# Read a verified export

Read a verified export

## Usage

``` r
gk_read_export(dir, verify = TRUE, expected_review_id = NULL)
```

## Arguments

- dir:

  Export directory.

- verify:

  Verify before reading? `FALSE` permits inspection of legacy or
  untrusted exports and makes no integrity claim.

- expected_review_id:

  Optional full ID passed to
  [`gk_verify_export()`](gk_verify_export.md).

## Value

A `gk_export` list containing snapshot, configuration and tables.

## See also

Other export: [`gk_export()`](gk_export.md), [`gk_lock()`](gk_lock.md),
[`gk_verify_export()`](gk_verify_export.md)

## Examples

``` r
cfg <- gk_example_config()
prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), cfg, quiet = TRUE)
thresholds <- gk_thresholds(prep, cfg, seed = 7L)
classification <- gk_classify(prep, thresholds, cfg)
#> Warning: 4 hierarchy rules disabled because required markers are not callable.
states <- gk_state_calls(prep, thresholds, classification, cfg)
structures <- gk_structures(classification, prep)
review <- gk_review(classification, states, structures, thresholds, prep)
snapshot <- gk_lock(review, reviewer = "example-reviewer", status = "PENDING")
# \donttest{
export_dir <- tempfile("gatekeepR-export-")
gk_export(snapshot, export_dir)
export <- gk_read_export(export_dir, expected_review_id = snapshot$review_id_full)
names(export)
#> [1] "snapshot"    "config"      "thresholds"  "cells"       "scores"     
#> [6] "state_calls" "structures"  "ledgers"     "checks"     
head(export$cells[, c("cell_id", "cell_type")])
#>   cell_id                   cell_type
#> 1 c000001 Unreviewed epithelial cells
#> 2 c000002 Unreviewed epithelial cells
#> 3 c000003 Unreviewed epithelial cells
#> 4 c000004 Unreviewed epithelial cells
#> 5 c000005 Unreviewed epithelial cells
#> 6 c000006 Unreviewed epithelial cells
unlink(export_dir, recursive = TRUE)
# }
```
