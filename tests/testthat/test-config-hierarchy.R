test_that("rules, flags, refinements and overrides construct and print", {
  r <- gk_rule("R1", "T cells", all_of = list("CD45", "CD3e"), none_of = "PanCK")
  expect_s3_class(r, "gk_rule")
  expect_identical(r$all_of, c("CD45", "CD3e"))
  expect_snapshot(print(r))
  rv <- gk_rule("R2", "Epi",
    all_of = "PanCK", review = "structure", pending_label = "Pending",
    decisions = list(Benign = "B", Tumor = "T", Unresolved = "U")
  )
  expect_identical(names(rv$decisions), c("Tumor", "Benign", "Unresolved"))
  expect_snapshot(print(rv))
  expect_s3_class(gk_flag(any_of = "A"), "gk_flag")
  expect_s3_class(gk_refinement("RF1", "S", "P", "a", "b"), "gk_refinement")
  ov <- gk_override("img", "A", threshold_method = "valley", reason = "Dim batch")
  expect_s3_class(ov, "gk_override")
  expect_true(is.na(ov$parent))
})

test_that("invalid rules and flags fail with named messages", {
  expect_snapshot(gk_rule("R1", "x", all_of = "A", none_of = "A"), error = TRUE)
  expect_snapshot(gk_rule("R1", "x", all_of = "A", review = "structure", pending_label = "p"), error = TRUE)
  expect_snapshot(gk_rule("R1", "x", review = "structure", pending_label = "p", decisions = c(Tumor = "t")), error = TRUE)
  expect_error(gk_rule("R1", "x", review = "structure"), "pending_label", class = "gatekeepr_error_config")
  expect_error(gk_rule("R1", "x", review = "manual", pending_label = "p"), class = "gatekeepr_error_input")
  expect_error(gk_rule("R1", "x", pending_label = "p"), class = "gatekeepr_error_config")
  expect_error(gk_rule("R1", "x", all_of = c("A", NA)), class = "gatekeepr_error_config")
  expect_error(gk_rule("R1", "x", on_uncallable = "ignore"), class = "gatekeepr_error_input")
  expect_error(gk_flag(), class = "gatekeepr_error_config")
  expect_error(gk_override("img", "A", reason = "x"), "changes nothing", class = "gatekeepr_error_config")
  expect_error(gk_override("img", "A", threshold_method = "valley"), class = "gatekeepr_error_config")
  expect_error(gk_override("img", "A", threshold_method = "valley", reason = " "), class = "gatekeepr_error_config")
  expect_error(gk_override("img", "A", parent = "", threshold_method = "valley", reason = "r"), class = "gatekeepr_error_config")
  expect_error(gk_override("img", "A", threshold_args = list(1), reason = "r"), class = "gatekeepr_error_config")
})

test_that("gk_hierarchy() enforces unique IDs and a policy for every flag", {
  rules <- list(gk_rule("R1", "a", all_of = "A"), gk_rule("R2", "b", all_of = "B"))
  h <- gk_hierarchy(rules,
    flags = list(mixed = gk_flag(all_of = "A", any_of = "B")),
    flag_policy = c(mixed = "exclude"), version = "1"
  )
  expect_s3_class(h, "gk_hierarchy")
  expect_snapshot(print(h))
  expect_snapshot(gk_hierarchy(list(gk_rule("R1", "a"), gk_rule("R1", "b")), version = "1"), error = TRUE)
  expect_snapshot(gk_hierarchy(rules, flags = list(mixed = gk_flag(all_of = "A")), version = "1"), error = TRUE)
  expect_error(gk_hierarchy(rules), "version", class = "gatekeepr_error_config")
  expect_error(gk_hierarchy(list(), version = "1"), class = "gatekeepr_error_config")
  expect_error(gk_hierarchy(rules, flags = list(gk_flag(all_of = "A")), version = "1"), class = "gatekeepr_error_config")
  expect_error(gk_hierarchy(rules, flag_policy = c(x = "exclude"), version = "1"), "undefined", class = "gatekeepr_error_config")
  expect_error(
    gk_hierarchy(rules, flags = list(m = gk_flag(all_of = "A")), flag_policy = c(m = "drop"), version = "1"),
    class = "gatekeepr_error_config"
  )
})

test_that("hierarchy labels include pending, decision and refinement labels", {
  cfg <- gk_example_config()
  labels <- .gk_hierarchy_labels(cfg$hierarchy, cfg$refinements)
  expect_true(all(c(
    "Unreviewed epithelial cells", "Tumor cells", "Treg cells", "Undefined",
    "Unresolved epithelial-immune contact"
  ) %in% labels))
  expect_false("Epithelial cells" %in% labels)
  tab <- .gk_rule_table(cfg$hierarchy)
  expect_identical(tab$review[[1]], "structure")
})
