# Declare a marker panel

**\[experimental\]**

A panel lists the markers used for gating, their role and how their
signal is transformed and thresholded. Arguments are vectorised over
`marker`; scalar arguments are recycled.

Roles:

- `identity`: used in hierarchy rules.

- `conditional_identity`: used in rules only on images where it is
  callable; when it is not callable, rules requiring it are disabled and
  it is treated as negative where rules exclude it.

- `state`: called within parent cell types (see
  [`gk_state_calls()`](https://github.com/CTTIR/gatekeepR/reference/gk_state_calls.md)).

- `context`: measured and displayed, never used in rules.

## Usage

``` r
gk_panel(
  marker,
  role,
  transform = "asinh",
  cofactor = 5,
  threshold_method = "mixture",
  threshold_args = list(),
  parents = list(),
  localization = NULL,
  optional = FALSE,
  min_support = gk_min_support()
)
```

## Arguments

- marker:

  Character vector of unique marker names; each must appear in the
  signal policy of the configuration.

- role:

  Role per marker (see above).

- transform:

  `"asinh"` (`asinh(x / cofactor)`), `"log1p"` or `"none"`.

- cofactor:

  Positive cofactor for `asinh`.

- threshold_method:

  Method per marker, see
  [`gk_threshold_methods()`](https://github.com/CTTIR/gatekeepR/reference/gk_threshold_methods.md).

- threshold_args:

  Method arguments: either one list used for every marker, or a list
  named by marker whose elements are lists.

- parents:

  State markers only: the parent sets (names from `parent_sets` in
  [`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md))
  within which the marker is estimated and called. Either a character
  vector used for every state marker, or a list named by marker.

- localization:

  `NULL`, or a list named by marker whose elements are lists with
  `numerator` and `denominator` compartments, `min_ratio` and optionally
  `statistic` (default `"mean"`), e.g.
  `list(FOXP3 = list(numerator = "nucleus", denominator = "cytoplasm", min_ratio = 1.5))`.

- optional:

  Logical per marker. A non-callable optional marker only disables its
  own rules; a non-callable required marker additionally raises a
  `gatekeepr_warning_uncallable` warning. Neither blocks an image.

- min_support:

  A
  [`gk_min_support()`](https://github.com/CTTIR/gatekeepR/reference/gk_min_support.md)
  object used for every marker, or a list of them named by marker.

## Value

An object of class `gk_panel`: a list with `markers` (a data frame with
`marker`, `role`, `transform`, `cofactor`, `threshold_method`,
`optional`) and per-marker named lists `threshold_args`, `parents`,
`localization` and `min_support`.

## See also

Other configuration:
[`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md),
[`gk_config_hash()`](https://github.com/CTTIR/gatekeepR/reference/gk_config_hash.md),
[`gk_hierarchy()`](https://github.com/CTTIR/gatekeepR/reference/gk_hierarchy.md),
[`gk_min_support()`](https://github.com/CTTIR/gatekeepR/reference/gk_min_support.md),
[`gk_signal_policy()`](https://github.com/CTTIR/gatekeepR/reference/gk_signal_policy.md),
[`gk_validate_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_validate_config.md),
[`gk_write_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_config.md),
[`hierarchy-elements`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)

## Examples

``` r
gk_panel(
  marker = c("CD45", "CD3e", "FOXP3"),
  role = c("identity", "identity", "state"),
  threshold_method = c("mixture", "mixture", "parent_crossing"),
  parents = list(FOXP3 = "T cells"),
  localization = list(
    FOXP3 = list(numerator = "nucleus", denominator = "cytoplasm", min_ratio = 1.5)
  )
)
#> <gk_panel> with 3 markers
#>  marker     role transform cofactor threshold_method optional parents
#>    CD45 identity     asinh        5          mixture    FALSE        
#>    CD3e identity     asinh        5          mixture    FALSE        
#>   FOXP3    state     asinh        5  parent_crossing    FALSE T cells
#>              localization
#>                          
#>                          
#>  nucleus/cytoplasm >= 1.5
```
