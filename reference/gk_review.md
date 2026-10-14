# Create an editable review state

**\[experimental\]**

Creates an immutable base review and four empty append-only ledgers.
Every subsequent review function returns a new object; effective labels
and dispositions are calculated by [`gk_replay()`](gk_replay.md).

## Usage

``` r
gk_review(classification, state_calls, structures, thresholds, prepared)
```

## Arguments

- classification:

  A [`gk_classify()`](gk_classify.md) result.

- state_calls:

  A [`gk_state_calls()`](gk_state_calls.md) result.

- structures:

  A [`gk_structures()`](gk_structures.md) result.

- thresholds:

  A [`gk_thresholds()`](gk_thresholds.md) result.

- prepared:

  The matching [`gk_prepare()`](gk_prepare.md) result.

## Value

An object of class `gk_review`.

## See also

Other review: [`gk_decide_structure()`](gk_decide_structure.md),
[`gk_dispose()`](gk_dispose.md),
[`gk_import_cuts()`](gk_import_cuts.md),
[`gk_ledgers()`](gk_ledgers.md),
[`gk_load_review()`](gk_load_review.md),
[`gk_replace_review()`](gk_replace_review.md),
[`gk_replay()`](gk_replay.md), [`gk_revert_last()`](gk_revert_last.md),
[`gk_save_review()`](gk_save_review.md),
[`gk_set_cut()`](gk_set_cut.md), [`gk_set_state()`](gk_set_state.md)
