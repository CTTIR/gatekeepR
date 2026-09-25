residual_fixture <- function() {
  withr::local_seed(41)
  x <- matrix(stats::rnorm(120 * 5), 120, 5,
    dimnames = list(paste0("cell", seq_len(120)), LETTERS[1:5]))
  x[1:25, "D"] <- NA_real_
  x
}

# Independent fit-time evaluator using QR residuals rather than frozen
# coefficients. This deliberately does not call package fitting helpers.
residual_reference <- function(x, ids) {
  robust <- function(y) {
    center <- apply(y, 2, stats::median, na.rm = TRUE)
    scale <- apply(y, 2, stats::mad, na.rm = TRUE)
    scale[!is.finite(scale) | scale <= 0] <- 1
    z <- sweep(sweep(y, 2, center, "-"), 2, scale, "/")
    z[z < -5] <- -5
    z[z > 5] <- 5
    z
  }
  standardize <- function(r) {
    center <- colMeans(r, na.rm = TRUE)
    scale <- apply(r, 2, stats::sd, na.rm = TRUE)
    scale[!is.finite(scale) | scale <= 0] <- 1
    sweep(sweep(r, 2, center, "-"), 2, scale, "/")
  }
  iz <- robust(x[, ids, drop = FALSE])
  ir <- qr.resid(qr(cbind(1, rowMeans(iz))), iz)
  ir <- ir - rowMeans(ir)
  z <- robust(x)
  p <- stats::prcomp(z[, ids, drop = FALSE], center = TRUE, scale. = FALSE)
  design <- cbind(1, p$x[, 1])
  r <- z * NA_real_
  for (j in seq_len(ncol(z))) {
    ok <- is.finite(z[, j])
    r[ok, j] <- qr.resid(qr(design[ok, , drop = FALSE]), z[ok, j])
  }
  r <- r - rowMeans(r[, ids, drop = FALSE])
  list(identity = standardize(ir), gate = standardize(r))
}

test_that("frozen residuals match independent fitted numerical spaces", {
  x <- residual_fixture()
  expected <- residual_reference(x, c("A", "B", "C"))
  m <- gk_fit_residual_model(x, c("A", "B", "C"),
    provenance = list(fit_scope = "synthetic image", transformation = "as supplied"),
    bindings = list(thresholds = data.frame(marker = "A", cut = 0)))
  y <- gk_apply_residual_model(x, m)
  expect_equal(y$identity, expected$identity, tolerance = 1e-10)
  expect_equal(y$gate, expected$gate, tolerance = 1e-10)
  expect_identical(is.na(y$gate), is.na(x))
  expect_identical(dimnames(y$gate), dimnames(x))
  expect_match(m$model_sha256, "^[a-f0-9]{64}$")
  expect_false("matrix" %in% names(m))
})

test_that("frozen application is independent of other rows and serialization", {
  x <- residual_fixture()
  m <- gk_fit_residual_model(x, c("A", "B", "C"))
  y <- gk_apply_residual_model(x, m)
  index <- rev(seq_len(nrow(x)))
  expect_equal(gk_apply_residual_model(x[index, ], m)$gate[index, ], y$gate)
  expect_equal(gk_apply_residual_model(x[-1, ], m)$gate, y$gate[-1, ])
  changed <- x
  changed[1, "A"] <- 999
  expect_equal(gk_apply_residual_model(changed, m)$gate[-1, ], y$gate[-1, ])
  expect_equal(gk_apply_residual_model(x[1, , drop = FALSE], m)$gate,
                y$gate[1, , drop = FALSE])
  expect_equal(nrow(gk_apply_residual_model(x[FALSE, , drop = FALSE], m)$gate), 0)
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(m, path, version = 2)
  restored <- readRDS(path)
  expect_identical(restored$model_sha256, m$model_sha256)
  expect_identical(gk_apply_residual_model(x, restored), y)
  expect_identical(gk_fit_residual_model(x, c("A", "B", "C"))$model_sha256,
                    m$model_sha256)
})

test_that("model hashes bind values, dimensions, names and configuration", {
  x <- residual_fixture()
  m <- gk_fit_residual_model(x, c("A", "B", "C"), bindings = list(cut = 0))
  bad <- m
  bad$panel_scale[[1]] <- 2
  expect_error(gk_apply_residual_model(x, bad), class = "gatekeepr_error_state")
  bad <- m
  names(bad$panel_scale)[[1]] <- "changed"
  expect_error(gk_apply_residual_model(x, bad), class = "gatekeepr_error_state")
  bad <- m
  bad$panel_regression <- t(bad$panel_regression)
  expect_error(gk_apply_residual_model(x, bad), class = "gatekeepr_error_state")
  bad <- m
  bad$bindings$cut <- 1
  expect_error(gk_apply_residual_model(x, bad), class = "gatekeepr_error_state")
  bad <- m
  bad$schema <- "future"
  expect_error(gk_apply_residual_model(x, bad), class = "gatekeepr_error_state")
  bad <- m
  bad$model_sha256 <- NULL
  expect_error(gk_apply_residual_model(x, bad), class = "gatekeepr_error_state")
})

