# gk_prepare() selects, transforms and records signals

    Code
      print(prep)
    Message
      <gk_prepared>: 8,000 cells, 1 image, 12 markers
      * Config SHA-256: "<hash>"
      * Source SHA-256: "<hash>"
      Callability: NOT_CALLABLE_ABSENT = 1; NOT_GATED = 1; PENDING_THRESHOLD = 10

# near-constant, unavailable and underpowered markers get their status

    Code
      cb[, c("marker", "status", "support", "details")]
    Output
        marker                    status            support
      1      A         PENDING_THRESHOLD                 ok
      2      N       NOT_CALLABLE_ABSENT      near_constant
      3      U  NOT_CALLABLE_UNAVAILABLE mostly_unavailable
      4      F NOT_CALLABLE_UNDERPOWERED          few_cells
                                                    details
      1               Signal supports threshold estimation.
      2                     99.5% of cells share one value.
      3 30.0% of cells have no usable signal (limit 20.0%).
      4             Only 15 cells with signal (minimum 20).

# a missing panel measurement is a structural error; an absent optional marker is not

    Code
      gk_prepare(x, cfg, quiet = TRUE)
    Condition
      Error in `gk_prepare()`:
      ! The cell table has no "mean" measurement of "C" in the "cell" compartment.
      i Check the signal policy and localisation rules against `x$dictionary`.

# image selection, paths and messages

    Code
      invisible(gk_prepare(a, cfg))
    Message
      v Prepared 300 cells on 1 image, 12 markers.
      ! 1 image x marker combination not callable: "CD21".
