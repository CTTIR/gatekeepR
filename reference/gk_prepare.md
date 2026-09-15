# Prepare marker signals for gating

**\[experimental\]**

Selects one signal per cell and marker according to the configuration's
signal policy, applies the per-marker transform, resolves localisation
measurements, and computes callability checks that run before any
correction or threshold (see
[`gk_callability()`](https://github.com/CTTIR/gatekeepR/reference/gk_callability.md)).

A panel marker whose measurement is missing from the cell table is a
structural failure (`gatekeepr_error_structure`). A marker that is
present but carries no usable signal is not an error: it is reported as
not callable, and every rule depending on it is disabled later.

## Usage

``` r
gk_prepare(x, config, image_id = NULL, quiet = FALSE)
```

## Arguments

- x:

  A `cellspec` object (see
  [`gk_cellspec()`](https://github.com/CTTIR/gatekeepR/reference/gk_cellspec.md))
  or the path of a cellspec directory.

- config:

  A
  [`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md).

- image_id:

  `NULL` for all images, or the images to keep.

- quiet:

  Suppress the summary message?

## Value

An object of class `gk_prepared`, a list with:

- `cells`: data frame `image_id`, `cell_id`, `sample_id`, `x`, `y`;

- `signal_raw`: cells x panel markers, selected raw signal (`NA` where
  unavailable);

- `score`: transformed signal;

- `source`: integer matrix, 1 = preferred compartment, 2 = fallback, 0 =
  unavailable; `source_labels` describes the features;

- `localization`: named list of per-marker data frames with `numerator`,
  `denominator`, `ratio` and `evaluable`;

- `callability`: see
  [`gk_callability()`](https://github.com/CTTIR/gatekeepR/reference/gk_callability.md);

- `transforms`: marker, transform and cofactor;

- `config`, `config_sha256`, `source_sha256` and
  `source_manifest_sha256`.

## See also

Other preparation:
[`gk_callability()`](https://github.com/CTTIR/gatekeepR/reference/gk_callability.md)

## Examples

``` r
x <- gk_read_cellspec(gk_example_path("example-slide"))
prep <- gk_prepare(x, gk_example_config())
#> ✔ Prepared 8,000 cells on 1 image, 12 markers.
#> ! 1 image x marker combination not callable: "CD21".
prep
#> <gk_prepared>: 8,000 cells, 1 image, 12 markers
#> • Config SHA-256: "2bdc84a35985"
#> • Source SHA-256: "5861333323bd"
#> Callability: NOT_CALLABLE_ABSENT = 1; NOT_GATED = 1; PENDING_THRESHOLD = 10
gk_callability(prep)
#>      image_id marker                 role              status  support
#> 1  example-01  PanCK             identity   PENDING_THRESHOLD       ok
#> 2  example-01   CD45             identity   PENDING_THRESHOLD       ok
#> 3  example-01   CD3e             identity   PENDING_THRESHOLD       ok
#> 4  example-01    CD4             identity   PENDING_THRESHOLD       ok
#> 5  example-01    CD8             identity   PENDING_THRESHOLD       ok
#> 6  example-01   CD20             identity   PENDING_THRESHOLD       ok
#> 7  example-01   CD68             identity   PENDING_THRESHOLD       ok
#> 8  example-01   CD31             identity   PENDING_THRESHOLD       ok
#> 9  example-01   CD21 conditional_identity NOT_CALLABLE_ABSENT constant
#> 10 example-01    SMA              context           NOT_GATED       ok
#> 11 example-01  FOXP3                state   PENDING_THRESHOLD       ok
#> 12 example-01   Ki67                state   PENDING_THRESHOLD       ok
#>                                            details n_cells n_available
#> 1            Signal supports threshold estimation.    8000        8000
#> 2            Signal supports threshold estimation.    8000        8000
#> 3            Signal supports threshold estimation.    8000        8000
#> 4            Signal supports threshold estimation.    8000        8000
#> 5            Signal supports threshold estimation.    8000        8000
#> 6            Signal supports threshold estimation.    8000        8000
#> 7            Signal supports threshold estimation.    8000        8000
#> 8            Signal supports threshold estimation.    8000        8000
#> 9                 Signal is constant across cells.    8000        8000
#> 10 Context marker: displayed, never used in rules.    8000        8000
#> 11           Signal supports threshold estimation.    8000        8000
#> 12           Signal supports threshold estimation.    8000        8000
#>    fraction_unavailable        sd   mad fraction_mode    q01    q50      q99
#> 1                     0 182.59163 5.995            NA 2.9699 12.095 788.7522
#> 2                     0 111.18391 7.055            NA 2.8299 12.025 444.4524
#> 3                     0  72.61746 3.760            NA 2.7199  9.240 329.2589
#> 4                     0  43.81275 3.110            NA 2.5099  8.540 218.6017
#> 5                     0  50.02880 2.930            NA 2.5200  8.500 254.0088
#> 6                     0  48.25392 2.890            NA 2.5399  8.280 272.7677
#> 7                     0  78.10408 3.455            NA 2.9500  9.825 396.2048
#> 8                     0  46.11671 2.830            NA 2.4998  8.250 252.4670
#> 9                     0   0.00000 0.000             1 0.0000  0.000   0.0000
#> 10                    0 111.09580 5.305            NA 2.7599 10.610 448.7429
#> 11                    0  38.35708 2.735            NA 2.6100  8.205 208.6020
#> 12                    0  75.70077 3.135            NA 2.6299  8.655 375.6249
```
