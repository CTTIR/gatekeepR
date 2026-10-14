# Estimate per-image marker thresholds

**\[experimental\]**

Estimates thresholds for identity and conditional identity markers.
Support is checked before estimation, and every method records a status
rather than inventing a cut when its input is absent, underpowered or
not separated. State-marker thresholds are estimated by
[`gk_state_calls()`](gk_state_calls.md) after parent labels are
available.

## Usage

``` r
gk_thresholds(
  prepared,
  config,
  embedding = NULL,
  correction = NULL,
  seed = 5420L
)
```

## Arguments

- prepared:

  A [`gk_prepare()`](gk_prepare.md) result.

- config:

  The configuration used to prepare the data.

- embedding:

  An optional [`gk_embed()`](gk_embed.md) result for
  `population_crossing`.

- correction:

  `NULL` or a [`gk_correct()`](gk_correct.md) result.

- seed:

  Seed used when sampling embedding populations.

## Value

An object of class `gk_thresholds`, a data frame with one row per image
and marker, the threshold result columns, and an `evidence` attribute
containing density and pool data for plotting.

## See also

Other thresholds: [`gk_embed()`](gk_embed.md),
[`gk_threshold_methods()`](gk_threshold_methods.md)

## Examples

``` r
prep <- gk_prepare(gk_example_path("example-slide"), gk_example_config(), quiet = TRUE)
thresholds <- gk_thresholds(prep, gk_example_config(), seed = 1L)
thresholds[, c("marker", "status", "estimate")]
#> <gk_thresholds>: 9 image x marker results
#> • Statuses: "CALLABLE = 8; NOT_CALLABLE_ABSENT = 1"
#> • Evidence records: 0
```
