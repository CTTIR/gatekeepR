# gatekeepR 1.2.0

Version 1.1.0 was prepared but not released; its changes are included here.

* The `mixture` threshold method no longer reports a cut when a fitted
  component collapses onto scores tied at the bound of the score range (at
  least nine in ten cells of a pool) and the cut lands next to that bound (in
  the last twentieth of the way from the other component). Scores with a floor
  or a saturation value whose cut stays between the two modes are not
  affected. Robust z-scores are clipped to [-5, 5];
  a strongly stained marker then received a `CALLABLE` cut next to the clip
  (4.98 for CD8 on the example slide), and separated positive cells below it
  were called negative (135 of 672). Such a marker now has the status
  `NOT_CALLABLE_NO_SEPARATION` with a detail that names the cause. Use the
  `valley` or `tail` method for it, or estimate on uncorrected scores. This
  changes the result for affected markers; thresholds of other markers are
  unchanged. The get-started article now estimates on uncorrected scores, on
  which every stained marker of the simulated panel with enough cells is
  callable.
* The threshold article runs the code it shows; its previous example called
  `gk_thresholds()` and `gk_plot_thresholds()` with arguments that do not
  exist. Vignette figures carry alternative text and are skipped when ggplot2
  is not installed. The reference index of the site is grouped by workflow
  step.
* `citation("gatekeepR")` takes the version from the installed package.
* The plot helpers share one look: `ggplot2::theme_minimal()`, written-out
  axis and legend titles, legend keys large enough to read, and colours that
  remain distinguishable with colour vision deficiency (Okabe-Ito for up to
  nine classes, viridis for numbers). A theme or scale added by the caller
  still replaces these defaults.
* `gk_plot_states()` draws only the cells of each parent set, marks the state
  threshold and shows cells without a call as "Not called". Previously every
  cell of the image appeared in every panel and uncalled cells were coloured
  as negative.
* `gk_plot_thresholds()` writes the status of a marker without an estimate
  into its row instead of leaving the row empty.
* `gk_plot_overview()` shows the number of cells per class next to the map;
  the map alone used to fill half of the canvas.
* A misspelt choice (for example `method` in `gk_correct()`, `status` in
  `gk_lock()` or `disposition` in `gk_dispose()`) now raises an error that
  inherits from `gatekeepr_error_input` and `gatekeepr_error`, as documented
  for every gatekeepR error. The message is unchanged.
* `gk_plot_map()`, `gk_plot_thresholds()` and `gk_plot_states()` fail with a
  `gatekeepr_error_input` error for an image that is not in the object instead
  of returning an empty plot.

* Exclude background cells when calculating density-basin centres, keeping
  centres finite and allowing small basins to merge without an indexing error.
  Background cells remain unassigned.
* Declare uwot 0.1.15 as the minimum version for its seeded embedding API.
* Detect native symbolic links, dangling links and Windows junctions without
  relying on the Windows `Sys.readlink()` stub; retain manifest and overwrite
  boundaries across platforms.
* Preserve unavailable marker measurements through correction and state calling;
  honour configured methods/support and validate ordered source and score bindings.
* Correct mixture overlap diagnostics and isolate cells by image and cell ID.
* Replay identity/state cuts, enablement and undo through the shared classifier.
  Validate checkpoint contents and detect stale concurrent sessions.
* Add real review controls, checkpoint/resume, explicit human review status and
  verified snapshot download. Render plots correctly and summarise dotplot means.
* Introduce version 2 snapshots/checkpoints and unambiguous data hashes. Bind all
  replay inputs, outputs, review decisions and status; reject mutated snapshots
  and verify staged exports before publication. Preserve exact decimal scores.
* Legacy records are preserved; regenerate/review into new paths. Explicit
  unverified inspection remains available for legacy exports. Frozen residual
  parameters require explicit import and downstream requalification, not refitting.


* Fix every plot helper (`gk_plot_density()`, `gk_plot_thresholds()`,
  `gk_plot_map()`, `gk_plot_dotplot()`, `gk_plot_states()`,
  `gk_plot_embedding()` and `gk_plot_overview()`), which failed when drawn
  with "Can't subset `.data` outside of a data mask context". The tests now
  build each plot instead of only checking its class.

* Standardise the named v5 package logo across README, documentation pages
  and available application headers, with matching light and dark artwork.

* gatekeepR no longer registers a `print()` method for `cellspec` objects.
  The class belongs to cellspecR, whose method was replaced whenever both
  packages were loaded.


- Add fixed numerical threshold calls and state diagnostics with explicit parent
  eligibility, localisation, missingness and non-authorising audit outputs.

- Add authenticated external residual-parameter import without fitting, fixed
  raw-support-aware ternary calls, and declarative candidate rules with explicit
  unavailable states. These APIs never authorise scientific review or production.

- Preserve review session ownership across checkpoint saves, reject foreign-owner writes, and serialise save/load operations with a separate filesystem lock.


* Added `gk_fit_residual_model()` and `gk_apply_residual_model()` for freezing
  common-score identity and first-principal-component panel residual spaces.
  Application reuses fitted parameters without refitting, requires the exact
  marker dictionary, and preserves optional missing values. Content hashes
  bind model parameters, typed metadata and caller-supplied threshold records.
  Raw-channel support, training-image scope and biological decisions remain
  explicit caller responsibilities; existing `gk_correct()` behaviour is unchanged.

* Cell-table readers recognise canonical cellspecR directories in Parquet and
  typed TSV formats. Explicit canonical writes delegate to cellspecR and
  preserve metadata, adjacency and exact numeric values. They require the
  optional cellspecR dependency and valid declared image calibration.
* `gk_write_cellspec()` retains its legacy default for compatibility and adds
  an explicit `format` argument. The legacy format is planned for retirement
  after migration is qualified; new integrations should select canonical
  `"parquet"` or `"tsv.gz"`. Schema errors never trigger a legacy fallback.
* Prepare the first CRAN submission: the documentation is declared as British
  English (`Language: en-GB`), a spelling word list is added, and the version
  is aligned across `DESCRIPTION`, `inst/CITATION`, `CITATION.cff`,
  `.zenodo.json` and the README.
* The help pages, README, vignettes and these notes use British spelling
  throughout (authorisation, localisation, serialise, standardised).

# gatekeepR 1.0.0

Initial package implementation; CRAN publication was not established.

* Added the study-neutral configuration model, cellspec 1.0 adapter,
  preparation and callability checks, simulator, and bundled example data.
* Added reproducible score corrections, per-image threshold estimation with
  evidence, and PCA/UMAP population embeddings.
* Added declarative classification, state calls, structure review, append-only
  review ledgers, persistence, immutable snapshots, and verifiable exports.
* Added plotting helpers, a Shiny review shell, reproducibility vignettes, and
  benchmark templates.
