# Set an identity or state threshold in the review ledger

Set an identity or state threshold in the review ledger

## Usage

``` r
gk_set_cut(
  review,
  image_id,
  marker,
  parent = NA_character_,
  estimate,
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

  Marker to change.

- parent:

  Parent set for a state marker; `NA` for identity markers.

- estimate:

  New finite threshold.

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
old <- thresholds$estimate[thresholds$marker == "CD3e"]
review <- gk_set_cut(review, "sim-01", "CD3e", estimate = old + 0.2,
  reviewer = "example-reviewer", reason = "Cut moved to the density valley")
gk_ledgers(review)$cut_log[, c("marker", "old_estimate", "new_estimate")]
#>   marker old_estimate new_estimate
#> 1   CD3e     2.687402     2.887402
```
