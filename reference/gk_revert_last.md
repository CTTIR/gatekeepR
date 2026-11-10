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
review <- gk_set_cut(review, "sim-01", "CD8", estimate = 3,
  reviewer = "example-reviewer", reason = "Provisional cut")
review <- gk_revert_last(review, reviewer = "example-reviewer",
  reason = "Provisional cut was too strict")
# Both entries remain; the second one reverts the first.
gk_ledgers(review)$cut_log[, c("entry_id", "reverts", "new_estimate")]
#>   entry_id reverts new_estimate
#> 1   CL0001    <NA>            3
#> 2   CL0002  CL0001            3
```
