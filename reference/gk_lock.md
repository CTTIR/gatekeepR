# Lock a review into an immutable snapshot

The version 2 review ID binds source identity, typed replay inputs,
effective outputs, ledgers, correction model, reviewer and status. It is
a content hash, not a signature or proof of a reviewer's identity.
REVIEWED records the human reviewer's assertion; it does not certify
scientific or clinical validity.

## Usage

``` r
gk_lock(review, reviewer, status = c("PENDING", "REVIEWED"))
```

## Arguments

- review:

  A [`gk_review()`](gk_review.md) object.

- reviewer:

  Reviewer identifier.

- status:

  `"PENDING"` or `"REVIEWED"`.

## Value

An object of class `gk_snapshot`.

## See also

Other export: [`gk_export()`](gk_export.md),
[`gk_read_export()`](gk_read_export.md),
[`gk_verify_export()`](gk_verify_export.md)

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
snapshot <- gk_lock(review, reviewer = "example-reviewer", status = "PENDING")
snapshot
#> <gk_snapshot> "gk-504f9e9e75df5c09": "PENDING"
#> • Production eligible: FALSE
#> • Locked: "2026-11-10T17:45:41Z"
snapshot$review_id
#> [1] "gk-504f9e9e75df5c09"
```
