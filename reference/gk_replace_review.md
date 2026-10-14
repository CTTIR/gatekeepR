# Replace selected review ledgers from a saved checkpoint

Replace selected review ledgers from a saved checkpoint

## Usage

``` r
gk_replace_review(
  review,
  snapshot_dir,
  scope = c("cuts", "structures", "dispositions", "states", "all"),
  confirm = FALSE,
  backup_dir = NULL
)
```

## Arguments

- review:

  A [`gk_review()`](gk_review.md) object.

- snapshot_dir:

  A directory written by [`gk_save_review()`](gk_save_review.md).

- scope:

  Ledgers to replace.

- confirm:

  Must be `TRUE`, because history is being replaced.

- backup_dir:

  Directory in which to save the current review first, or `NULL` for a
  temporary directory.

## Value

A new `gk_review` object with `backup_path` attribute.

## See also

Other review: [`gk_decide_structure()`](gk_decide_structure.md),
[`gk_dispose()`](gk_dispose.md),
[`gk_import_cuts()`](gk_import_cuts.md),
[`gk_ledgers()`](gk_ledgers.md),
[`gk_load_review()`](gk_load_review.md), [`gk_replay()`](gk_replay.md),
[`gk_revert_last()`](gk_revert_last.md), [`gk_review()`](gk_review.md),
[`gk_save_review()`](gk_save_review.md),
[`gk_set_cut()`](gk_set_cut.md), [`gk_set_state()`](gk_set_state.md)
