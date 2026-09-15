# argument checks abort with gatekeepr_error_input and the user's argument name

    Code
      f(1)
    Condition
      Error in `f()`:
      ! `value` must be a single non-empty string.
      x Got a number.

# reviewer IDs and reasons are safe to store in ledgers

    Code
      .gk_check_reason(strrep("ä", 501))
    Condition
      Error:
      ! `strrep("ä", 501)` must be at most 1,000 bytes.
      x Got 1002 bytes.

# missing suggested packages are listed together

    Code
      .gk_require(c("stats", "gk.no.such.pkg1", "gk.no.such.pkg2"), "The review app")
    Condition
      Error:
      ! The review app needs packages gk.no.such.pkg1 and gk.no.such.pkg2.
      i Install with `install.packages(c("gk.no.such.pkg1", "gk.no.such.pkg2"))`.

