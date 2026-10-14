# Import identity-marker cuts without replacing other ledgers

Import identity-marker cuts without replacing other ledgers

## Usage

``` r
gk_import_cuts(review, path, reviewer, reason)
```

## Arguments

- review:

  A [`gk_review()`](gk_review.md) object.

- path:

  A TSV file with `image_id`, `marker`, `estimate` and optional `parent`
  columns.

- reviewer:

  Reviewer identifier.

- reason:

  Required reason recorded for every imported cut.

## Value

A new `gk_review` object.

## See also

Other review: [`gk_decide_structure()`](gk_decide_structure.md),
[`gk_dispose()`](gk_dispose.md), [`gk_ledgers()`](gk_ledgers.md),
[`gk_load_review()`](gk_load_review.md),
[`gk_replace_review()`](gk_replace_review.md),
[`gk_replay()`](gk_replay.md), [`gk_revert_last()`](gk_revert_last.md),
[`gk_review()`](gk_review.md), [`gk_save_review()`](gk_save_review.md),
[`gk_set_cut()`](gk_set_cut.md), [`gk_set_state()`](gk_set_state.md)
