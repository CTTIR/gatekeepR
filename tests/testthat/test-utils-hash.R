test_that("canonical JSON sorts keys and removes whitespace", {
  a <- list(b = 1, a = list(z = "x", y = I(c(1, 2))))
  b <- list(a = list(y = I(c(1, 2)), z = "x"), b = 1)
  expect_identical(.gk_canonical_json(a), '{"a":{"y":[1,2],"z":"x"},"b":1}')
  expect_identical(.gk_canonical_json(a), .gk_canonical_json(b))
})

test_that("numbers use one spelling regardless of type or input form", {
  expect_identical(.gk_canonical_json(1L), "1")
  expect_identical(.gk_canonical_json(1), "1")
  expect_identical(.gk_canonical_json(-0), "0")
  expect_identical(.gk_canonical_json(0.1), "0.1")
  expect_identical(.gk_canonical_json(0.1 + 0.2), "0.30000000000000004")
  expect_identical(.gk_canonical_json(NA_real_), "null")
  from_json <- vapply(c("1", "1.0", "1e0", "10E-1"), function(s) {
    .gk_canonical_json(jsonlite::fromJSON(s))
  }, character(1))
  expect_true(all(from_json == "1"))
  expect_error(.gk_canonical_json(Inf), class = "gatekeepr_error_input")
})

test_that("scalars, arrays, empty objects and nulls are distinguished", {
  expect_identical(.gk_canonical_json(I("a")), '["a"]')
  expect_identical(.gk_canonical_json("a"), '"a"')
  expect_identical(.gk_canonical_json(list()), "[]")
  expect_identical(.gk_canonical_json(structure(list(), names = character())), "{}")
  expect_identical(.gk_canonical_json(list(a = NULL)), '{"a":null}')
  expect_identical(.gk_canonical_json(c(TRUE, NA)), "[true,null]")
  expect_identical(.gk_canonical_json(character()), "[]")
  expect_identical(.gk_canonical_json("café \"q\""), '"café \\"q\\""')
  expect_identical(.gk_canonical_json(factor("lvl")), '"lvl"')
  expect_identical(
    .gk_canonical_json(data.frame(b = 1:2, a = c("x", "y"))),
    '[{"a":"x","b":1},{"a":"y","b":2}]'
  )
  expect_error(.gk_canonical_json(list(a = 1, a = 2)), class = "gatekeepr_error_input")
  expect_error(.gk_canonical_json(sum), class = "gatekeepr_error_input")
})

test_that("pretty JSON parses to the same value as canonical JSON", {
  x <- list(b = I(c(1.5, 2)), a = list(c = "d"), e = structure(list(), names = character()))
  pretty <- .gk_to_json(x, pretty = TRUE)
  expect_match(pretty, "\n")
  expect_identical(
    jsonlite::fromJSON(pretty, simplifyVector = FALSE),
    jsonlite::fromJSON(.gk_canonical_json(x), simplifyVector = FALSE)
  )
})

test_that("data hashes depend on content, not on R serialisation", {
  m <- matrix(c(1.5, 2, NA, 4), 2, dimnames = list(NULL, c("a", "b")))
  h1 <- .gk_sha256_data(c("x", "y"), m, c(TRUE, NA), 1:2, NULL)
  h2 <- .gk_sha256_data(c("x", "y"), m, c(TRUE, NA), 1:2, NULL)
  expect_identical(h1, h2)
  expect_match(h1, "^[0-9a-f]{64}$")
  m2 <- m
  m2[1, 1] <- 1.5000000000000002
  expect_false(identical(h1, .gk_sha256_data(c("x", "y"), m2, c(TRUE, NA), 1:2, NULL)))
  expect_false(identical(.gk_sha256_data("a"), .gk_sha256_data(NA_character_)))
  expect_identical(.gk_short_hash(h1, 8L), substr(h1, 1, 8))
})
