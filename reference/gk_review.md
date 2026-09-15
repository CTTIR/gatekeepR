# Create an editable review state

**\[experimental\]**

Creates an immutable base review and four empty append-only ledgers.
Every subsequent review function returns a new object; effective labels
and dispositions are calculated by
[`gk_replay()`](https://github.com/CTTIR/gatekeepR/reference/gk_replay.md).

## Usage

``` r
gk_review(classification, state_calls, structures, thresholds, prepared)
```

## Arguments

- classification:

  A
  [`gk_classify()`](https://github.com/CTTIR/gatekeepR/reference/gk_classify.md)
  result.

- state_calls:

  A
  [`gk_state_calls()`](https://github.com/CTTIR/gatekeepR/reference/gk_state_calls.md)
  result.

- structures:

  A
  [`gk_structures()`](https://github.com/CTTIR/gatekeepR/reference/gk_structures.md)
  result.

- thresholds:

  A
  [`gk_thresholds()`](https://github.com/CTTIR/gatekeepR/reference/gk_thresholds.md)
  result.

- prepared:

  The matching
  [`gk_prepare()`](https://github.com/CTTIR/gatekeepR/reference/gk_prepare.md)
  result.

## Value

An object of class `gk_review`.

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
[`gk_save_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_save_review.md),
[`gk_set_cut()`](https://github.com/CTTIR/gatekeepR/reference/gk_set_cut.md),
[`gk_set_state()`](https://github.com/CTTIR/gatekeepR/reference/gk_set_state.md)
