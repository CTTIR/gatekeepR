# Set an identity or state threshold in the review ledger

Set an identity or state threshold in the review ledger

## Usage

``` r
gk_set_cut(
  review,
  image_id,
  marker,
  parent = NA_character_,
  estimate,
  reviewer,
  reason
)
```

## Arguments

- review:

  A [`gk_review()`](gk_review.md) object.

- image_id:

  Image to change.

- marker:

  Marker to change.

- parent:

  Parent set for a state marker; `NA` for identity markers.

- estimate:

  New finite threshold.

- reviewer:

  Reviewer identifier.

- reason:

  Required reason recorded in the ledger.

## Value

A new `gk_review` object.

## See also

Other review: [`gk_decide_structure()`](gk_decide_structure.md),
[`gk_dispose()`](gk_dispose.md),
[`gk_import_cuts()`](gk_import_cuts.md),
[`gk_ledgers()`](gk_ledgers.md),
[`gk_load_review()`](gk_load_review.md),
[`gk_replace_review()`](gk_replace_review.md),
[`gk_replay()`](gk_replay.md), [`gk_revert_last()`](gk_revert_last.md),
[`gk_review()`](gk_review.md), [`gk_save_review()`](gk_save_review.md),
[`gk_set_state()`](gk_set_state.md)
