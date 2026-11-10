# Return the four review ledgers

Return the four review ledgers

## Usage

``` r
gk_ledgers(review)
```

## Arguments

- review:

  A [`gk_review()`](gk_review.md) object.

## Value

A named list of append-only data frames.

## See also

Other review: [`gk_decide_structure()`](gk_decide_structure.md),
[`gk_dispose()`](gk_dispose.md),
[`gk_import_cuts()`](gk_import_cuts.md),
[`gk_load_review()`](gk_load_review.md),
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
review <- gk_set_cut(review, "sim-01", "CD3e", estimate = 2.8,
  reviewer = "example-reviewer", reason = "Cut moved to the density valley")
ledgers <- gk_ledgers(review)
names(ledgers)
#> [1] "cut_log"         "structure_log"   "disposition_log" "state_log"      
vapply(ledgers, nrow, integer(1))
#>         cut_log   structure_log disposition_log       state_log 
#>               1               0               0               0 
```
