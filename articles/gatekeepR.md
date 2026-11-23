# gatekeepR: a reviewable marker gating workflow

![gatekeepR logo](figures/logo.svg)![gatekeepR
logo](figures/logo-dark.svg)

`gatekeepR` turns per-cell marker measurements into reviewable phenotype
and state calls. The same prepared objects and classifier are used by
batch code, the review application, and the locked export. This keeps a
reviewed result replayable after the interactive session has ended.

## The complete workflow

The following code is the smallest end-to-end template. It uses a
configuration and a panel declared as data, then carries the result
through thresholding, classification, state calls, structures, review,
and export.

``` r

cfg <- gk_example_config()
cells <- gk_simulate(n_cells = 300L, seed = 7L)
prep <- gk_prepare(cells, config = cfg, quiet = TRUE)
thresholds <- gk_thresholds(prep, cfg, seed = 7L)
classification <- gk_classify(prep, thresholds, config = cfg)
#> Warning: 4 hierarchy rules disabled because required markers are not
#> callable.
states <- gk_state_calls(prep, thresholds, classification, config = cfg)
structures <- gk_structures(classification, prep)
review <- gk_review(classification, states, structures, thresholds, prep)
reviewed <- gk_replay(review)

snapshot <- gk_lock(review, reviewer = "example-reviewer", status = "PENDING")
export_dir <- tempfile("gatekeepR-example-")
gk_export(snapshot, dir = export_dir)
stopifnot(all(gk_verify_export(export_dir,
  expected_review_id = snapshot$review_id_full)$ok))
```

PENDING is deliberate: running an example does not complete scientific
review. Warnings about disabled rules identify unsupported channels in
the simulated panel and are retained as evidence in the export.

A score correction is optional:
[`gk_correct()`](../reference/gk_correct.md) returns corrected scores
that are passed as `correction` to
[`gk_thresholds()`](../reference/gk_thresholds.md) and
[`gk_classify()`](../reference/gk_classify.md). Robust z-scores are
clipped to the range from -5 to 5, which matters for the `mixture`
method; see the article on threshold methods before combining the two.

[`gk_replay()`](../reference/gk_replay.md) is the review boundary: it
applies the append-only ledgers to the initial calls and returns the
effective reviewed state.
[`gk_save_review()`](../reference/gk_save_review.md) and
[`gk_load_review()`](../reference/gk_load_review.md) persist the review
package before export when work must be resumed later.

## Outputs and auditability

The `classification`, `states`, and `structures` objects retain the cell
and image identifiers needed to join results back to source data. A
locked export contains the effective calls, review ledgers,
configuration, provenance, and a manifest.
[`gk_verify_export()`](../reference/gk_verify_export.md) checks the
manifest and replays the exported decisions, so downstream code can
reject incomplete or contradictory exports.

## Optional interfaces

Plots are thin views over the same objects used by batch code:

``` r

image_id <- prep$cells$image_id[[1L]]
gk_plot_map(reviewed, image_id = image_id)
```

![Map of cell centroids on the simulated image, coloured by reviewed
cell type.](gatekeepR_files/figure-html/plots-1.png)

``` r

gk_plot_thresholds(thresholds, image_id = image_id)
```

![Dot chart of the threshold estimate of each marker, coloured by
status, with the status written out for markers that are not
callable.](gatekeepR_files/figure-html/plots-2.png)

``` r

gk_plot_overview(reviewed, image_id = image_id)
```

![Overview with the cell map on the left and a bar chart of the number
of cells per cell type on the
right.](gatekeepR_files/figure-html/plots-3.png)

The review app can load a review or an exported result with
`shiny::runApp(gk_app(review = review))` or
`shiny::runApp(gk_app(export = export_dir))`. The app does not create a
separate classification implementation.
