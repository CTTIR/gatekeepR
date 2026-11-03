# Undo the most recent review action without deleting history

Undo the most recent review action without deleting history

## Usage

``` r
gk_revert_last(review, reviewer, reason)
```

## Arguments

- review:

  A [`gk_review()`](gk_review.md) object.

- reviewer:

  Reviewer identifier.

- reason:

  Required reason recorded in the ledger.

## Value

A new `gk_review` object.

## Details

The appended row references the target action. Replay restores the state
before that action, including earlier overlapping selections. Undoing an
undo reactivates its target. No existing ledger row is removed.

## See also

Other review: [`gk_decide_structure()`](gk_decide_structure.md),
[`gk_dispose()`](gk_dispose.md),
[`gk_import_cuts()`](gk_import_cuts.md),
[`gk_ledgers()`](gk_ledgers.md),
[`gk_load_review()`](gk_load_review.md),
[`gk_replace_review()`](gk_replace_review.md),
[`gk_replay()`](gk_replay.md), [`gk_review()`](gk_review.md),
[`gk_save_review()`](gk_save_review.md),
[`gk_set_cut()`](gk_set_cut.md), [`gk_set_state()`](gk_set_state.md)
