# Launch the gatekeepR review application

Review threshold, structure, disposition and state decisions in a local
Shiny session. Every change requires a reviewer and reason and appends a
ledger entry. A locked download uses one verified snapshot; subsequent
edits invalidate that download until a new snapshot is locked. Choosing
`REVIEWED` is an explicit human assessment, not automatic panel
validation.

## Usage

``` r
gk_app(
  review = NULL,
  cellspec = NULL,
  config = NULL,
  workdir = NULL,
  export = NULL,
  reviewer = NULL,
  max_upload_mb = 2048,
  allow_local_paths = FALSE,
  max_plot_points = 50000L,
  ...
)
```

## Arguments

- review:

  An existing [`gk_review()`](gk_review.md) object.

- cellspec:

  A cellspec object or path used to build a review.

- config:

  A [`gk_config()`](gk_config.md) used with cellspec.

- workdir:

  A saved review directory to resume, or a new checkpoint directory when
  supplying `review` or `cellspec`. Checkpoints are written only when
  Save checkpoint is clicked. Existing directories must be resumed with
  `workdir` alone, preventing replacement with an unrelated review.

- export:

  A verified export directory to inspect read-only.

- reviewer:

  Initial reviewer identifier; it can be changed in the app.

- max_upload_mb:

  Reserved compatibility option. There is no upload view.

- allow_local_paths:

  Allow `cellspec` to be a local path. Explicit `workdir` and `export`
  arguments are trusted host configuration; there are no
  browser-supplied local path inputs.

- max_plot_points:

  Maximum cells displayed in the map. The cell table shows at most 500
  cells, or this limit if it is smaller. Display limits never change
  analysis, ledgers or exported rows.

- ...:

  Reserved application options.

## Value

A shiny.appobj.

## Details

Review state is private to each browser session. When a checkpoint
directory is configured, only the first active browser session can save
it. Separate R processes are additionally protected by the checkpoint
ownership rules in [`gk_save_review()`](gk_save_review.md). The download
is a gzip-compressed tar archive containing a `review` directory that
can be checked with [`gk_verify_export()`](gk_verify_export.md).
