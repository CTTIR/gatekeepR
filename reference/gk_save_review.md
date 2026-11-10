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

The saved directory invisibly, with a `checkpoint_revision` attribute.

## Details

Saving over a checkpoint requires ownership of any existing session
lock. Both save and load use an operating-system lock on a separate
hidden sibling file named `.DIRECTORY.gatekeepR.lock`. This empty file
remains after use; do not remove it while sessions may be accessing the
review. The filesystem must support advisory file locks, and its parent
directory must be writable. Session ownership is preserved when
replacing the checkpoint. Reviews returned by
[`gk_load_review()`](gk_load_review.md) carry a checkpoint revision.
Saving that review back to its working directory rejects intervening
writes, even from another browser session in the same R process. After
saving, reload the checkpoint before further editing, or copy the
returned path's `checkpoint_revision` attribute to
`review$checkpoint_revision`. Explicit overwrites with reviews that were
never loaded remain supported.

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
path <- gk_save_review(review, file.path(root, "review"))
list.files(path)
#> [1] "DONE"            "MANIFEST.sha256" "config.json"     "ledgers"        
#> [5] "metadata.json"   "review.rds"     
unlink(root, recursive = TRUE)
```
