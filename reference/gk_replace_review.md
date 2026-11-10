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

## Details

Replacement requires the same analytical base. Partial replacement must
preserve globally unique action orders and valid undo references. If
histories conflict, use [`gk_import_cuts()`](gk_import_cuts.md) to
append new cuts, or replace the complete history with `scope = "all"`.

## See also

Other review: [`gk_decide_structure()`](gk_decide_structure.md),
[`gk_dispose()`](gk_dispose.md),
[`gk_import_cuts()`](gk_import_cuts.md),
[`gk_ledgers()`](gk_ledgers.md),
[`gk_load_review()`](gk_load_review.md), [`gk_replay()`](gk_replay.md),
[`gk_revert_last()`](gk_revert_last.md), [`gk_review()`](gk_review.md),
[`gk_save_review()`](gk_save_review.md),
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
agreed <- gk_set_cut(review, "sim-01", "CD3e", estimate = 2.8,
  reviewer = "reviewer-a", reason = "Cut agreed in the panel review")
gk_save_review(agreed, file.path(root, "agreed"))
current <- gk_set_cut(review, "sim-01", "CD8", estimate = 2.5,
  reviewer = "reviewer-b", reason = "Provisional cut")
replaced <- gk_replace_review(current, file.path(root, "agreed"),
  scope = "cuts", confirm = TRUE, backup_dir = file.path(root, "backup"))
gk_ledgers(replaced)$cut_log[, c("reviewer", "marker", "new_estimate")]
#>     reviewer marker new_estimate
#> 1 reviewer-a   CD3e          2.8
unlink(root, recursive = TRUE)
```
