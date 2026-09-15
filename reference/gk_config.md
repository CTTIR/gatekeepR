# Assemble a gating configuration

**\[experimental\]**

A configuration is the single source of truth for gating a study: which
measurement represents each marker, the marker panel, the named parent
sets used by state markers, the phenotype hierarchy, per-image threshold
overrides and state-based refinements. It is validated as a whole and
hashed canonically (see
[`gk_config_hash()`](https://github.com/CTTIR/gatekeepR/reference/gk_config_hash.md));
the hash travels with every result produced from it.

## Usage

``` r
gk_config(
  signal_policy,
  panel,
  parent_sets = list(),
  hierarchy,
  overrides = NULL,
  refinements = NULL
)
```

## Arguments

- signal_policy:

  A
  [`gk_signal_policy()`](https://github.com/CTTIR/gatekeepR/reference/gk_signal_policy.md)
  (or `cellspecR` signal policy) data frame.

- panel:

  A
  [`gk_panel()`](https://github.com/CTTIR/gatekeepR/reference/gk_panel.md).

- parent_sets:

  Named list of character vectors of cell-type labels, e.g.
  `list("T cells" = c("CD4 T cells", "CD8 T cells"))`.

- hierarchy:

  A
  [`gk_hierarchy()`](https://github.com/CTTIR/gatekeepR/reference/gk_hierarchy.md).

- overrides:

  `NULL` or a list of
  [`gk_override()`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)
  objects.

- refinements:

  `NULL` or a list of
  [`gk_refinement()`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)
  objects.

## Value

An object of class `gk_config`. Invalid combinations abort with a
`gatekeepr_error_config` listing every failed check.

## See also

[`gk_validate_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_validate_config.md)
for a check table without aborting;
[`vignette("configuration", package = "gatekeepR")`](https://github.com/CTTIR/gatekeepR/articles/configuration.md).

Other configuration:
[`gk_config_hash()`](https://github.com/CTTIR/gatekeepR/reference/gk_config_hash.md),
[`gk_hierarchy()`](https://github.com/CTTIR/gatekeepR/reference/gk_hierarchy.md),
[`gk_min_support()`](https://github.com/CTTIR/gatekeepR/reference/gk_min_support.md),
[`gk_panel()`](https://github.com/CTTIR/gatekeepR/reference/gk_panel.md),
[`gk_signal_policy()`](https://github.com/CTTIR/gatekeepR/reference/gk_signal_policy.md),
[`gk_validate_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_validate_config.md),
[`gk_write_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_config.md),
[`hierarchy-elements`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)

## Examples

``` r
cfg <- gk_example_config()
cfg
#> <gk_config> (schema 1.0.0)
#> • Panel: 12 markers (identity 8, state 2, context 1, conditional_identity 1)
#> • Hierarchy "1.0.0": 9 rules, 1 flag
#> • Parent sets: 3; refinements: 2; overrides: 0
#> • SHA-256: "2bdc84a359852919307483c7b938813135e5ed1d77cbf339ab19b33480f5c232"
gk_config_hash(cfg)
#> [1] "2bdc84a359852919307483c7b938813135e5ed1d77cbf339ab19b33480f5c232"
```
