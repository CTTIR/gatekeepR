# Review and reproducibility

Review actions are append-only. Each action has an order, reviewer,
reason, and target identity. The effective result is calculated by
replaying those actions in order.

``` r

review <- gk_review(classification, states, structures, thresholds, prep)
review <- gk_set_cut(review, marker = "marker_a", estimate = 0.5,
  reviewer = "reviewer-01", reason = "manual boundary")
review <- gk_dispose(review, cell_id = "cell-001", disposition = "DELETE",
  reviewer = "reviewer-01", reason = "out of tissue")
reviewed <- gk_replay(review)
```

[`gk_save_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_save_review.md)
writes a staged, checksummed review directory and
[`gk_load_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_load_review.md)
restores it. Once the review is complete,
[`gk_lock()`](https://github.com/CTTIR/gatekeepR/reference/gk_lock.md)
blocks further mutation and
[`gk_export()`](https://github.com/CTTIR/gatekeepR/reference/gk_export.md)
writes the reproducible result. Verify it before delivery:

``` r

gk_save_review(review, "review")
gk_lock(review, reviewer = "reviewer-01")
export <- gk_export(review, "export")
gk_verify_export(export)
```

The verification step checks identifiers, configuration and source
hashes, ledger replay, deletion history, and threshold hashes. It is
suitable for a batch validation job as well as for a human review
handoff.
