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

  A
  [`gk_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_review.md)
  object.

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

Other review:
[`gk_decide_structure()`](https://github.com/CTTIR/gatekeepR/reference/gk_decide_structure.md),
[`gk_dispose()`](https://github.com/CTTIR/gatekeepR/reference/gk_dispose.md),
[`gk_import_cuts()`](https://github.com/CTTIR/gatekeepR/reference/gk_import_cuts.md),
[`gk_ledgers()`](https://github.com/CTTIR/gatekeepR/reference/gk_ledgers.md),
[`gk_load_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_load_review.md),
[`gk_replace_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_replace_review.md),
[`gk_replay()`](https://github.com/CTTIR/gatekeepR/reference/gk_replay.md),
[`gk_revert_last()`](https://github.com/CTTIR/gatekeepR/reference/gk_revert_last.md),
[`gk_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_review.md),
[`gk_save_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_save_review.md),
[`gk_set_state()`](https://github.com/CTTIR/gatekeepR/reference/gk_set_state.md)
