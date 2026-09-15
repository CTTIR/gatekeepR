# Threshold methods available in gatekeepR

**\[experimental\]**

Lists the threshold estimation methods, the marker roles allowed to use
them, their arguments with defaults, and a description. Set a marker's
method with `threshold_method` and its arguments with `threshold_args`
in
[`gk_panel()`](https://github.com/CTTIR/gatekeepR/reference/gk_panel.md).

State markers also accept `pooled` (default `FALSE`): with
`pooled = TRUE` one estimate is made over the union of the marker's
parent sets and used for every parent, and the threshold table records
this.

## Usage

``` r
gk_threshold_methods()
```

## Value

A data frame with columns `method`, `role_allowed` (roles joined by
`", "`), `arguments` (`name = default` pairs) and `description`.

## See also

Other thresholds:
[`gk_embed()`](https://github.com/CTTIR/gatekeepR/reference/gk_embed.md),
[`gk_thresholds()`](https://github.com/CTTIR/gatekeepR/reference/gk_thresholds.md)

## Examples

``` r
gk_threshold_methods()[, c("method", "role_allowed")]
#>                method                          role_allowed
#> 1              manual identity, conditional_identity, state
#> 2              valley identity, conditional_identity, state
#> 3                tail identity, conditional_identity, state
#> 4             mixture identity, conditional_identity, state
#> 5 population_crossing        identity, conditional_identity
#> 6     parent_crossing                                 state
```
