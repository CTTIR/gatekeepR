# Set a cell disposition

Set a cell disposition

## Usage

``` r
gk_dispose(
  review,
  image_id,
  cell_id = NULL,
  bbox = NULL,
  disposition = c("EXCLUDE", "DELETE", "RESTORE"),
  reviewer,
  reason
)
```

## Arguments

- review:

  A [`gk_review()`](gk_review.md) object.

- image_id:

  Image to change.

- cell_id:

  A cell ID, or `NULL` when using `bbox`.

- bbox:

  A `c(xmin, xmax, ymin, ymax)` selection, or `NULL`.

- disposition:

  `"EXCLUDE"`, `"DELETE"` or `"RESTORE"`.

- reviewer:

  Reviewer identifier.

- reason:

  Required reason recorded in the ledger.

## Value

A new `gk_review` object.

## See also

Other review: [`gk_decide_structure()`](gk_decide_structure.md),
[`gk_import_cuts()`](gk_import_cuts.md),
[`gk_ledgers()`](gk_ledgers.md),
[`gk_load_review()`](gk_load_review.md),
[`gk_replace_review()`](gk_replace_review.md),
[`gk_replay()`](gk_replay.md), [`gk_revert_last()`](gk_revert_last.md),
[`gk_review()`](gk_review.md), [`gk_save_review()`](gk_save_review.md),
[`gk_set_cut()`](gk_set_cut.md), [`gk_set_state()`](gk_set_state.md)
