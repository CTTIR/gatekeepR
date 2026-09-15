test_that("the example configuration is valid and prints", {
  cfg <- gk_example_config()
  expect_s3_class(cfg, "gk_config")
  checks <- gk_validate_config(cfg)
  expect_true(all(checks$status == "pass"))
  expect_snapshot(print(cfg))
  expect_snapshot(print(checks))
})

test_that("T01 invalid configurations fail with specific messages", {
  base <- gk_example_config()
  # unknown marker in a rule
  h <- base$hierarchy
  h$rules[[2]]$all_of <- c(h$rules[[2]]$all_of, "CD99")
  expect_snapshot(
    gk_config(base$signal_policy, base$panel, base$parent_sets, h, refinements = base$refinements),
    error = TRUE
  )
  # context marker used in a rule
  h <- base$hierarchy
  h$rules[[8]]$none_of <- c(h$rules[[8]]$none_of, "SMA")
  err <- expect_error(
    gk_config(base$signal_policy, base$panel, base$parent_sets, h, refinements = base$refinements),
    class = "gatekeepr_error_config"
  )
  expect_match(conditionMessage(err), "context marker 'SMA'")
  # flag referring to a state marker
  h <- base$hierarchy
  h$flags$mixed_contact$any_of <- "FOXP3"
  expect_error(
    gk_config(base$signal_policy, base$panel, base$parent_sets, h, refinements = base$refinements),
    "Flag 'mixed_contact' uses state marker 'FOXP3'", class = "gatekeepr_error_config"
  )
})

test_that("cross-component checks name parent sets, refinements and overrides", {
  base <- gk_example_config()
  sets <- base$parent_sets
  sets$Tumor <- "Tumour cells"
  expect_snapshot(
    gk_config(base$signal_policy, base$panel, sets, base$hierarchy, refinements = base$refinements),
    error = TRUE
  )
  sets <- base$parent_sets
  sets$Immune <- NULL
  expect_error(
    gk_config(base$signal_policy, base$panel, sets, base$hierarchy, refinements = base$refinements),
    "undefined parent set 'Immune'", class = "gatekeepr_error_config"
  )
  bad_ref <- list(
    gk_refinement("RF10", "Ki67", "CD4 T cells", "CD4 T cells", "x"),
    gk_refinement("R010", "PanCK", "Tumor", "Nope", "y"),
    gk_refinement("RF10", "FOXP3", "Immune", "CD4 T cells", "z")
  )
  err <- expect_error(
    gk_config(base$signal_policy, base$panel, base$parent_sets, base$hierarchy, refinements = bad_ref),
    class = "gatekeepr_error_config"
  )
  msg <- conditionMessage(err)
  expect_match(msg, "Refinement rule_id 'RF10' is not unique")
  expect_match(msg, "'R010' is not unique")
  expect_match(msg, "'CD4 T cells' is not a parent set of state marker 'Ki67'")
  expect_match(msg, "'PanCK', which is not a state marker")
  expect_match(msg, "starts from label 'Nope'")
  ovs <- list(
    gk_override("img", "SMA", threshold_method = "valley", reason = "r"),
    gk_override("img", "CD3e", threshold_method = "parent_crossing", reason = "r"),
    gk_override("img", "CD4", parent = "Tumor", threshold_method = "valley", reason = "r"),
    gk_override("img", "Ki67", parent = "CD4 T cells", threshold_args = list(min_n = 50), reason = "r"),
    gk_override("img", "CD8", threshold_method = "otsu", reason = "r"),
    gk_override("img", "CD20", threshold_args = list(bogus = TRUE), reason = "r"),
    gk_override("img", "CD20", threshold_args = list(min_n = 10), reason = "again")
  )
  err <- expect_error(
    gk_config(base$signal_policy, base$panel, base$parent_sets, base$hierarchy,
      overrides = ovs, refinements = base$refinements
    ),
    class = "gatekeepr_error_config"
  )
  msg <- conditionMessage(err)
  for (pattern in c(
    "same image, marker and parent", "'SMA', which is not a gated panel marker",
    "method 'parent_crossing' is not allowed for identity", "must not name a parent",
    "parent 'CD4 T cells', which the marker does not use", "unknown method 'otsu'",
    "unknown argument 'bogus'"
  )) {
    expect_match(msg, pattern, fixed = TRUE)
  }
  panel <- base$panel
  panel$threshold_args$FOXP3 <- list(reference = "Stroma")
  expect_error(
    gk_config(base$signal_policy, panel, base$parent_sets, base$hierarchy, refinements = base$refinements),
    "undefined reference set 'Stroma'", class = "gatekeepr_error_config"
  )
  pol <- base$signal_policy[base$signal_policy$marker != "CD31", ]
  expect_error(
    gk_config(pol, base$panel, base$parent_sets, base$hierarchy, refinements = base$refinements),
    "'CD31' has no entry in the signal policy", class = "gatekeepr_error_config"
  )
  sets <- base$parent_sets
  sets$Empty <- character()
  expect_error(
    gk_config(base$signal_policy, base$panel, sets, base$hierarchy, refinements = base$refinements),
    "is empty", class = "gatekeepr_error_config"
  )
})

