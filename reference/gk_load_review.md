# Load a review checkpoint and acquire its single-writer lock

**\[experimental\]**

## Usage

``` r
gk_load_review(dir, takeover = FALSE)
```

## Arguments

- dir:

  Directory written by [`gk_save_review()`](gk_save_review.md).

- takeover:

  Replace a lock left by a stale session.

## Value

A `gk_review` object.

## Details

Loading is serialized with saving by the sibling operation lock
described in [`gk_save_review()`](gk_save_review.md). Explicit takeover
applies to session ownership; it cannot interrupt a save or load
currently holding the operating-system lock.

## See also

Other review: [`gk_decide_structure()`](gk_decide_structure.md),
[`gk_dispose()`](gk_dispose.md),
[`gk_import_cuts()`](gk_import_cuts.md),
[`gk_ledgers()`](gk_ledgers.md),
[`gk_replace_review()`](gk_replace_review.md),
[`gk_replay()`](gk_replay.md), [`gk_revert_last()`](gk_revert_last.md),
[`gk_review()`](gk_review.md), [`gk_save_review()`](gk_save_review.md),
[`gk_set_cut()`](gk_set_cut.md), [`gk_set_state()`](gk_set_state.md)

## Examples

``` r
cfg <- gk_example_config()
prep <- gk_prepare(gk_simulate(n_cells = 300L, seed = 7L), cfg, quiet = TRUE)
thresholds <- gk_thresholds(prep, cfg, seed = 7L)
classification <- gk_classify(prep, thresholds, cfg)
#> Warning: 4 hierarchy rules disabled because required markers are not callable.
states <- gk_state_calls(prep, thresholds, classification, cfg)
structures <- gk_structures(classification, prep)
review <- gk_review(classification, states, structures, thresholds, prep)
root <- tempfile("gatekeepR-example-")
dir.create(root)
gk_save_review(review, file.path(root, "review"))
loaded <- gk_load_review(file.path(root, "review"))
loaded
#> <gk_review>: 0 ledger entries; locked = FALSE
unlink(root, recursive = TRUE)
```
