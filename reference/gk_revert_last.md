# Append an inverse of the most recent review action

Append an inverse of the most recent review action

## Usage

``` r
gk_revert_last(review, reviewer, reason)
```

## Arguments

- review:

  A
  [`gk_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_review.md)
  object.

- reviewer:

  Reviewer identifier.

- reason:

  Required reason recorded in the ledger.

## Value

A new `gk_review` object. No existing ledger row is removed.

## See also

Other review:
[`gk_decide_structure()`](https://github.com/CTTIR/gatekeepR/reference/gk_decide_structure.md),
[`gk_dispose()`](https://github.com/CTTIR/gatekeepR/reference/gk_dispose.md),
[`gk_import_cuts()`](https://github.com/CTTIR/gatekeepR/reference/gk_import_cuts.md),
[`gk_ledgers()`](https://github.com/CTTIR/gatekeepR/reference/gk_ledgers.md),
[`gk_load_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_load_review.md),
[`gk_replace_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_replace_review.md),
[`gk_replay()`](https://github.com/CTTIR/gatekeepR/reference/gk_replay.md),
[`gk_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_review.md),
[`gk_save_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_save_review.md),
[`gk_set_cut()`](https://github.com/CTTIR/gatekeepR/reference/gk_set_cut.md),
[`gk_set_state()`](https://github.com/CTTIR/gatekeepR/reference/gk_set_state.md)
