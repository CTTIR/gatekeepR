## Submission

This is a new submission (gatekeepR 1.2.0).

## Test environments

* local macOS (aarch64-apple-darwin), R 4.6.1:
  `R CMD check --as-cran --no-manual` on the built tarball. LaTeX is not
  installed on this machine, so the PDF manual was not built locally. The
  optional Bioconductor package 'EBImage' could not be installed locally
  (its dependency 'fftwtools' needs the FFTW system library), so this run
  used `_R_CHECK_FORCE_SUGGESTS_=false`; the EBImage tests are skipped when
  it is not installed. cellspecR 1.2.0 was installed from the CTTIR
  R-universe.
* GitHub Actions (r-lib/actions v2, `--as-cran`, all Suggests installed):
  * macos-latest (R release)
  * windows-latest (R release)
  * ubuntu-latest (R devel, release, oldrel-1)

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

* 'EBImage' (Bioconductor) is suggested for one optional threshold method and
  is used conditionally.
* Examples, tests and vignettes use only simulated, study-neutral data, write
  only to `tempdir()` and do not access the network. The 'shiny' review
  application is only launched on request.

## Downstream dependencies

There are currently no downstream dependencies on CRAN.
