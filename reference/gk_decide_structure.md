# Decide one structure or bounding box

Decide one structure or bounding box

## Usage

``` r
gk_decide_structure(
  review,
  image_id,
  structure_id = NULL,
  bbox = NULL,
  decision = c("Tumor", "Benign", "Unresolved"),
  reviewer,
  reason
)
```

## Arguments

- review:

  A
  [`gk_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_review.md)
  object.

- image_id:

  Image to change.

- structure_id:

  A structure ID, or `NULL`.

- bbox:

  A `c(xmin, xmax, ymin, ymax)` selection, or `NULL`.

- decision:

  One of `"Tumor"`, `"Benign"` or `"Unresolved"`.

- reviewer:

  Reviewer identifier.

- reason:

  Required reason recorded in the ledger.

## Value

A new `gk_review` object.

## See also

Other review:
[`gk_dispose()`](https://github.com/CTTIR/gatekeepR/reference/gk_dispose.md),
[`gk_import_cuts()`](https://github.com/CTTIR/gatekeepR/reference/gk_import_cuts.md),
[`gk_ledgers()`](https://github.com/CTTIR/gatekeepR/reference/gk_ledgers.md),
[`gk_load_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_load_review.md),
[`gk_replace_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_replace_review.md),
[`gk_replay()`](https://github.com/CTTIR/gatekeepR/reference/gk_replay.md),
[`gk_revert_last()`](https://github.com/CTTIR/gatekeepR/reference/gk_revert_last.md),
[`gk_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_review.md),
[`gk_save_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_save_review.md),
[`gk_set_cut()`](https://github.com/CTTIR/gatekeepR/reference/gk_set_cut.md),
[`gk_set_state()`](https://github.com/CTTIR/gatekeepR/reference/gk_set_state.md)
