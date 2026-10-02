# Diagnose fixed state thresholds with explicit parent and localization scope

**\[experimental\]**

Each column is an independent state test. Parent eligibility is supplied
by the caller and is not scientific authorization. Optional localization
uses `(numerator + offset) / (denominator + offset) >= minimum`; both
measurements and their offset-adjusted operands must be finite.
Nonfinite ratios cannot be positive. `audit_missing` explicitly selects
whether nonfinite or unavailable measurements produce FALSE or NA in the
legacy audit flag. The separate nullable positive flag is NA whenever
the measurement, threshold or parent is unavailable or ineligible.
Missingness status takes precedence over threshold availability, then
parent eligibility. No model, threshold or authorization is inferred.

## Usage

``` r
gk_fixed_state_diagnostics(
  values,
  cutoffs,
  parent,
  localization_numerator = NULL,
  localization_denominator = NULL,
  localization_minimum = NULL,
  localization_offset = 1e-09,
  audit_missing
)
```

## Arguments

- values:

  Keyed numeric matrix of state measurements in threshold units.

- cutoffs:

  Named numeric vector in exact state-column order.

- parent:

  Keyed logical matrix matching values; NA means unknown eligibility.

- localization_numerator, localization_denominator:

  Optional keyed numeric matrices matching values, in caller-specified
  common units.

- localization_minimum:

  Named numeric vector matching columns. NA disables localization for
  that column; finite values enable it.

- localization_offset:

  Finite nonnegative scalar added to both operands.

- audit_missing:

  Named character vector of `false` or `propagate` per state.

## Value

Long data frame with cell_id, state, audit_positive,
measurement_evaluable, parent_eligible, threshold_available,
diagnostic_status, nullable_positive, review_authorized and
production_eligible. Authorization is always FALSE.

## Examples

``` r
x <- matrix(c(1, NA), 2, 1, dimnames = list(c("a", "b"), "state"))
parent <- matrix(TRUE, 2, 1, dimnames = dimnames(x))
gk_fixed_state_diagnostics(x, c(state = 1), parent,
  audit_missing = c(state = "propagate"))
#>   cell_id state audit_positive measurement_evaluable parent_eligible
#> a       a state           TRUE                  TRUE            TRUE
#> b       b state             NA                 FALSE            TRUE
#>   threshold_available                       diagnostic_status nullable_positive
#> a                TRUE                     EVALUABLE_RULE_ONLY              TRUE
#> b                TRUE UNAVAILABLE_MEASUREMENT_OR_LOCALIZATION                NA
#>   review_authorized production_eligible
#> a             FALSE               FALSE
#> b             FALSE               FALSE
```
