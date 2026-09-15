# the example configuration is valid and prints

    Code
      print(cfg)
    Message
      <gk_config> (schema 1.0.0)
      * Panel: 12 markers (identity 8, state 2, context 1, conditional_identity 1)
      * Hierarchy "1.0.0": 9 rules, 1 flag
      * Parent sets: 3; refinements: 2; overrides: 0
      * SHA-256: "2bdc84a359852919307483c7b938813135e5ed1d77cbf339ab19b33480f5c232"

---

    Code
      print(checks)
    Message
      v Configuration valid (8 checks passed).

# T01 invalid configurations fail with specific messages

    Code
      gk_config(base$signal_policy, base$panel, base$parent_sets, h, refinements = base$
        refinements)
    Condition
      Error in `gk_config()`:
      ! Invalid gatekeepR configuration (1 failed check).
      x Rule 'R020' refers to unknown marker 'CD99'.

# cross-component checks name parent sets, refinements and overrides

    Code
      gk_config(base$signal_policy, base$panel, sets, base$hierarchy, refinements = base$
        refinements)
    Condition
      Error in `gk_config()`:
      ! Invalid gatekeepR configuration (1 failed check).
      x Parent set 'Tumor' contains label 'Tumour cells', which the hierarchy never assigns.

# gk_read_config() and gk_validate_config() report malformed files

    Code
      gk_read_config(write_variant(v))
    Condition
      Error in `gk_read_config()`:
      ! Unsupported configuration schema version "2.0.0".
      i This version of gatekeepR reads schema 1.x.

---

    Code
      print(checks)
    Message
      x Configuration invalid: 1 failed check.
      x construction: Duplicate rule_id "R020" in the hierarchy.

