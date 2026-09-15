# gatekeepR

`gatekeepR` turns per-cell marker measurements from multiplexed tissue
images into cell types that a person has reviewed.

- **Suggest cut-offs:** estimates a threshold for each marker on each
  slide, and says openly when a marker cannot be called.
- **Classify:** applies one declared phenotype hierarchy.
- **Review:** lets a reviewer adjust cut-offs, decide on epithelial
  structures and exclude artefacts in a Shiny app.
- **Lock:** freezes the result into a single immutable review snapshot,
  which every exported file and every later analysis refers to.

> **Status: 1.0.0 release candidate.** The configuration, preparation,
> correction, threshold, classification, review, export and plotting
> paths are implemented. The package is being checked for its first CRAN
> submission.

## Why

Semi-automated gating is where multiplex imaging studies are most
fragile:

- **Automatic cut-offs look confident even when a marker has no
  signal.** Gating code tends to produce a threshold for every marker,
  including a channel that was never stained.
- **Batch scripts and review apps drift apart.** Each carries its own
  copy of the phenotype rules.
- **Review decisions get lost.** An import can overwrite them, and
  exported files cannot be traced back to the one review they came from.

`gatekeepR` is built so that each of these failures becomes an error or
a visible status instead:

- one classifier shared by batch and app;
- explicit callability;
- append-only review ledgers;
- content-addressed, verifiable export packages.

## Scope

**In scope**

- **Panel definition:** a marker panel with roles (identity, state,
  context, conditional), signal compartments, and localisation rules for
  markers such as nuclear FOXP3 or Ki67.
- **Callability:** checks run before any threshold is estimated (absent,
  constant or unsupported channels).
- **Threshold methods:**
  - manual
  - density valley
  - density tail
  - two-component mixture
  - population density crossing on an embedding
  - parent-specific estimation for state markers
- **Phenotype hierarchy:** declarative, ordered and versioned, with
  explicit classes for ambiguous objects and for cells awaiting review.
- **State calls:** every marker × parent combination is estimated and
  exported, not just the one currently displayed.
- **Review support:** spatial grouping of candidate epithelial
  structures for tumour vs. benign decisions.
- **Review app:** cut-offs, structures, exclusions and deletions, state
  markers. Downloads come only from a locked snapshot.
- **Export verification:** replays and reconciles labels, decisions and
  deletion histories.

**Out of scope**

- Reading tool exports (→ `cellspecR`).
- Segmentation (→ QuPath / `qupflowR`, `segmantR`).
- Spatial statistics, neighbourhoods and cohort analysis (→
  `phenoscapR`).
- Shipping study-specific panels or cut-offs: those live with each
  study.

## Where it sits in CTTIR

    cellspecR (validated cell table + signal policy)
          │
          ▼
    gatekeepR: callability → thresholds → hierarchy → state calls
          │           ▲
          │           └── review app (cut-offs, structures, exclusions)
          ▼
    locked snapshot (review_id, hashes, ledgers, calls)
          │
          ▼
    phenoscapR / cohort statistics / reports

## Interface

