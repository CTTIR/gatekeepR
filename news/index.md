# Changelog

## gatekeepR 1.2.0

Version 1.1.0 was prepared but not released; its changes are included
here.

- Detect native symbolic links, dangling links and Windows junctions
  without relying on the Windows
  [`Sys.readlink()`](https://rdrr.io/r/base/Sys.readlink.html) stub;
  retain manifest and overwrite boundaries across platforms.

- Preserve unavailable marker measurements through correction and state
  calling; honour configured methods/support and validate ordered source
  and score bindings.

- Correct mixture overlap diagnostics and isolate cells by image and
  cell ID.

- Replay identity/state cuts, enablement and undo through the shared
  classifier. Validate checkpoint contents and detect stale concurrent
  sessions.

- Add real review controls, checkpoint/resume, explicit human review
  status and verified snapshot download. Render plots correctly and
  summarize dotplot means.

- Introduce version 2 snapshots/checkpoints and unambiguous data hashes.
  Bind all replay inputs, outputs, review decisions and status; reject
  mutated snapshots and verify staged exports before publication.
  Preserve exact decimal scores.

- Legacy records are preserved; regenerate/review into new paths.
  Explicit unverified inspection remains available for legacy exports.
  Frozen residual parameters require explicit import and downstream
  requalification, not refitting.

- Fix every plot helper
  ([`gk_plot_density()`](../reference/gk_plot_density.md),
  [`gk_plot_thresholds()`](../reference/gk_plot_thresholds.md),
  [`gk_plot_map()`](../reference/gk_plot_map.md),
  [`gk_plot_dotplot()`](../reference/gk_plot_dotplot.md),
  [`gk_plot_states()`](../reference/gk_plot_states.md),
  [`gk_plot_embedding()`](../reference/gk_plot_embedding.md) and
  [`gk_plot_overview()`](../reference/gk_plot_overview.md)), which
  failed when drawn with “Can’t subset `.data` outside of a data mask
  context”. The tests now build each plot instead of only checking its
  class.

- Standardize the named v5 package logo across README, documentation
  pages and available application headers, with matching light and dark
  artwork.

- Add fixed numerical threshold calls and state diagnostics with
  explicit parent eligibility, localization, missingness and
  non-authorizing audit outputs.

- Add authenticated external residual-parameter import without fitting,
  fixed raw-support-aware ternary calls, and declarative candidate rules
  with explicit unavailable states. These APIs never authorize
  scientific review or production.

- Preserve review session ownership across checkpoint saves, reject
  foreign-owner writes, and serialize save/load operations with a
  separate filesystem lock.

- Added
  [`gk_fit_residual_model()`](../reference/gk_fit_residual_model.md) and
  [`gk_apply_residual_model()`](../reference/gk_fit_residual_model.md)
  for freezing common-score identity and first-principal-component panel
  residual spaces. Application reuses fitted parameters without
  refitting, requires the exact marker dictionary, and preserves
  optional missing values. Content hashes bind model parameters, typed
  metadata and caller-supplied threshold records. Raw-channel support,
  training-image scope and biological decisions remain explicit caller
  responsibilities; existing
  [`gk_correct()`](../reference/gk_correct.md) behaviour is unchanged.

- Cell-table readers recognize canonical cellspecR directories in
  Parquet and typed TSV formats. Explicit canonical writes delegate to
  cellspecR and preserve metadata, adjacency and exact numeric values.
  They require the optional cellspecR dependency and valid declared
  image calibration.

- [`gk_write_cellspec()`](../reference/gk_write_cellspec.md) retains its
  legacy default for compatibility and adds an explicit `format`
  argument. The legacy format is planned for retirement after migration
  is qualified; new integrations should select canonical `"parquet"` or
  `"tsv.gz"`. Schema errors never trigger a legacy fallback.

- Prepare the first CRAN submission: the documentation is declared as
  British English (`Language: en-GB`), a spelling word list is added,
  and the version is aligned across `DESCRIPTION`, `inst/CITATION`,
  `CITATION.cff`, `.zenodo.json` and the README.

## gatekeepR 1.0.0

Initial package implementation; CRAN publication was not established.

- Added the study-neutral configuration model, cellspec 1.0 adapter,
  preparation and callability checks, simulator, and bundled example
  data.
- Added reproducible score corrections, per-image threshold estimation
  with evidence, and PCA/UMAP population embeddings.
- Added declarative classification, state calls, structure review,
  append-only review ledgers, persistence, immutable snapshots, and
  verifiable exports.
- Added plotting helpers, a Shiny review shell, reproducibility
  vignettes, and benchmark templates.
