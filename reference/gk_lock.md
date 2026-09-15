# Lock a review into an immutable snapshot

Lock a review into an immutable snapshot

## Usage

``` r
gk_lock(review, reviewer, status = c("PENDING", "REVIEWED"))
```

## Arguments

- review:

  A
  [`gk_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_review.md)
  object.

- reviewer:

  Reviewer identifier.

- status:

  `"PENDING"` or `"REVIEWED"`.

## Value

An object of class `gk_snapshot`.

## See also

Other export:
[`gk_export()`](https://github.com/CTTIR/gatekeepR/reference/gk_export.md),
[`gk_read_export()`](https://github.com/CTTIR/gatekeepR/reference/gk_read_export.md),
[`gk_verify_export()`](https://github.com/CTTIR/gatekeepR/reference/gk_verify_export.md)
