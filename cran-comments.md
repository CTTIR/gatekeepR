## Submission

This is a new submission (gatekeepR 1.2.0).

## Test environments

* local macOS (aarch64-apple-darwin), R 4.6.1:
  `R CMD check --as-cran` on the built tarball on 14 November 2026, with all
  suggested packages available. PDF and HTML manuals, examples and rebuilt
  vignettes passed; TinyTeX and HTML Tidy 5.8.0 were used. The optional
  Bioconductor backend was exercised with EBImage 4.54.0, fftwtools 0.9-11
  and a privately built FFTW 3.3.11. The canonical adapter used cellspecR
  1.2.0 (source commit `ac2a3aac`).
* GitHub Actions baseline (public commit `76d8cf4`, r-lib/actions v2,
  `--as-cran`, all Suggests installed):
  * macos-latest (R release)
  * windows-latest (R release)
  * ubuntu-latest (R devel, release, oldrel-1)

Hosted checks on the maintenance candidate must be verified after publication;
the baseline platform results do not qualify the changed source.

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE
  Maintainer: 'R. Heller <raban.heller@uni-ulm.de>'
  New submission
  Suggests or Enhances not in mainstream repositories:
    cellspecR
  Availability using Additional_repositories specification:
    cellspecR   yes   https://cttir.r-universe.dev

  This is the first submission of this package. cellspecR is optional: it is
  available from the repository declared in `Additional_repositories` and is
  used only conditionally (`requireNamespace()` in code,
  `skip_if_not_installed()` in tests).

## Additional notes

* 'EBImage' (Bioconductor) is suggested for the optional density-basin backend and
  is used conditionally.
* Test coverage with the optional backend installed is 96.65%, above the
  unchanged 95% regression floor.
* Examples, tests and vignettes use only simulated, study-neutral data, write
  only to `tempdir()` and do not access the network. The 'shiny' review
  application is only launched on request.

## Downstream dependencies

The CRAN source index checked on 14 November 2026 contained no gatekeepR release
and no reverse dependencies. Development consumers in the phenoloom suite are
qualified separately through their integration checks.
