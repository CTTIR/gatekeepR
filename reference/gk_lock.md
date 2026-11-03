# Lock a review into an immutable snapshot

The version 2 review ID binds source identity, typed replay inputs,
effective outputs, ledgers, correction model, reviewer and status. It is
a content hash, not a signature or proof of a reviewer's identity.
REVIEWED records the human reviewer's assertion; it does not certify
scientific or clinical validity.

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
