# Verify content identity, replay and reconciliation invariants

Version 2 checks typed contents, source identity, correction model and
every ledger, then reconstructs the base review and compares effective
cells, scores and state calls. Legacy exports can be inspected
explicitly with `gk_read_export(verify = FALSE)`, but require a new
review and lock to obtain this verification contract. No export files
are modified.

## Usage

``` r
gk_verify_export(
  dir,
  cellspec_dir = NULL,
  strict = TRUE,
  expected_review_id = NULL
)
```

## Arguments

- dir:

  Export directory written by [`gk_export()`](gk_export.md).

- cellspec_dir:

  Optional source cellspec directory, checked against the source and
  prepared score contents.

- strict:

  Abort on failed verification?

- expected_review_id:

  Optional independently retained full SHA-256 review ID (the snapshot's
  `review_id_full`).

## Value

A check data frame with `check`, `ok` and `details`.

## Details

Hashes are not signatures. Keep the full review ID independently and
supply `expected_review_id` when verification must detect a replaced
whole export.

## See also

Other export: [`gk_export()`](gk_export.md), [`gk_lock()`](gk_lock.md),
[`gk_read_export()`](gk_read_export.md)

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
checks <- gk_verify_export(export_dir, expected_review_id = snapshot$review_id_full)
all(checks$ok)
#> [1] TRUE
unlink(export_dir, recursive = TRUE)
# }
```
