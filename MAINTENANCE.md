# Maintenance audit — 2 November 2026

Repository CTTIR/gatekeepR; base `9514a37b688f2dc3abecfaf0e0153a0e0835bb91`.
Original clean checkout is preserved. Changes are isolated on
`maintenance/public-readiness-20261030`; publication is not authorized.

## Purpose and baseline

The promised path is source measurements -> supported marker thresholds ->
classification -> reviewer decisions -> checkpoint -> locked export -> verified
replay. Append-only history and content-addressed records must preserve actual
scientific meaning, not merely files with matching checksums.

The first test attempt passed 629 assertions but encountered 17 errors, one
skip and one warning while dbscan was missing; this was an incomplete environment
baseline. The pinned unchanged base then passed 738 assertions with no failures
or skips and one expected RNG restoration warning. Baseline logs/source and all
subsequent evidence are retained in the workspace audit directory.

Optional EBImage 4.54.0 initially failed because FFTW headers were absent. FFTW
3.3.11 was built into the audit's private tools directory and fftwtools/EBImage
installed into its private R library. No global R library or unrelated process
was changed. The actual EBImage watershed and corrected embedding path ran in
scientific regression checks.

## Confirmed findings

| Priority | Evidence and impact | Location | Required outcome |
|---|---|---|---|
| Essential | Logged identity cuts do not change effective thresholds or labels | review.R | Cuts affect shared classification and survive replay/checkpoints |
| Essential | State cut API errors; ENABLE loses SET_CUT; undo DELETE loses prior EXCLUDE | review.R | Correct ordered action and prior-state semantics |
| Essential | Edited ledger reason/state values/production eligibility still verify after ordinary manifest refresh | export.R | Semantic hashes, review identity and all exported decisions reconcile |
| Essential | Different in-memory sources share review_id when source_manifest is missing | snapshot construction | Bind the actual source and relevant scientific content |
| Essential | Correction none imputes missing signal as positive; one absent image erases good-image signal | corrections.R | Preserve missingness and per-image support |
| Essential | Absent state signals become positive; configured method/support ignored; nonfinite localization passes | states/thresholds | Honor declared methods and require supported finite evidence |
| Essential | Foreign sources and incompatible threshold score spaces accepted | analysis boundaries | Reject incoherent scientific objects before calling/review |
| Essential | Mixture overlap differs from documented smaller-component tail fraction | threshold methods | Independent Gaussian-tail oracle matches reported evidence/status |
| Everyday use | App has three viewer tabs and no review controls | app.R | Real review/lock/download journey through shared APIs |
| Everyday use | Dotplot plots raw rows and joins classification positionally | plots.R | ID-aligned group summaries invariant to row order |
| Essential | Image-local cell IDs joined without image ID | replay/plots/export | Composite identities throughout review and maps |
| Essential | Decimal transport changes scores on current R; fractional ledger order silently truncates | utils-io.R | Exact numeric round trips and strict typed parsing |
| Essential | Ambiguous string concatenation creates equal content hashes for distinct inputs | utils-hash.R | Typed, length-prefixed hash version 2 |
| Everyday use | Plot objects construct but fail when actually rendered | plots.R | Real plot build and browser checks |
| Release | Advertised review/export example paths are absent | example docs | Executable first-use documentation and truthful status |

An initial suspected app export-class error was retracted: construction from a
verified export succeeds. Detailed probes and raw evidence are retained under
the workspace audit's `evidence/gatekeepR/`.

## Strategy and acceptance, before implementation

1. Repair scientific support, missingness, method dispatch, localization and
   source/score-space contracts. Use independently calculated small fixtures,
   multiple images and deliberately mismatched objects. Preserve source data.
2. Repair ordered reviewer replay, undo and persistence. Verify effective calls,
   prior dispositions, checkpoint round trips and concurrent session ownership.
3. Bind and verify snapshot identity, scientific content, all ledgers and review
   status. Rehashed tampering must fail. Preserve legacy files and document any
   stricter verification/re-review migration instead of silently rewriting them.
4. Complete a bounded review UI using the same R APIs: reviewer/reason, cuts,
   states, structures, dispositions, undo, checkpoint, lock and current-snapshot
   downloads. Changes invalidate stale downloads; no automatic scientific
   approval or duplicate classifier. Verify the full path in a real browser.
5. Validate package installation, manuals, vignettes, first use, optional methods,
   shared house lint and the existing 95% coverage gate. Independently review
   results and record exact commands, failures, final artifacts and limits.

Scientific contracts precede final review/export qualification. App work may
proceed against stable public APIs. Segmentation, cohort statistics, new assay
panels and biological validation remain outside this maintenance release.

## Completed work and verification

The five milestones above are complete for local readiness. Scientific support,
source/score contracts, effective reviewer replay, checkpoint concurrency,
content-bound exports, app controls and executable documentation were repaired.
Version 1.1.0 is an unpublished development candidate. CRAN's current source
index had no gatekeepR entry on 2 November 2026; GitHub reported no releases or
tags. Unverified publication metadata were corrected, and CFF 1.2.0 validation
passes. The public maintainer email and ORCID are preserved.

