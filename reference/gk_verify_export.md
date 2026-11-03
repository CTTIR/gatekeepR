# Verify content identity, replay and reconciliation invariants

Version 2 checks typed contents, source identity, correction model and
every ledger, then reconstructs the base review and compares effective
cells, scores and state calls. Legacy exports can be inspected
explicitly with `gk_read_export(verify = FALSE)`, but require a new
review and lock to obtain this verification contract. No export files
are modified.

## Usage

``` r
gk_verify_export(
  dir,
  cellspec_dir = NULL,
  strict = TRUE,
  expected_review_id = NULL
)
```

## Arguments

- dir:

  Export directory written by [`gk_export()`](gk_export.md).

- cellspec_dir:

  Optional source cellspec directory, checked against the source and
  prepared score contents.

- strict:

  Abort on failed verification?

- expected_review_id:

  Optional independently retained full SHA-256 review ID (the snapshot's
  `review_id_full`).

## Value

A check data frame with `check`, `ok` and `details`.

## Details

Hashes are not signatures. Keep the full review ID independently and
supply `expected_review_id` when verification must detect a replaced
whole export.

## See also

Other export: [`gk_export()`](gk_export.md), [`gk_lock()`](gk_lock.md),
[`gk_read_export()`](gk_read_export.md)
