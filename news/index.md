# Changelog

## gatekeepR (development version)

- Added
  [`gk_fit_residual_model()`](https://github.com/CTTIR/gatekeepR/reference/gk_fit_residual_model.md)
  and
  [`gk_apply_residual_model()`](https://github.com/CTTIR/gatekeepR/reference/gk_fit_residual_model.md)
  for freezing common-score identity and first-principal-component panel
  residual spaces. Application reuses fitted parameters without
  refitting, requires the exact marker dictionary, and preserves
  optional missing values. Content hashes bind model parameters, typed
  metadata and caller-supplied threshold records. Raw-channel support,
  training-image scope and biological decisions remain explicit caller
  responsibilities; existing
  [`gk_correct()`](https://github.com/CTTIR/gatekeepR/reference/gk_correct.md)
  behavior is unchanged.

- Cell-table readers recognize canonical cellspecR directories in
  Parquet and typed TSV formats. Explicit canonical writes delegate to
  cellspecR and preserve metadata, adjacency and exact numeric values.
  They require the optional cellspecR dependency and valid declared
  image calibration.

- [`gk_write_cellspec()`](https://github.com/CTTIR/gatekeepR/reference/gk_write_cellspec.md)
  retains its legacy default for compatibility and adds an explicit
  `format` argument. The legacy format is planned for retirement after
  migration is qualified; new integrations should select canonical
  `"parquet"` or `"tsv.gz"`. Schema errors never trigger a legacy
  fallback.

## gatekeepR 1.0.0

Initial CRAN release.

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
