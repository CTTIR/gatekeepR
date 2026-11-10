# Write a locked review export

Modified snapshots are rejected before writing. Staged files must pass
content and replay verification before they replace the destination.

## Usage

``` r
gk_export(snapshot, dir, overwrite = FALSE)
```

## Arguments

- snapshot:

  A [`gk_lock()`](gk_lock.md) result.

- dir:

  Destination directory.

- overwrite:

  Replace an existing export directory.

## Value

The destination directory invisibly.

## See also

Other export: [`gk_lock()`](gk_lock.md),
[`gk_read_export()`](gk_read_export.md),
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
list.files(export_dir)
#>  [1] "DONE"                  "MANIFEST.sha256"       "cells.tsv.gz"         
#>  [4] "config.json"           "correction_model.json" "ledgers"              
#>  [7] "replay"                "scores.tsv.gz"         "snapshot.json"        
#> [10] "state_calls.tsv.gz"    "structures.tsv"        "thresholds.tsv"       
unlink(export_dir, recursive = TRUE)
# }
```