test_that("finite input policy and dictionary failures are explicit", {
  x <- residual_fixture()
  m <- gk_fit_residual_model(x, c("A", "B", "C"))
  expect_error(gk_apply_residual_model(x[, 5:1], m), class = "gatekeepr_error_input")
  expect_error(gk_apply_residual_model(x[, -1], m), class = "gatekeepr_error_input")
  for (value in c(NA_real_, NaN, Inf)) {
    bad <- x
    bad[1, "A"] <- value
    expect_error(gk_apply_residual_model(bad, m), class = "gatekeepr_error_input")
    expect_error(gk_fit_residual_model(bad, c("A", "B", "C")), class = "gatekeepr_error_input")
  }
  expect_error(gk_fit_residual_model(x[1:19, ], c("A", "B")), class = "gatekeepr_error_input")
  expect_error(gk_fit_residual_model(unname(x), "A"), class = "gatekeepr_error_input")
  expect_error(gk_fit_residual_model(as.data.frame(x), "A"), class = "gatekeepr_error_input")
  bad <- x
  colnames(bad)[[2]] <- "A"
  expect_error(gk_fit_residual_model(bad, "A"), class = "gatekeepr_error_input")
  expect_error(gk_fit_residual_model(x, "A", provenance = list("unnamed")),
               class = "gatekeepr_error_input")
  expect_error(gk_fit_residual_model(x, "A", bindings = list(fun = identity)),
               class = "gatekeepr_error_input")
})

test_that("scale fallback and unsupported optional markers are recorded", {
  x <- residual_fixture()
  x[, "D"] <- NA_real_
  x[1:19, "D"] <- 1:19
  x[, "E"] <- 0
  m <- gk_fit_residual_model(x, c("A", "B", "C"))
  y <- gk_apply_residual_model(x, m)
  expect_true(m$panel_robust$fallback[["E"]])
  expect_identical(m$panel_robust$scale[["E"]], 1)
  expect_true(all(is.na(y$gate[, "D"])))
  expect_true(all(is.finite(y$gate[, "E"])))
  expect_identical(m$panel_scale[["D"]], 1)
  x[, "D"] <- NA_real_
  m <- gk_fit_residual_model(x, c("A", "B", "C"))
  expect_true(all(is.na(gk_apply_residual_model(x, m)$gate[, "D"])))
  expect_error(gk_fit_residual_model(x * 0, c("A", "B", "C")),
               class = "gatekeepr_error_state")
})

test_that("single identity dimensions and invalid metadata remain explicit", {
  x <- residual_fixture()
  m <- gk_fit_residual_model(x, "A")
  y <- gk_apply_residual_model(x, m)
  expect_identical(dim(y$identity), c(120L, 1L))
  expect_true(all(y$identity == 0))
  expect_identical(dim(m$identity_regression), c(2L, 1L))
  expect_error(gk_fit_residual_model(x, "A", provenance = 1), class = "gatekeepr_error_input")
  expect_error(gk_fit_residual_model(x, "A", provenance = list(a = 1, a = 2)),
               class = "gatekeepr_error_input")
  expect_error(gk_fit_residual_model(x, "A", bindings = list(value = Inf)),
               class = "gatekeepr_error_input")
  expect_error(gk_fit_residual_model(x, "A", bindings = list(value = NaN)),
               class = "gatekeepr_error_input")
  a <- gk_fit_residual_model(x, "A", bindings = list(labels = c(TRUE, NA, FALSE)))
  b <- gk_fit_residual_model(x, "A", bindings = list(labels = c(TRUE, FALSE, NA)))
  expect_false(identical(a$model_sha256, b$model_sha256))
  a <- gk_fit_residual_model(x, "A", bindings = list(cuts = data.frame(cut = 0, row.names = "A")))
  b <- a
  rownames(b$bindings$cuts) <- "B"
  expect_error(gk_apply_residual_model(x, b), class = "gatekeepr_error_state")
  m <- gk_fit_residual_model(x, c("A", "B"),
    bindings = list(config = gk_example_config(), ordered = I(c("A", "B"))))
  path <- withr::local_tempfile(fileext = ".rds")
  saveRDS(m, path)
  expect_identical(gk_apply_residual_model(x, readRDS(path)),
                    gk_apply_residual_model(x, m))
  bad <- m
  class(bad$bindings$ordered) <- NULL
  expect_error(gk_apply_residual_model(x, bad), class = "gatekeepr_error_state")
})
