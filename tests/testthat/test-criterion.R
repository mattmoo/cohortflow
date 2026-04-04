test_that("cf_criterion() accepts a formula", {
  crit <- cf_criterion(~ age >= 18, label = "Adults only", type = "include")
  expect_s3_class(crit, "cf_criterion")
  expect_equal(crit$label, "Adults only")
  expect_equal(crit$type,  "include")
  expect_true(inherits(crit$predicate, "formula"))
})

test_that("cf_criterion() accepts a function", {
  fn   <- function(d) !is.na(d$consent_date)
  crit <- cf_criterion(fn, label = "Consent recorded", type = "include")
  expect_s3_class(crit, "cf_criterion")
  expect_true(is.function(crit$predicate))
})

test_that("cf_criterion() rejects non-formula/function predicates", {
  expect_error(cf_criterion("age >= 18", label = "x"), class = "rlang_error")
  expect_error(cf_criterion(TRUE,        label = "x"), class = "rlang_error")
})

test_that("cf_criterion() rejects two-sided formulas", {
  expect_error(cf_criterion(y ~ x, label = "bad"), class = "rlang_error")
})

test_that("cf_criterion() requires a non-empty label", {
  expect_error(cf_criterion(~ age >= 18, label = ""),  class = "rlang_error")
  expect_error(cf_criterion(~ age >= 18, label = NA_character_), class = "rlang_error")
})

test_that("cf_criterion() defaults type to 'include'", {
  crit <- cf_criterion(~ age >= 18, label = "Adults")
  expect_equal(crit$type, "include")
})

test_that("print.cf_criterion() runs without error", {
  crit <- cf_criterion(~ age >= 18, label = "Adults", type = "include")
  expect_output(print(crit))
})

# ---------------------------------------------------------------------------
# eval_criterion

test_that("eval_criterion() works with a formula predicate", {
  crit <- cf_criterion(~ age >= 18, label = "Adults", type = "include")
  d    <- data.frame(age = c(10, 20, 30, NA))
  res  <- cohortflow:::eval_criterion(crit, d)
  expect_equal(res, c(FALSE, TRUE, TRUE, NA))
})

test_that("eval_criterion() works with a function predicate", {
  fn   <- function(d) !is.na(d$consent_date)
  crit <- cf_criterion(fn, label = "Consent", type = "include")
  d    <- data.frame(consent_date = as.Date(c("2023-01-01", NA, "2023-06-01")))
  res  <- cohortflow:::eval_criterion(crit, d)
  expect_equal(res, c(TRUE, FALSE, TRUE))
})

test_that("eval_criterion() errors if predicate returns wrong length", {
  fn   <- function(d) TRUE   # scalar, not length-n
  crit <- cf_criterion(fn, label = "Bad fn", type = "include")
  d    <- data.frame(x = 1:5)
  expect_error(cohortflow:::eval_criterion(crit, d), class = "rlang_error")
})

test_that("eval_criterion() errors if predicate returns non-logical", {
  fn   <- function(d) as.integer(d$x > 0)
  crit <- cf_criterion(fn, label = "Int fn", type = "include")
  d    <- data.frame(x = 1:3)
  expect_error(cohortflow:::eval_criterion(crit, d), class = "rlang_error")
})