| Area | Functions |
|----|----|
| Panel and rules | [`gk_panel()`](https://github.com/CTTIR/gatekeepR/reference/gk_panel.md), [`gk_hierarchy()`](https://github.com/CTTIR/gatekeepR/reference/gk_hierarchy.md), [`gk_read_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_config.md), [`gk_write_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_config.md) |
| Signals | [`gk_prepare()`](https://github.com/CTTIR/gatekeepR/reference/gk_prepare.md), [`gk_callability()`](https://github.com/CTTIR/gatekeepR/reference/gk_callability.md), [`gk_correct()`](https://github.com/CTTIR/gatekeepR/reference/gk_correct.md) |
| Thresholds | [`gk_thresholds()`](https://github.com/CTTIR/gatekeepR/reference/gk_thresholds.md), [`gk_threshold_methods()`](https://github.com/CTTIR/gatekeepR/reference/gk_threshold_methods.md), [`gk_embed()`](https://github.com/CTTIR/gatekeepR/reference/gk_embed.md) |
| Classification | [`gk_classify()`](https://github.com/CTTIR/gatekeepR/reference/gk_classify.md), [`gk_state_calls()`](https://github.com/CTTIR/gatekeepR/reference/gk_state_calls.md), [`gk_structures()`](https://github.com/CTTIR/gatekeepR/reference/gk_structures.md) |
| Review | [`gk_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_review.md), [`gk_set_cut()`](https://github.com/CTTIR/gatekeepR/reference/gk_set_cut.md), [`gk_decide_structure()`](https://github.com/CTTIR/gatekeepR/reference/gk_decide_structure.md), [`gk_dispose()`](https://github.com/CTTIR/gatekeepR/reference/gk_dispose.md), [`gk_set_state()`](https://github.com/CTTIR/gatekeepR/reference/gk_set_state.md), [`gk_revert_last()`](https://github.com/CTTIR/gatekeepR/reference/gk_revert_last.md), [`gk_import_cuts()`](https://github.com/CTTIR/gatekeepR/reference/gk_import_cuts.md), [`gk_replace_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_replace_review.md), [`gk_save_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_save_review.md), [`gk_load_review()`](https://github.com/CTTIR/gatekeepR/reference/gk_load_review.md) |
| Snapshot | [`gk_lock()`](https://github.com/CTTIR/gatekeepR/reference/gk_lock.md), [`gk_export()`](https://github.com/CTTIR/gatekeepR/reference/gk_export.md), [`gk_verify_export()`](https://github.com/CTTIR/gatekeepR/reference/gk_verify_export.md), [`gk_read_export()`](https://github.com/CTTIR/gatekeepR/reference/gk_read_export.md), [`gk_replay()`](https://github.com/CTTIR/gatekeepR/reference/gk_replay.md) |
| Plots | [`gk_plot_overview()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_overview.md), [`gk_plot_density()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_density.md), [`gk_plot_map()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_map.md), [`gk_plot_embedding()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_embedding.md), [`gk_plot_dotplot()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_dotplot.md), [`gk_plot_thresholds()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_thresholds.md), [`gk_plot_states()`](https://github.com/CTTIR/gatekeepR/reference/gk_plot_states.md) |
| Example data | [`gk_example_config()`](https://github.com/CTTIR/gatekeepR/reference/gk_example_config.md), [`gk_example_path()`](https://github.com/CTTIR/gatekeepR/reference/gk_example_path.md), [`gk_simulate()`](https://github.com/CTTIR/gatekeepR/reference/gk_simulate.md) |
| App | [`gk_app()`](https://github.com/CTTIR/gatekeepR/reference/gk_app.md), a review application that also runs from shinylaunchR |

``` r

config <- gk_example_config()
x      <- gk_read_cellspec(gk_example_path("example-slide"))
prep   <- gk_prepare(x, config, quiet = TRUE)
fixed  <- gk_correct(prep, method = "robust_z")
emb    <- gk_embed(prep, correction = fixed, seed = 42)
thr    <- gk_thresholds(prep, config, embedding = emb, correction = fixed)
cls    <- gk_classify(prep, thr, config, correction = fixed)
states <- gk_state_calls(prep, thr, cls, config)
shapes <- gk_structures(cls, prep)

rev    <- gk_review(cls, states, shapes, thr, prep)
snap   <- gk_lock(rev, reviewer = "reviewer-01", status = "REVIEWED")
gk_export(snap, "reviews/example-01")
gk_verify_export("reviews/example-01")
```

## Installation

``` r

# install.packages("pak")
pak::pak("CTTIR/gatekeepR")
```

The development version can be installed from GitHub. Optional features
use packages listed in `Suggests`, including `uwot`, `dbscan`,
`ggplot2`, `shiny` and `patchwork`.

## Contributing

Follows the [CTTIR contributing
guide](https://github.com/CTTIR/.github/blob/main/CONTRIBUTING.md).

## License

MIT
