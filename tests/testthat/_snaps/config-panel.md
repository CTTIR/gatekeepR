# gk_min_support() validates and prints

    Code
      print(ms)
    Message
      <gk_min_support>: min_cells = 30, max_unavailable = 0.2, min_auc = 0.7,
      near_constant_mode_fraction = 0.99

# gk_panel() expands shared and per-marker arguments

    Code
      print(p)
    Message
      <gk_panel> with 3 markers
    Output
       marker     role transform cofactor threshold_method optional parents
            A identity     asinh        5           valley    FALSE        
            B identity     asinh        5          mixture    FALSE        
            S    state     asinh        5             tail    FALSE Parents
                 localization
                             
                             
       nucleus/cytoplasm >= 2

# gk_panel() rejects invalid panels with specific messages

    Code
      gk_panel("S", role = "state", threshold_method = "tail")
    Condition
      Error in `gk_panel()`:
      ! State marker "S" has no parent sets.
      i Give `parents`, e.g. `parents = list(S = "T cells")`.

---

    Code
      gk_panel("A", role = "lineage")
    Condition
      Error in `gk_panel()`:
      ! Unknown role for marker "A".
      i Roles are "identity", "state", "context", and "conditional_identity".

---

    Code
      gk_panel("A", role = "identity", threshold_method = "otsu")
    Condition
      Error in `gk_panel()`:
      ! Marker "A" uses unknown threshold method "otsu".
      i See `gk_threshold_methods()`.

---

    Code
      gk_panel("A", role = "identity", threshold_method = "parent_crossing")
    Condition
      Error in `gk_panel()`:
      ! Threshold method "parent_crossing" is not allowed for "identity" marker "A".

---

    Code
      gk_panel("A", role = "identity", threshold_args = list(A = list(bogus = 1)))
    Condition
      Error in `gk_panel()`:
      ! Marker "A": unknown argument "bogus" for method "mixture".
      i Allowed: "max_overlap", "max_iter", "tol", and "min_n".

