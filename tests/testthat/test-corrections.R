test_that("corrections preserve absent markers and replay exactly", {
  prep <- gk_example_prepared()
  for (method in c("none", "robust_z", "common_score_residual",
                   "pc1_panel_residual")) {
    corrected <- gk_correct(prep, method = method)
    expect_s3_class(corrected, "gk_corrected")
    expect_s3_class(corrected$model, "gk_correction_model")
    expect_true(all(is.na(corrected$matrix[, "CD21"])))
    replayed <- gk_correct(prep, method = corrected$model)
    expect_identical(corrected$matrix, replayed$matrix)
  }
})

test_that("residual correction records and applies row centering", {
  prep <- gk_example_prepared()
  uncentered <- gk_correct(prep, "common_score_residual", row_center = FALSE)
  centered <- gk_correct(prep, "common_score_residual", row_center = TRUE)
  expect_identical(uncentered$model$row_center, FALSE)
  expect_identical(centered$model$row_center, TRUE)
})

test_that("corrections reject a model fitted to different prepared data", {
  prep <- gk_example_prepared()
  model <- gk_correct(prep, "robust_z")$model
  other <- prep
  other$source_sha256 <- "different-source"
  expect_error(gk_correct(other, model), class = "gatekeepr_error_state")
})
