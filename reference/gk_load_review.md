# Load a review checkpoint and acquire its single-writer lock

Load a review checkpoint and acquire its single-writer lock

## Usage

``` r
gk_load_review(dir, takeover = FALSE)
```

## Arguments

- dir:

  Directory written by
  [`gk_save_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_save_review.md).

- takeover:

  Replace a lock left by a stale session.

## Value

A `gk_review` object.

## See also

Other review:
[`gk_decide_structure()`](https://github.com/CTTIR/gatekeepR/reference/gk_decide_structure.md),
[`gk_dispose()`](https://github.com/CTTIR/gatekeepR/reference/gk_dispose.md),
[`gk_import_cuts()`](https://github.com/CTTIR/gatekeepR/reference/gk_import_cuts.md),
[`gk_ledgers()`](https://github.com/CTTIR/gatekeepR/reference/gk_ledgers.md),
[`gk_replace_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_replace_review.md),
[`gk_replay()`](https://github.com/CTTIR/gatekeepR/reference/gk_replay.md),
[`gk_revert_last()`](https://github.com/CTTIR/gatekeepR/reference/gk_revert_last.md),
[`gk_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_review.md),
[`gk_save_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_save_review.md),
[`gk_set_cut()`](https://github.com/CTTIR/gatekeepR/reference/gk_set_cut.md),
[`gk_set_state()`](https://github.com/CTTIR/gatekeepR/reference/gk_set_state.md)