test_that("gk_config() type-checks its components", {
  base <- gk_example_config()
  expect_error(gk_config(base$signal_policy, list(), hierarchy = base$hierarchy), class = "gatekeepr_error_input")
  expect_error(gk_config(base$signal_policy, base$panel, hierarchy = list()), class = "gatekeepr_error_input")
  expect_error(gk_config(base$signal_policy, base$panel, list("x"), base$hierarchy), class = "gatekeepr_error_config")
  expect_error(gk_config(base$signal_policy, base$panel, base$parent_sets, base$hierarchy, overrides = list(1)),
    class = "gatekeepr_error_config"
  )
  expect_error(gk_config(base$signal_policy, base$panel, base$parent_sets, base$hierarchy, refinements = list(1)),
    class = "gatekeepr_error_config"
  )
})

test_that("JSON round trip preserves the configuration and its hash", {
  cfg <- gk_example_config()
  path <- withr::local_tempfile(fileext = ".json")
  expect_invisible(gk_write_config(cfg, path))
  back <- gk_read_config(path)
  expect_identical(gk_config_hash(back), gk_config_hash(cfg))
  expect_identical(.gk_config_to_list(back), .gk_config_to_list(cfg))
  nested <- file.path(withr::local_tempdir(), "new dir", "cfg.json")
  gk_write_config(cfg, nested)
  expect_true(file.exists(nested))
})

test_that("the hash is stable across key order, whitespace and numeric spelling", {
  cfg <- gk_example_config()
  path <- withr::local_tempfile(fileext = ".json")
  gk_write_config(cfg, path)
  txt <- paste(readLines(path), collapse = "\n")
  x <- jsonlite::fromJSON(txt, simplifyVector = FALSE)
  shuffle <- function(v) {
    if (is.list(v) && !is.null(names(v)) && length(v) > 1L) {
      v <- v[rev(seq_along(v))]
    }
    if (is.list(v)) v[] <- lapply(v, shuffle)
    v
  }
  compact <- jsonlite::toJSON(shuffle(x), auto_unbox = TRUE, null = "null", digits = NA)
  compact <- gsub('"cofactor":5', '"cofactor":5.0', compact, fixed = TRUE)
  compact <- gsub('"min_ratio":1.5', '"min_ratio":15e-1', compact, fixed = TRUE)
  expect_match(compact, "5.0", fixed = TRUE)
  alt <- withr::local_tempfile(fileext = ".json")
  writeLines(compact, alt)
  expect_identical(gk_config_hash(gk_read_config(alt)), gk_config_hash(cfg))
})

test_that("the hash changes with any semantic change", {
  cfg <- gk_example_config()
  h0 <- gk_config_hash(cfg)
  changed <- cfg
  changed$hierarchy$flag_policy$mixed_contact <- "exclude"
  expect_false(identical(gk_config_hash(changed), h0))
  changed <- cfg
  changed$panel$threshold_args$CD3e <- list(min_n = 150)
  expect_false(identical(gk_config_hash(changed), h0))
  expect_error(gk_config_hash(list()), class = "gatekeepr_error_input")
})

test_that("written configurations validate against the JSON schema", {
  skip_if_not_installed("jsonvalidate")
  schema <- system.file("schema", "gatekeepr-config-1.0.0.schema.json", package = "gatekeepR")
  path <- withr::local_tempfile(fileext = ".json")
  cfg <- gk_example_config()
  cfg <- gk_config(cfg$signal_policy, cfg$panel, cfg$parent_sets, cfg$hierarchy,
    overrides = list(gk_override("img", "CD3e", threshold_args = list(min_n = 50), reason = "Test")),
    refinements = cfg$refinements
  )
  gk_write_config(cfg, path)
  expect_true(jsonvalidate::json_validate(path, schema, engine = "ajv"))
  x <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  x$panel[[1]]$role <- "lineage"
  bad <- withr::local_tempfile(fileext = ".json")
  writeLines(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null"), bad)
  expect_false(jsonvalidate::json_validate(bad, schema, engine = "ajv"))
})

test_that("gk_read_config() and gk_validate_config() report malformed files", {
  path <- withr::local_tempfile(fileext = ".json")
  gk_write_config(gk_example_config(), path)
  x <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  write_variant <- function(v) {
    p <- tempfile(fileext = ".json")
    writeLines(jsonlite::toJSON(v, auto_unbox = TRUE, null = "null"), p)
    p
  }
  v <- x
  v$schema_version <- "2.0.0"
  expect_snapshot(gk_read_config(write_variant(v)), error = TRUE)
  v <- x
  v$hierarchy <- NULL
  expect_error(gk_read_config(write_variant(v)), "lacks", class = "gatekeepr_error_config")
  v <- x
  v$hierarchy$rules[[3]]$rule_id <- "R020"
  p <- write_variant(v)
  expect_error(gk_read_config(p), "Duplicate rule_id", class = "gatekeepr_error_config")
  checks <- gk_validate_config(p)
  expect_identical(checks$status, "fail")
  expect_snapshot(print(checks))
  expect_identical(gk_validate_config(x)$status[[1]], "pass")
  expect_error(gk_validate_config(42), NA)
  expect_identical(gk_validate_config(42)$status, "fail")
  expect_error(.gk_config_from_list("x"), class = "gatekeepr_error_config")
  v <- x
  v$hierarchy$rules[[2]]$all_of <- list("CD45", "CD3e", "CD999")
  expect_identical(sum(gk_validate_config(v)$status == "fail"), 1L)
})
