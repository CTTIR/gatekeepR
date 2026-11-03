# Correct prepared marker scores

**\[experimental\]**

Applies a deterministic correction to transformed marker scores. Markers
on images that fail the raw support checks are excluded from fitting and
are `NA` in the corrected matrix. Missing measurements remain `NA`.
Fitting uses all supported images together; residual methods use median
imputation internally without exposing imputed values as measurements.
The fitted parameters are returned in a `gk_correction_model` and can be
applied again to the same prepared data. Stored correction models from
older data-hash versions must be regenerated from their original source
and configuration. For migration of the separate frozen residual
parameter models, see
[`gk_apply_residual_model()`](gk_fit_residual_model.md).

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

  A [`gk_prepare()`](gk_prepare.md) result.

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
[`gk_fit_residual_model()`](gk_fit_residual_model.md),
[`gk_import_residual_model()`](gk_import_residual_model.md)

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
