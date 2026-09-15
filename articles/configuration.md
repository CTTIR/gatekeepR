# Configuration as data

Configuration is explicit and serializable. The example configuration is
useful for smoke tests and for learning the object shape.

``` r

cfg <- gk_example_config()
gk_validate_config(cfg)
#> ✔ Configuration valid (8 checks passed).
gk_config_hash(cfg)
#> [1] "2bdc84a359852919307483c7b938813135e5ed1d77cbf339ab19b33480f5c232"
```

For a project configuration, declare the panel, signal policies,
phenotype hierarchy, and minimum support rules with
[`gk_panel()`](https://github.com/CTTIR/gatekeepR/reference/gk_panel.md),
[`gk_signal_policy()`](https://github.com/CTTIR/gatekeepR/reference/gk_signal_policy.md),
[`gk_hierarchy()`](https://github.com/CTTIR/gatekeepR/reference/gk_hierarchy.md),
and
[`gk_min_support()`](https://github.com/CTTIR/gatekeepR/reference/gk_min_support.md).
Validate it before preparing data:

``` r

cfg <- gk_config(
  panel = gk_panel(c("marker_a", "marker_b")),
  hierarchy = gk_hierarchy(...),
  signal_policy = gk_signal_policy(...),
  min_support = gk_min_support(...)
)
gk_validate_config(cfg)
gk_write_config(cfg, "config.json")
```

The configuration hash is recorded with prepared objects, reviews, and
exports. Changing a rule therefore creates a new computational identity
instead of silently changing an existing review.
