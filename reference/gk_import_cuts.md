# Import identity-marker cuts without replacing other ledgers

Import identity-marker cuts without replacing other ledgers

## Usage

``` r
gk_import_cuts(review, path, reviewer, reason)
```

## Arguments

- review:

  A [`gk_review()`](gk_review.md) object.

- path:

  A TSV file with `image_id`, `marker`, `estimate` and optional `parent`
  columns.

- reviewer:

  Reviewer identifier.

- reason:

  Required reason recorded for every imported cut.

## Value

A new `gk_review` object.

## See also

Other review: [`gk_decide_structure()`](gk_decide_structure.md),
[`gk_dispose()`](gk_dispose.md), [`gk_ledgers()`](gk_ledgers.md),
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
cuts <- tempfile(fileext = ".tsv")
utils::write.table(
  data.frame(image_id = "sim-01", marker = c("CD3e", "CD8"), estimate = c(2.7, 2.6)),
  cuts, sep = "\t", row.names = FALSE, quote = FALSE
)
review <- gk_import_cuts(review, cuts, reviewer = "example-reviewer",
  reason = "Cuts agreed in the panel review")
gk_ledgers(review)$cut_log[, c("marker", "old_estimate", "new_estimate")]
#>   marker old_estimate new_estimate
#> 1   CD3e     2.687402          2.7
#> 2    CD8     2.871802          2.6
unlink(cuts)
```
