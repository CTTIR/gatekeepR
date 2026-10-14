# Lock a review into an immutable snapshot

Lock a review into an immutable snapshot

## Usage

``` r
gk_lock(review, reviewer, status = c("PENDING", "REVIEWED"))
```

## Arguments

- review:

  A [`gk_review()`](gk_review.md) object.

- reviewer:

  Reviewer identifier.

- status:

  `"PENDING"` or `"REVIEWED"`.

## Value

An object of class `gk_snapshot`.

## See also

Other export: [`gk_export()`](gk_export.md),
[`gk_read_export()`](gk_read_export.md),
[`gk_verify_export()`](gk_verify_export.md)
