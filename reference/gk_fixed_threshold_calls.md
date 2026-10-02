# Apply fixed score thresholds without raw-support assessment

**\[experimental\]**

This numerical diagnostic does not establish raw measurement support or
scientific eligibility. Disabled, missing or nonfinite scores and
thresholds produce UNAVAILABLE. Equality to a finite cutoff produces
HIGH.

## Usage

``` r
gk_fixed_threshold_calls(scores, cutoffs, enabled)
```

## Arguments

- scores:

  Keyed numeric score matrix.

- cutoffs:

  Named numeric vector in exact column order.

- enabled:

  Named logical vector in exact column order, without missingness.

## Value

Keyed character matrix containing HIGH, LOW or UNAVAILABLE.

## Examples

``` r
x <- matrix(c(1, NA), 2, 1, dimnames = list(c("a", "b"), "signal"))
gk_fixed_threshold_calls(x, c(signal = 1), c(signal = TRUE))
#>   signal       
#> a "HIGH"       
#> b "UNAVAILABLE"
```
