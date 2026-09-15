# Callability rules for a marker

**\[experimental\]**

Sets the checks that decide whether a marker can be called on an image
before and after threshold estimation (see
[`gk_callability()`](https://github.com/CTTIR/gatekeepR/reference/gk_callability.md)).

## Usage

``` r
gk_min_support(
  min_cells = 20L,
  max_unavailable = 0.2,
  min_auc = 0.65,
  near_constant_mode_fraction = 0.99
)
```

## Arguments

- min_cells:

  Minimum number of available cells, and minimum cells per positive and
  negative pool.

- max_unavailable:

  Largest fraction of cells whose signal is unavailable (missing or
  below the policy's `min_value`) before the marker is
  `NOT_CALLABLE_UNAVAILABLE`.

- min_auc:

  Minimum AUC between positive and negative pools for the crossing
  methods. The AUC describes internally selected pools and is not a
  validated accuracy.

- near_constant_mode_fraction:

  A marker whose median absolute deviation is zero and whose most
  frequent value covers at least this fraction of available cells is
  `NOT_CALLABLE_ABSENT`.

## Value

A list of class `gk_min_support`.

## See also

Other configuration:
[`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md),
[`gk_config_hash()`](https://github.com/CTTIR/gatekeepR/reference/gk_config_hash.md),
[`gk_hierarchy()`](https://github.com/CTTIR/gatekeepR/reference/gk_hierarchy.md),
[`gk_panel()`](https://github.com/CTTIR/gatekeepR/reference/gk_panel.md),
[`gk_signal_policy()`](https://github.com/CTTIR/gatekeepR/reference/gk_signal_policy.md),
[`gk_validate_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_validate_config.md),
[`gk_write_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_config.md),
[`hierarchy-elements`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)

## Examples

``` r
gk_min_support(min_auc = 0.6)
#> <gk_min_support>: min_cells = 20, max_unavailable = 0.2, min_auc = 0.6,
#> near_constant_mode_fraction = 0.99
```
