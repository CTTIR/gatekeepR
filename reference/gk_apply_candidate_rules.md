# Evaluate declarative rules on ternary candidate calls

**\[experimental\]**

Each rule has unique `id`, `label`, and optional named `all` and `any`
lists. List entries specify allowed states for a named marker. All `all`
conditions and at least one `any` condition must match; absent groups
impose no condition. Later matching rules overwrite earlier labels. No
expression is evaluated, and unavailable never implicitly means LOW.
Labels are caller descriptions, not scientific approvals; authorization
flags are always false.

## Usage

``` r
gk_apply_candidate_rules(calls, rules, default_label)
```

## Arguments

- calls:

  Keyed character matrix containing HIGH, LOW or UNAVAILABLE.

- rules:

  Ordered list of declarative rules as described above.

- default_label:

  Nonempty label for rows matching no rule.

## Value

Data frame with cell_id, label, rule_id, review_authorized and
production_eligible. Both authorization fields are always FALSE.

## See also

Other classification:
[`gk_classify()`](https://github.com/CTTIR/gatekeepR/reference/gk_classify.md),
[`gk_fixed_signal_calls()`](https://github.com/CTTIR/gatekeepR/reference/gk_fixed_signal_calls.md),
[`gk_state_calls()`](https://github.com/CTTIR/gatekeepR/reference/gk_state_calls.md),
[`gk_structures()`](https://github.com/CTTIR/gatekeepR/reference/gk_structures.md)

## Examples

``` r
calls <- matrix(c("HIGH", "UNAVAILABLE"), 2, 1,
  dimnames = list(c("one", "two"), "A"))
rules <- list(list(id = "signal", label = "candidate", all = list(A = "HIGH")))
gk_apply_candidate_rules(calls, rules, "unresolved")
#>   cell_id      label rule_id review_authorized production_eligible
#> 1     one  candidate  signal             FALSE               FALSE
#> 2     two unresolved    <NA>             FALSE               FALSE
```
