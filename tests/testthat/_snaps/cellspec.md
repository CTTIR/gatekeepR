# gk_signal_policy() recycles and validates

    Code
      print(pol)
    Message
      <gk_signal_policy> for 2 markers
    Output
       marker compartment statistic fallback_compartment min_value
            A        cell      mean                 <NA>         0
            B     nucleus      mean                 cell         0

# gk_cellspec() builds a spec-conformant object

    Code
      print(x)
    Message
      <cellspec> 1.0.0: 3 cells, 1 image, 1 marker, 2 features
      Markers: "A"

# gk_cellspec() rejects structurally invalid input

    Code
      gk_cellspec(bad, m)
    Condition
      Error in `gk_cellspec()`:
      ! `x` is not a valid cellspec object.
      x (image_id, cell_id) must be unique.

# signal selection follows the policy, fallback and min_value

    Code
      .gk_signal_matrix(x, missing)
    Condition
      Error:
      ! The cell table has no "mean" measurement of "P" in the "membrane" compartment.
      i Check the signal policy and localisation rules against `x$dictionary`.

