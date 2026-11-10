# Replay all effective review decisions

Replay all effective review decisions

## Usage

``` r
gk_replay(review)
```

## Arguments

- review:

  A [`gk_review()`](gk_review.md) object.

## Value

A `gk_replayed` object with effective cells, thresholds and state calls.

## See also

Other review: [`gk_decide_structure()`](gk_decide_structure.md),
[`gk_dispose()`](gk_dispose.md),
[`gk_import_cuts()`](gk_import_cuts.md),
[`gk_ledgers()`](gk_ledgers.md),
[`gk_load_review()`](gk_load_review.md),
[`gk_replace_review()`](gk_replace_review.md),
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
review <- gk_dispose(review, "sim-01", bbox = c(0, 50, 0, 50),
  disposition = "EXCLUDE", reviewer = "example-reviewer",
  reason = "Tissue fold in the image corner")
replayed <- gk_replay(review)
replayed
#> <gk_replayed>: 300 effective cells
table(replayed$cells$disposition_effective)
#> 
#> EXCLUDE    NONE 
#>       7     293 
```
