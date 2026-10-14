# Validate a gating configuration

**\[experimental\]**

Runs every configuration check and returns them as a table instead of
aborting. Accepts a [`gk_config()`](gk_config.md) object, a path to a
configuration JSON file, or a list as parsed from such a file.
Construction errors (for example a duplicated `rule_id`) are reported as
a failed `construction` check.

## Usage

``` r
gk_validate_config(config)
```

## Arguments

- config:

  A `gk_config`, a path to a JSON file, or a parsed list.

## Value

A data frame of class `gk_config_checks` with columns `check`, `status`
(`"pass"` or `"fail"`) and `message`.

## See also

Other configuration: [`gk_config()`](gk_config.md),
[`gk_config_hash()`](gk_config_hash.md),
[`gk_hierarchy()`](gk_hierarchy.md),
[`gk_min_support()`](gk_min_support.md), [`gk_panel()`](gk_panel.md),
[`gk_signal_policy()`](gk_signal_policy.md),
[`gk_write_config()`](gk_write_config.md),
[`hierarchy-elements`](hierarchy-elements.md)

## Examples

``` r
gk_validate_config(gk_example_config())
#> ✔ Configuration valid (8 checks passed).
```
