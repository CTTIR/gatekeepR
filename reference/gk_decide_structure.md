# Decide one structure or bounding box

Decide one structure or bounding box

## Usage

``` r
gk_decide_structure(
  review,
  image_id,
  structure_id = NULL,
  bbox = NULL,
  decision = c("Tumor", "Benign", "Unresolved"),
  reviewer,
  reason
)
```

## Arguments

- review:

  A [`gk_review()`](gk_review.md) object.

- image_id:

  Image to change.

- structure_id:

  A structure ID, or `NULL`.

- bbox:

  A `c(xmin, xmax, ymin, ymax)` selection, or `NULL`.

- decision:

  One of `"Tumor"`, `"Benign"` or `"Unresolved"`.

- reviewer:

  Reviewer identifier.

- reason:

  Required reason recorded in the ledger.

## Value

A new `gk_review` object.

## See also

Other review: [`gk_dispose()`](gk_dispose.md),
[`gk_import_cuts()`](gk_import_cuts.md),
[`gk_ledgers()`](gk_ledgers.md),
[`gk_load_review()`](gk_load_review.md),
[`gk_replace_review()`](gk_replace_review.md),
[`gk_replay()`](gk_replay.md), [`gk_revert_last()`](gk_revert_last.md),
[`gk_review()`](gk_review.md), [`gk_save_review()`](gk_save_review.md),
[`gk_set_cut()`](gk_set_cut.md), [`gk_set_state()`](gk_set_state.md)

## Examples

``` r
cfg <- gk_example_config()
prep <- gk_prepare(gk_simulate(n_cells = 600L, seed = 7L), cfg, quiet = TRUE)
thresholds <- gk_thresholds(prep, cfg, seed = 7L)
classification <- gk_classify(prep, thresholds, cfg)
#> Warning: 1 hierarchy rule disabled because required markers are not callable.
states <- gk_state_calls(prep, thresholds, classification, cfg)
structures <- gk_structures(classification, prep)
review <- gk_review(classification, states, structures, thresholds, prep)
structures$structures[, c("structure_id", "n_cells")]
#>   structure_id n_cells
#> 1          E01      37
#> 2          E02      33
#> 3          E03      28
#> 4          E04      23
#> 5          E05      22
first <- structures$structures$structure_id[[1L]]
review <- gk_decide_structure(review, "sim-01", structure_id = first,
  decision = "Tumor", reviewer = "example-reviewer",
  reason = "Invasive nest architecture")
gk_ledgers(review)$structure_log[, c("structure_id", "decision", "n_affected_at_creation")]
#>   structure_id decision n_affected_at_creation
#> 1          E01    Tumor                     NA
```