| Verification | Observed result |
|---|---|
| Final source archive, `R CMD check --as-cran` | 0 errors, 0 warnings, 1 NOTE; manuals, examples and rebuilt vignettes pass |
| Incoming NOTE | New submission; optional cellspecR is outside mainstream repositories but available from declared CTTIR R-universe |
| Test coverage, unchanged 95% gate | 96.655216%; 1,103 assertions, 0 failures/warnings/skips with NOT_CRAN=true |
| As-CRAN tests | 1,069 assertions pass; 22 existing CRAN snapshot skips and one installed-source guard skip; source guard separately passes |
| House lint and workflow syntax | Zero findings; house rules pinned at CTTIR/.github 9009cfad768a37cc7f794e75825fa47ddc8d1489; actionlint passes |
| Fresh package installation | Exact final archive installed into a new package library; vanilla R verifies namespace location and both raw/corrected 8,000-cell workflows |
| Checkpoint/export failure paths | Stale concurrent save, changed content/status/model/source, invalid typed values and wrong trusted full ID rejected |
| Native optional method | EBImage 4.54.0 watershed and corrected embedding path exercised, no skipped optional-method checks |
| Browser app | Eight tabs, cuts/structures/states/dispositions/undo, human status, checkpoint/resume, stale-session protection and two downloaded archives verified |
| Documentation site | 70 pages, 641 internal targets, 14 desktop/mobile page checks; no broken links, JS errors, missing assets or overflow |
| PDF manual | 53 pages inspected; final text matches inspected content after first-page repository metadata verification; no clipped text |
| Archive and data | 185 source files match the final archive; no unknown/artifact files; all six original bundled data files unchanged |

The final archive is `.checks/readiness-5/gatekeepR_1.1.0.tar.gz` (1,914,179
bytes), SHA-256
`3c839b14b4097810016afe2abc5964c5dc2c4bb3503c7ebbbbdea0b35940dc7c`.
The final check used R 4.6.1 on aarch64 macOS 27.0.1, with audit-local
dependencies. The fresh package library reused those audited dependencies;
it was not an independent download of every dependency. Hosted Linux/Windows
checks and older supported R versions have not been run for these commits.

The original baseline passed its tests despite the confirmed defects. Subsequent
independent review caught fractional ledger truncation, empty structure handling,
render-only plot failures and ambiguous composite identities. Intermediate build
failures were fixed. A documentation probe image accidentally entered one
candidate archive; it was preserved outside the source tree, and the final
archive was rebuilt, inspected and checked cleanly. No check was weakened.

Benchmark totals for prepare through verified export were 2.74/2.75/9.84 seconds
for 300/1,000/8,000 cells versus baseline 0.81/1.09/5.08 seconds. The main added
cost is verification before publication and the additional replay payload.
Sampled RSS peaked at 278 MiB. These are local observations under concurrent
machine load, not a throughput guarantee. No speculative optimization was made.

Local evidence is under the workspace audit's `evidence/gatekeepR/`, including
`verification.json`, `build-check-5.log`, `coverage-gate.json`,
`final-archive-inspection.json`, `final-first-use-5/result.json`,
`site-manual-verification.md`, `performance.json` and per-area independent reviews.
`run.sh` defines the private R library and tools used; `build-check-5.R`,
`coverage-gate.R` and `installed-first-use.R` record exact reproducible commands.
The README gives the installation and first-use path. Standard checks from a
prepared development environment are:

```sh
R CMD build .
R CMD check --as-cran gatekeepR_1.1.0.tar.gz
NOT_CRAN=true Rscript -e 'x <- covr::package_coverage(type="tests"); stopifnot(covr::percent_coverage(x) >= 95)'
```

## Migration and interpretation

Version 2 exports/checkpoints and hash bindings intentionally reject legacy
analytical objects. Keep original data, files and provenance. Rebuild from the
original source/configuration, review changed results and write to new paths.
Legacy export inspection remains available only with explicit `verify = FALSE`.
Frozen residual models can import validated original parameter fields and file
SHA without refitting; retain bindings/provenance and requalify outputs. The
migration regression preserves parameter values, numerical outputs and source
bytes. Exact finite score transport uses strict typed parsing; missing numeric
values have a canonical representation in content hashes.

Keep the full review ID independently to detect replacement of an entire export.
Hashes do not authenticate a human reviewer. REVIEWED records a human assertion,
not scientific or clinical validation. Owner locks persist after R exits;
explicit takeover is appropriate only after confirming the prior process stopped.

The development-only Remotes field was replaced with Additional_repositories
for the optional cellspecR adapter, following the
[CRAN policies](https://cran.r-project.org/web/packages/policies.html).
The declared repository supplies cellspecR 1.1.0. No hosted CI, deployment,
submission or publication has been performed.

## Deferred work and external readiness

The current release excludes segmentation, new assay panels, image overlays,
freehand annotation and cohort statistics. Biological assay qualification and
study-specific human review remain the user's scientific work. After all local
gates pass, the next release step is review and authorization of the prepared
commits, hosted platform checks on those exact commits, then submission or
publication through the intended channel.
