# Enable, disable or set a parent-specific state call

Enable, disable or set a parent-specific state call

## Usage

``` r
gk_set_state(
  review,
  image_id,
  marker,
  parent,
  action = c("ENABLE", "DISABLE", "SET_CUT"),
  estimate = NULL,
  reviewer,
  reason
)
```

## Arguments

- review:

  A [`gk_review()`](gk_review.md) object.

- image_id:

  Image to change.

- marker:

  State marker.

- parent:

  Configured parent set.

- action:

  `"ENABLE"`, `"DISABLE"` or `"SET_CUT"`.

- estimate:

  New threshold for `SET_CUT`.

- reviewer:

  Reviewer identifier.

- reason:

  Required reason recorded in the ledger.

## Value

A new `gk_review` object.

## See also

Other review: [`gk_decide_structure()`](gk_decide_structure.md),
[`gk_dispose()`](gk_dispose.md),
[`gk_import_cuts()`](gk_import_cuts.md),
[`gk_ledgers()`](gk_ledgers.md),
[`gk_load_review()`](gk_load_review.md),
[`gk_replace_review()`](gk_replace_review.md),
[`gk_replay()`](gk_replay.md), [`gk_revert_last()`](gk_revert_last.md),
[`gk_review()`](gk_review.md), [`gk_save_review()`](gk_save_review.md),
[`gk_set_cut()`](gk_set_cut.md)

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
review <- gk_set_state(review, "sim-01", marker = "Ki67", parent = "Tumor",
  action = "SET_CUT", estimate = 1.5, reviewer = "example-reviewer",
  reason = "Cut placed after visual review of Ki67")
gk_ledgers(review)$state_log[, c("marker", "parent", "action", "new_estimate")]
#>   marker parent  action new_estimate
#> 1   Ki67  Tumor SET_CUT          1.5
```
