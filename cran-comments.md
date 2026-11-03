## Version 1.1.0 — prepared, not submitted

## Test environment

* macOS 27.0.1, aarch64, R 4.6.1.
* Final source archive: `R CMD check --as-cran`.
* Hosted Linux/Windows and older supported R checks remain pending.

## Results

0 errors, 0 warnings, 1 NOTE. The NOTE identifies a new submission and the
optional cellspecR dependency outside mainstream repositories. Its declared
Additional_repositories URL provides cellspecR 1.1.0 and incoming checks confirmed
availability. Strong dependencies are available from CRAN; optional EBImage is
from Bioconductor.

The as-CRAN tests passed 1,069 assertions with 23 documented skips. The full
coverage run with NOT_CRAN=true passed 1,103 assertions without failures,
warnings or skips, and measured 96.655216% coverage against the unchanged 95%
gate. Exact evidence and remaining release steps are recorded in MAINTENANCE.md.

The package contains only simulated and study-neutral example data. Version 2
review/checkpoint/hash formats require explicit migration and re-review of legacy
records; original data and frozen parameter records are preserved.
