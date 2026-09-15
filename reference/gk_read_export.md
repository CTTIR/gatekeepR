# Read a verified export

Read a verified export

## Usage

``` r
gk_read_export(dir, verify = TRUE)
```

## Arguments

- dir:

  Export directory.

- verify:

  Verify before reading?

## Value

A `gk_export` list containing snapshot, configuration and tables.

## See also

Other export:
[`gk_export()`](https://github.com/CTTIR/gatekeepR/reference/gk_export.md),
[`gk_lock()`](https://github.com/CTTIR/gatekeepR/reference/gk_lock.md),
[`gk_verify_export()`](https://github.com/CTTIR/gatekeepR/reference/gk_verify_export.md)
