# rules, flags, refinements and overrides construct and print

    Code
      print(r)
    Message
      <gk_rule> "R1" -> "T cells"
        all_of: "CD45" and "CD3e"
        any_of:
        none_of: "PanCK"
        on_uncallable: "disable_rule"

---

    Code
      print(rv)
    Message
      <gk_rule> "R2" -> "Epi"
        all_of: "PanCK"
        any_of:
        none_of:
        on_uncallable: "disable_rule"
        review: structure, pending as "Pending"

# invalid rules and flags fail with named messages

    Code
      gk_rule("R1", "x", all_of = "A", none_of = "A")
    Condition
      Error in `gk_rule()`:
      ! Rule "R1" requires and excludes "A" at the same time.

---

    Code
      gk_rule("R1", "x", all_of = "A", review = "structure", pending_label = "p")
    Condition
      Error in `gk_rule()`:
      ! Review rule "R1" has no decisions.
      i Map "Tumor", "Benign", and "Unresolved" to labels.

---

    Code
      gk_rule("R1", "x", review = "structure", pending_label = "p", decisions = c(
        Tumor = "t"))
    Condition
      Error in `gk_rule()`:
      ! Review rule "R1" must map exactly "Tumor", "Benign", and "Unresolved" to labels.
      x Got "Tumor".

# gk_hierarchy() enforces unique IDs and a policy for every flag

    Code
      print(h)
    Message
      <gk_hierarchy> version "1": 2 rules, 1 flag
    Output
       rule_id label all_of any_of none_of on_uncallable review
            R1     a      A                 disable_rule       
            R2     b      B                 disable_rule       
    Message
      Flag mixed ("exclude"): all_of "A"; any_of "B"; none_of

---

    Code
      gk_hierarchy(list(gk_rule("R1", "a"), gk_rule("R1", "b")), version = "1")
    Condition
      Error in `gk_hierarchy()`:
      ! Duplicate rule_id "R1" in the hierarchy.

---

    Code
      gk_hierarchy(rules, flags = list(mixed = gk_flag(all_of = "A")), version = "1")
    Condition
      Error in `gk_hierarchy()`:
      ! Flag "mixed" has no policy.
      i Set `flag_policy` to one of "exclude", "flag_only", and "unresolved" for every flag.

