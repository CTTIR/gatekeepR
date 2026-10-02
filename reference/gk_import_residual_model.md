# Import externally frozen residual parameters without fitting

**\[experimental\]**

Validates a numerical parameter bundle and authenticates its external
source file. The caller maps the external format into the documented
parameter fields; the source hash authenticates bytes, not mapping
correctness or scientific approval. No coefficient is estimated or
changed.

## Usage

``` r
gk_import_residual_model(
  parameters,
  source_file,
  source_sha256,
  provenance = list(),
  bindings = list()
)
```

## Arguments

- parameters:

  Named list containing `panel`, `identity_markers`, `identity_robust`,
  `identity_regression`, `identity_center`, `identity_scale`,
  `panel_robust`, `pc_center`, `pc1_rotation`, `panel_regression`,
  `panel_center`, `panel_scale` and `n_training`, with the same shapes
  as a fitted model.

- source_file:

  Existing file from which the parameters were obtained.

- source_sha256:

  Expected lowercase SHA-256 of that file.

- provenance:

  Named list of caller source and transformation metadata.

- bindings:

  Named list of immutable caller policies or thresholds.

## Value

A hash-bound `gk_frozen_residual_model`. The training-score hash is
unavailable; the authenticated source-file hash is stored in provenance.

## See also

Other corrections:
[`gk_correct()`](https://github.com/CTTIR/gatekeepR/reference/gk_correct.md),
[`gk_fit_residual_model()`](https://github.com/CTTIR/gatekeepR/reference/gk_fit_residual_model.md)

## Examples

``` r
x <- cbind(A = seq_len(30), B = sin(seq_len(30)))
fitted <- gk_fit_residual_model(x, c("A", "B"))
fields <- c("panel", "identity_markers", "identity_robust",
  "identity_regression", "identity_center", "identity_scale", "panel_robust",
  "pc_center", "pc1_rotation", "panel_regression", "panel_center",
  "panel_scale", "n_training")
path <- tempfile(fileext = ".rds")
saveRDS(fitted, path)
imported <- gk_import_residual_model(unclass(fitted)[fields], path,
  digest::digest(file = path, algo = "sha256"))
gk_apply_residual_model(x, imported)$identity
#>                 A           B
#>  [1,] -1.80052025  1.80052025
#>  [2,] -1.80304745  1.80304745
#>  [3,] -0.95965027  0.95965027
#>  [4,]  0.01503163 -0.01503163
#>  [5,]  0.28565602 -0.28565602
#>  [6,] -0.33581210  0.33581210
#>  [7,] -1.21722198  1.21722198
#>  [8,] -1.48743363  1.48743363
#>  [9,] -0.83723989  0.83723989
#> [10,]  0.19634994 -0.19634994
#> [11,]  0.72383395 -0.72383395
#> [12,]  0.32102159 -0.32102159
#> [13,] -0.58096749  0.58096749
#> [14,] -1.09207287  1.09207287
#> [15,] -0.68161081  0.68161081
#> [16,]  0.33381759 -0.33381759
#> [17,]  1.08140796 -1.08140796
#> [18,]  0.93460498 -0.93460498
#> [19,]  0.08915445 -0.08915445
#> [20,] -0.61686449  0.61686449
#> [21,] -0.47356547  0.47356547
#> [22,]  0.44807888 -0.44807888
#> [23,]  1.36148880 -1.36148880
#> [24,]  1.48765525 -1.48765525
#> [25,]  0.77135719 -0.77135719
#> [26,] -0.06806843  0.06806843
#> [27,] -0.19808174  0.19808174
#> [28,]  0.56162671 -0.56162671
#> [29,]  1.57336029 -1.57336029
#> [30,]  1.96771164 -1.96771164
unlink(path)
```
