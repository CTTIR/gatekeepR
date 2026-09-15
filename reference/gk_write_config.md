# Read and write configuration files

**\[experimental\]**

`gk_write_config()` writes a configuration as pretty-printed canonical
JSON (sorted keys) following
`inst/schema/gatekeepr-config-1.0.0.schema.json`. `gk_read_config()`
parses a file with `jsonlite` (no code is evaluated), rebuilds the
configuration through the constructors and aborts with a
`gatekeepr_error_config` listing every failed check.

## Usage

``` r
gk_write_config(config, path)

gk_read_config(path)
```

## Arguments

- config:

  A
  [`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md).

- path:

  File path.

## Value

`gk_write_config()` returns `config` invisibly; `gk_read_config()`
returns a `gk_config`.

## See also

Other configuration:
[`gk_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_config.md),
[`gk_config_hash()`](https://github.com/CTTIR/gatekeepR/reference/gk_config_hash.md),
[`gk_hierarchy()`](https://github.com/CTTIR/gatekeepR/reference/gk_hierarchy.md),
[`gk_min_support()`](https://github.com/CTTIR/gatekeepR/reference/gk_min_support.md),
[`gk_panel()`](https://github.com/CTTIR/gatekeepR/reference/gk_panel.md),
[`gk_signal_policy()`](https://github.com/CTTIR/gatekeepR/reference/gk_signal_policy.md),
[`gk_validate_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_validate_config.md),
[`hierarchy-elements`](https://github.com/CTTIR/gatekeepR/reference/hierarchy-elements.md)

## Examples

``` r
path <- tempfile(fileext = ".json")
gk_write_config(gk_example_config(), path)
cfg <- gk_read_config(path)
identical(gk_config_hash(cfg), gk_config_hash(gk_example_config()))
#> [1] TRUE
unlink(path)
```
