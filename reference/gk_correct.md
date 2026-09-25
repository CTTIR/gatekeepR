# Correct prepared marker scores

**\[experimental\]**

Applies a deterministic correction to transformed marker scores. Markers
that fail the raw support checks are excluded from fitting and are `NA`
in the corrected matrix, so correction cannot create signal in an absent
channel. The fitted parameters are returned in a `gk_correction_model`
and can be applied again to the same prepared data.

## Usage

``` r
gk_correct(
  prepared,
  method = c("none", "robust_z", "common_score_residual", "pc1_panel_residual"),
  markers = NULL,
  row_center = FALSE
)
```

## Arguments

- prepared:

  A
  [`gk_prepare()`](https://github.com/CTTIR/gatekeepR/reference/gk_prepare.md)
  result.

- method:

  One of `"none"`, `"robust_z"`, `"common_score_residual"` or
  `"pc1_panel_residual"`.

- markers:

  Character vector of markers to correct. `NULL` selects identity and
  conditional identity markers.

- row_center:

  Whether to subtract each cell's residual mean. This changes the
  meaning of per-cell values and is `FALSE` by default.

## Value

A `gk_corrected` list with `matrix`, `model`, `config_sha256` and
`source_sha256`. The model has class `gk_correction_model` and stores
all fitted centres, scales, rotations and coefficients.

## See also

Other corrections:
[`gk_fit_residual_model()`](https://github.com/CTTIR/gatekeepR/reference/gk_fit_residual_model.md)

## Examples

``` r
prep <- gk_prepare(gk_example_path("example-slide"), gk_example_config(), quiet = TRUE)
corrected <- gk_correct(prep, method = "robust_z")
corrected$model
#> <gk_correction_model>: "robust_z" for 9 markers
#> • Fitted markers: "PanCK", "CD45", "CD3e", "CD4", "CD8", "CD20", "CD68", and
#>   "CD31"
#> • Excluded markers: "CD21"
#> • Row centring: FALSE
```
