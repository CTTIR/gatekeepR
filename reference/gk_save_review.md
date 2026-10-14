# Save a review checkpoint atomically

**\[experimental\]**

## Usage

``` r
gk_save_review(review, dir, overwrite = FALSE)
```

## Arguments

- review:

  A [`gk_review()`](gk_review.md) object.

- dir:

  Directory to create.

- overwrite:

  Replace an existing directory.

## Value

The saved directory invisibly.

## Details

Saving over a checkpoint requires ownership of any existing session
lock. Both save and load use an operating-system lock on a separate
hidden sibling file named `.DIRECTORY.gatekeepR.lock`. This empty file
remains after use; do not remove it while sessions may be accessing the
review. The filesystem must support advisory file locks, and its parent
directory must be writable. Session ownership is preserved when
replacing the checkpoint.

## See also

Other review: [`gk_decide_structure()`](gk_decide_structure.md),
[`gk_dispose()`](gk_dispose.md),
[`gk_import_cuts()`](gk_import_cuts.md),
[`gk_ledgers()`](gk_ledgers.md),
[`gk_load_review()`](gk_load_review.md),
[`gk_replace_review()`](gk_replace_review.md),
[`gk_replay()`](gk_replay.md), [`gk_revert_last()`](gk_revert_last.md),
[`gk_review()`](gk_review.md), [`gk_set_cut()`](gk_set_cut.md),
[`gk_set_state()`](gk_set_state.md)
