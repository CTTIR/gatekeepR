# Read a verified export

Read a verified export

## Usage

``` r
gk_read_export(dir, verify = TRUE, expected_review_id = NULL)
```

## Arguments

- dir:

  Export directory.

- verify:

  Verify before reading? `FALSE` permits inspection of legacy or
  untrusted exports and makes no integrity claim.

- expected_review_id:

  Optional full ID passed to
  [`gk_verify_export()`](gk_verify_export.md).

## Value

A `gk_export` list containing snapshot, configuration and tables.

## See also

Other export: [`gk_export()`](gk_export.md), [`gk_lock()`](gk_lock.md),
[`gk_verify_export()`](gk_verify_export.md)
