# Apply fixed cutoffs with explicit raw-support availability

**\[experimental\]**

Selected signals and underlying features are assessed over the full
supplied image scope. A score can be HIGH or LOW only when enabled,
finite, supported by at least `min_finite` nonnegative selected values
with distinct values, and its selected source feature has at least
`min_finite` finite values with distinct values. The named source value
must also be finite at that cell; finite selected values cannot
substitute for missing source measurements. All other calls remain
UNAVAILABLE. No threshold is fitted.

## Usage

``` r
gk_fixed_signal_calls(
  scores,
  selected,
  selected_features,
  raw_features,
  cutoffs,
  enabled,
  min_finite = 20L
)
```

## Arguments

- scores:

  Keyed numeric score matrix; its rows may be a subset of selected.

- selected:

  Keyed numeric selected-signal matrix for the full image scope.

- selected_features:

  Character matrix matching selected, naming each underlying raw
  feature. NA denotes an unavailable selected source.

- raw_features:

  Keyed numeric raw-feature matrix with the same row order as selected.
  Source-feature support counts all finite values.

- cutoffs:

  Named numeric vector in exact score-column order.

- enabled:

  Named logical vector in exact score-column order.

- min_finite:

  Minimum finite count, an integer of at least two.

## Value

List with ternary `calls`, selected-marker and source-feature support.

## See also

Other classification:
[`gk_apply_candidate_rules()`](https://github.com/CTTIR/gatekeepR/reference/gk_apply_candidate_rules.md),
[`gk_classify()`](https://github.com/CTTIR/gatekeepR/reference/gk_classify.md),
[`gk_state_calls()`](https://github.com/CTTIR/gatekeepR/reference/gk_state_calls.md),
[`gk_structures()`](https://github.com/CTTIR/gatekeepR/reference/gk_structures.md)

## Examples

``` r
x <- matrix(1:4, 4, 1, dimnames = list(letters[1:4], "A"))
f <- x
colnames(f) <- "raw_a"
sources <- matrix("raw_a", 4, 1, dimnames = dimnames(x))
gk_fixed_signal_calls(x, x, sources, f, c(A = 2), c(A = TRUE), 2)$calls
#>   A     
#> a "LOW" 
#> b "HIGH"
#> c "HIGH"
#> d "HIGH"
```
