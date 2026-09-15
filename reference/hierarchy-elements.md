# Hierarchy rules, flags, refinements and overrides

**\[experimental\]**

Building blocks of a phenotype hierarchy:

- `gk_rule()` assigns `label` to cells positive for every marker in
  `all_of`, for at least one marker in `any_of` (ignored when empty) and
  negative for every marker in `none_of`. Rules are evaluated in order
  and the first match wins.

- `gk_flag()` is a named Boolean expression evaluated before the rules;
  its policy (`exclude`, `flag_only` or `unresolved`) is set in
  [`gk_hierarchy()`](https://github.com/CTTIR/gatekeepR/reference/gk_hierarchy.md).

- `gk_refinement()` relabels cells of `from_label` that are positive for
  an enabled state call (`marker` within `parent`), e.g. CD4 T cells
  that are FOXP3-positive become Treg cells.

- `gk_override()` replaces the threshold method or arguments of one
  marker on one image, with a mandatory reason. Overrides are part of
  the configuration and its hash; they never live in code.

## Usage

``` r
gk_rule(
  rule_id,
  label,
  all_of = character(),
  any_of = character(),
  none_of = character(),
  on_uncallable = "disable_rule",
  review = NULL,
  pending_label = NULL,
  decisions = NULL
)

gk_flag(all_of = character(), any_of = character(), none_of = character())

gk_refinement(rule_id, marker, parent, from_label, to_label)

gk_override(
  image_id,
  marker,
  parent = NA_character_,
  threshold_method = NULL,
  threshold_args = NULL,
  reason
)
```

## Arguments

- rule_id:

  Stable identifier, e.g. `"R010"`.

- label:

  Cell type assigned by the rule.

- all_of, any_of, none_of:

  Character vectors of marker names.

- on_uncallable:

  What to do with markers in `none_of` that are not callable on an
  image: `"disable_rule"` (default) or `"treat_as_negative"`. Markers in
  `all_of` or `any_of` that are not callable always disable the rule.

- review:

  `NULL`, or `"structure"`: matching cells start as `pending_label`
  until a structure decision exists (see
  [`gk_decide_structure()`](https://github.com/CTTIR/gatekeepR/reference/gk_decide_structure.md)).

- pending_label:

  Label of cells awaiting a structure decision.

- decisions:

  Named list or character vector mapping each decision (`Tumor`,
  `Benign`, `Unresolved`) to a label.

- marker, parent:

  State marker and parent set of a refinement or override.

- from_label, to_label:

  Labels before and after refinement.

- image_id:

  Image the override applies to.

- threshold_method, threshold_args:

  Replacement method and arguments; `NULL` keeps the panel's.

- reason:

  Why the override exists (required, recorded).

## Value

Objects of class `gk_rule`, `gk_flag`, `gk_refinement` or `gk_override`.

## See also

Other configuration:
[`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md),
[`gk_config_hash()`](https://github.com/CTTIR/gatekeepR/reference/gk_config_hash.md),
[`gk_hierarchy()`](https://github.com/CTTIR/gatekeepR/reference/gk_hierarchy.md),
[`gk_min_support()`](https://github.com/CTTIR/gatekeepR/reference/gk_min_support.md),
[`gk_panel()`](https://github.com/CTTIR/gatekeepR/reference/gk_panel.md),
[`gk_signal_policy()`](https://github.com/CTTIR/gatekeepR/reference/gk_signal_policy.md),
[`gk_validate_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_validate_config.md),
[`gk_write_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_config.md)

## Examples

``` r
gk_rule("R020", "CD8 T cells", all_of = c("CD45", "CD3e", "CD8"), none_of = "CD4")
#> <gk_rule> "R020" -> "CD8 T cells"
#>   all_of: "CD45", "CD3e", and "CD8"
#>   any_of:
#>   none_of: "CD4"
#>   on_uncallable: "disable_rule"
gk_rule(
  "R010", "Epithelial cells",
  all_of = "PanCK", review = "structure",
  pending_label = "Unreviewed epithelial cells",
  decisions = c(
    Tumor = "Tumor cells", Benign = "Benign epithelial cells",
    Unresolved = "Unresolved epithelial cells"
  )
)
#> <gk_rule> "R010" -> "Epithelial cells"
#>   all_of: "PanCK"
#>   any_of:
#>   none_of:
#>   on_uncallable: "disable_rule"
#>   review: structure, pending as "Unreviewed epithelial cells"
gk_flag(all_of = "PanCK", any_of = c("CD45", "CD3e"))
#> $all_of
#> [1] "PanCK"
#> 
#> $any_of
#> [1] "CD45" "CD3e"
#> 
#> $none_of
#> character(0)
#> 
#> attr(,"class")
#> [1] "gk_flag"
gk_refinement("RF10", "FOXP3", "CD4 T cells", "CD4 T cells", "Treg cells")
#> $rule_id
#> [1] "RF10"
#> 
#> $marker
#> [1] "FOXP3"
#> 
#> $parent
#> [1] "CD4 T cells"
#> 
#> $from_label
#> [1] "CD4 T cells"
#> 
#> $to_label
#> [1] "Treg cells"
#> 
#> attr(,"class")
#> [1] "gk_refinement"
gk_override("slide-07", "CD3e",
  threshold_args = list(rule = "crossing"),
  reason = "Dim staining batch; q99 rule over-conservative (review 2026-03)"
)
#> $image_id
#> [1] "slide-07"
#> 
#> $marker
#> [1] "CD3e"
#> 
#> $parent
#> [1] NA
#> 
#> $threshold_method
#> NULL
#> 
#> $threshold_args
#> $threshold_args$rule
#> [1] "crossing"
#> 
#> 
#> $reason
#> [1] "Dim staining batch; q99 rule over-conservative (review 2026-03)"
#> 
#> attr(,"class")
#> [1] "gk_override"
```
