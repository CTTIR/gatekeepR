# Declare which measurement represents each marker

**\[experimental\]**

A signal policy chooses, per marker, the compartment and statistic whose
value represents the marker, with an optional fallback compartment used
per cell when the preferred value is missing or below `min_value`. The
result has the same structure as
[`cellspecR::cs_signal_policy()`](https://cttir.github.io/cellspecR/reference/cs_signal_policy.html),
so either can be used in
[`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md).

## Usage

``` r
gk_signal_policy(
  marker,
  compartment = "cell",
  statistic = "mean",
  fallback_compartment = NA_character_,
  min_value = 0
)
```

## Arguments

- marker:

  Character vector of unique marker names.

- compartment:

  Preferred compartment per marker: `"cell"`, `"nucleus"`, `"cytoplasm"`
  or `"membrane"`. Recycled.

- statistic:

  Statistic per marker, e.g. `"mean"`. Recycled.

- fallback_compartment:

  Compartment used when the preferred value is unavailable, or `NA` for
  none. Recycled.

- min_value:

  Values below this are treated as unavailable. Recycled.

## Value

A data frame of class `gk_signal_policy` (also `cs_signal_policy`) with
columns `marker`, `compartment`, `statistic`, `fallback_compartment` and
`min_value`.

## See also

Other configuration:
[`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md),
[`gk_config_hash()`](https://github.com/CTTIR/gatekeepR/reference/gk_config_hash.md),
[`gk_hierarchy()`](https://github.com/CTTIR/gatekeepR/reference/gk_hierarchy.md),
[`gk_min_support()`](https://github.com/CTTIR/gatekeepR/reference/gk_min_support.md),
[`gk_panel()`](https://github.com/CTTIR/gatekeepR/reference/gk_panel.md),
[`gk_validate_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_validate_config.md),
[`gk_write_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_config.md),
[`hierarchy-elements`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)

## Examples

``` r
gk_signal_policy(
  marker = c("CD3e", "FOXP3", "PanCK"),
  compartment = c("cell", "nucleus", "cytoplasm"),
  fallback_compartment = c(NA, NA, "cell")
)
#> <gk_signal_policy> for 3 markers
#>  marker compartment statistic fallback_compartment min_value
#>    CD3e        cell      mean                 <NA>         0
#>   FOXP3     nucleus      mean                 <NA>         0
#>   PanCK   cytoplasm      mean                 cell         0
```
