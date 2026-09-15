# gatekeepR: a reviewable marker gating workflow

`gatekeepR` turns per-cell marker measurements into reviewable phenotype
and state calls. The same prepared objects and classifier are used by
batch code, the review application, and the locked export. This keeps a
reviewed result replayable after the interactive session has ended.

## The complete workflow

The following code is the smallest end-to-end template. It uses a
configuration and a panel declared as data, then carries the result
through correction, thresholding, classification, state calls,
structures, review, and export.

``` r

cfg <- gk_example_config()
prep <- gk_prepare(cells, config = cfg)
corrected <- gk_correct(prep, method = "robust_z")
thresholds <- gk_thresholds(prep, cfg, correction = corrected)
classification <- gk_classify(corrected, thresholds, config = cfg)
states <- gk_state_calls(corrected, thresholds, config = cfg)
structures <- gk_structures(classification, corrected)
review <- gk_review(classification, states, structures, thresholds, corrected)
reviewed <- gk_replay(review)

snapshot <- gk_lock(review, reviewer = "reviewer-01")
gk_export(snapshot, dir = "export")
gk_verify_export("export")
```

[`gk_replay()`](https://github.com/CTTIR/gatekeepR/reference/gk_replay.md)
is the review boundary: it applies the append-only ledgers to the
initial calls and returns the effective reviewed state.
[`gk_save_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_save_review.md)
and
[`gk_load_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_load_review.md)
persist the review package before export when work must be resumed
later.

## Outputs and auditability

The `classification`, `states`, and `structures` objects retain the cell
and image identifiers needed to join results back to source data. A
locked export contains the effective calls, review ledgers,
configuration, provenance, and a manifest.
[`gk_verify_export()`](https://github.com/CTTIR/gatekeepR/reference/gk_verify_export.md)
checks the manifest and replays the exported decisions, so downstream
code can reject incomplete or contradictory exports.

## Optional interfaces

Plots are thin views over the same objects used by batch code:

``` r

gk_plot_map(reviewed, image_id = "image-01")
gk_plot_thresholds(thresholds)
gk_plot_overview(reviewed, image_id = "image-01")
```

The Shiny shell can load a review or an exported result with
`gk_app(review = review)` or `gk_app(export = export)`. The app does not
create a separate classification implementation.
