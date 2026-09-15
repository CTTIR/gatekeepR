# Launch the gatekeepR review application

Launch the gatekeepR review application

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

  An existing gk_review() object.

- cellspec:

  A cellspec object or path used to build a review.

- config:

  A gk_config() used with cellspec.

- workdir:

  A saved review directory.

- export:

  A verified export directory to inspect.

- reviewer:

  Reviewer identifier shown in the app.

- max_upload_mb:

  Maximum upload size for a future upload view.

- allow_local_paths:

  Allow local path inputs.

- max_plot_points:

  Maximum points shown in map views.

- ...:

  Reserved application options.

## Value

A shiny.appobj.
