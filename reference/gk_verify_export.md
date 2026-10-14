# Verify manifest integrity, replay and reconciliation invariants

Verify manifest integrity, replay and reconciliation invariants

## Usage

``` r
gk_verify_export(dir, cellspec_dir = NULL, strict = TRUE)
```

## Arguments

- dir:

  Export directory written by [`gk_export()`](gk_export.md).

- cellspec_dir:

  Optional source cellspec directory.

- strict:

  Abort on the first failed verification group?

## Value

A check data frame with `check`, `ok` and `details`.

## See also

Other export: [`gk_export()`](gk_export.md), [`gk_lock()`](gk_lock.md),
[`gk_read_export()`](gk_read_export.md)
