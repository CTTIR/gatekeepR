# Canonical hash of a configuration

**\[experimental\]**

SHA-256 of the canonical JSON form of a configuration: object keys
sorted, no insignificant whitespace, numbers in shortest round-trip
form. The hash is therefore identical for configurations that differ
only in key order, whitespace or numeric spelling in their JSON files,
and changes whenever a rule, threshold setting, flag policy, override or
refinement changes.

## Usage

``` r
gk_config_hash(config)
```

## Arguments

- config:

  A
  [`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md).

## Value

A 64-character lowercase hexadecimal string.

## See also

Other configuration:
[`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md),
[`gk_hierarchy()`](https://github.com/CTTIR/gatekeepR/reference/gk_hierarchy.md),
[`gk_min_support()`](https://github.com/CTTIR/gatekeepR/reference/gk_min_support.md),
[`gk_panel()`](https://github.com/CTTIR/gatekeepR/reference/gk_panel.md),
[`gk_signal_policy()`](https://github.com/CTTIR/gatekeepR/reference/gk_signal_policy.md),
[`gk_validate_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_validate_config.md),
[`gk_write_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_config.md),
[`hierarchy-elements`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)

## Examples

``` r
gk_config_hash(gk_example_config())
#> [1] "2bdc84a359852919307483c7b938813135e5ed1d77cbf339ab19b33480f5c232"
```
