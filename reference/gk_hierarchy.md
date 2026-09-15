# Declare a phenotype hierarchy

**\[experimental\]**

An ordered set of
[`gk_rule()`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)s
(first match wins), flags evaluated before the rules with an explicit
policy each, and the labels used for cells that match no rule, that are
excluded by a flag, or that are unresolved.

Flag policies:

- `exclude`: the cell is labelled `excluded_label` and not analysed.

- `unresolved`: the cell is labelled `unresolved_label`.

- `flag_only`: the flag is recorded and the cell continues through the
  rules.

The chosen policy is part of the configuration hash and applies
identically in batch code and in the review app.

## Usage

``` r
gk_hierarchy(
  rules,
  flags = list(),
  flag_policy = list(),
  undefined_label = "Undefined",
  excluded_label = "Excluded",
  unresolved_label = "Unresolved",
  version,
  rationale = ""
)
```

## Arguments

- rules:

  List of
  [`gk_rule()`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)
  objects, in evaluation order.

- flags:

  Named list of
  [`gk_flag()`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)
  objects.

- flag_policy:

  Named list or character vector giving the policy of every flag.

- undefined_label, excluded_label, unresolved_label:

  Labels for cells matching no rule, excluded by a flag, or unresolved
  by a flag.

- version:

  Version string of the hierarchy (required).

- rationale:

  Free text recorded with the hierarchy.

## Value

An object of class `gk_hierarchy`.

## See also

Other configuration:
[`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md),
[`gk_config_hash()`](https://github.com/CTTIR/gatekeepR/reference/gk_config_hash.md),
[`gk_min_support()`](https://github.com/CTTIR/gatekeepR/reference/gk_min_support.md),
[`gk_panel()`](https://github.com/CTTIR/gatekeepR/reference/gk_panel.md),
[`gk_signal_policy()`](https://github.com/CTTIR/gatekeepR/reference/gk_signal_policy.md),
[`gk_validate_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_validate_config.md),
[`gk_write_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_config.md),
[`hierarchy-elements`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)

## Examples

``` r
gk_hierarchy(
  rules = list(
    gk_rule("R010", "T cells", all_of = c("CD45", "CD3e")),
    gk_rule("R020", "Other immune cells", all_of = "CD45")
  ),
  flags = list(mixed = gk_flag(all_of = "PanCK", any_of = "CD45")),
  flag_policy = c(mixed = "unresolved"),
  version = "1.0"
)
#> <gk_hierarchy> version "1.0": 2 rules, 1 flag
#>  rule_id              label     all_of any_of none_of on_uncallable review
#>     R010            T cells CD45, CD3e                 disable_rule       
#>     R020 Other immune cells       CD45                 disable_rule       
#> Flag mixed ("unresolved"): all_of "PanCK"; any_of "CD45"; none_of
```
