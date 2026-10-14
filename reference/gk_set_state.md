# Enable, disable or set a parent-specific state call

Enable, disable or set a parent-specific state call

## Usage

``` r
gk_set_state(
  review,
  image_id,
  marker,
  parent,
  action = c("ENABLE", "DISABLE", "SET_CUT"),
  estimate = NULL,
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

  State marker.

- parent:

  Configured parent set.

- action:

  `"ENABLE"`, `"DISABLE"` or `"SET_CUT"`.

- estimate:

  New threshold for `SET_CUT`.

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
[`gk_set_cut()`](gk_set_cut.md)
