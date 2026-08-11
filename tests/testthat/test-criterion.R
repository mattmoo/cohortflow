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
# cf_criterion() -- randomise type

test_that("cf_criterion() accepts type = 'randomise' with NULL predicate", {
  crit <- cf_criterion(predicate = NULL, label = "Randomised", type = "randomise",
                       by = "cluster_id", arms = "arm")
  expect_s3_class(crit, "cf_criterion")
  expect_null(crit$predicate)
  expect_equal(crit$type, "randomise")
  expect_equal(crit$by,   "cluster_id")
  expect_equal(crit$arms, "arm")
})

test_that("cf_criterion() requires `by` for type = 'randomise'", {
  expect_error(
    cf_criterion(predicate = NULL, label = "Randomised", type = "randomise", arms = "arm"),
    class = "rlang_error"
  )
})

test_that("cf_criterion() requires `arms` for type = 'randomise'", {
  expect_error(
    cf_criterion(predicate = NULL, label = "Randomised", type = "randomise", by = "cluster_id"),
    class = "rlang_error"
  )
})

test_that("cf_criterion() requires a NULL predicate for type = 'randomise'", {
  expect_error(
    cf_criterion(~ TRUE, label = "Randomised", type = "randomise",
                 by = "cluster_id", arms = "arm"),
    class = "rlang_error"
  )
})

test_that("cf_criterion() requires a non-NULL predicate for other types", {
  expect_error(
    cf_criterion(predicate = NULL, label = "x", type = "include"),
    class = "rlang_error"
  )
})

test_that("cf_criterion() rejects `arms` for non-randomise types", {
  expect_error(
    cf_criterion(~ age >= 18, label = "Adults", type = "include", arms = "arm"),
    class = "rlang_error"
  )
})

test_that("print.cf_criterion() displays randomise steps without error", {
  crit <- cf_criterion(predicate = NULL, label = "Randomised", type = "randomise",
                       by = "cluster_id", arms = "arm")
  expect_output(print(crit), "Randomised")
  expect_output(print(crit), "\\[by: cluster_id\\]")
  expect_output(print(crit), "\\[arms: arm\\]")
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

# ---------------------------------------------------------------------------
# cf_criterion category parameter

test_that("cf_criterion() accepts a category", {
  crit <- cf_criterion(~ age >= 18, label = "Adults", category = "Age")
  expect_equal(crit$category, "Age")
})

test_that("cf_criterion() rejects empty category string", {
  expect_error(
    cf_criterion(~ age >= 18, label = "Adults", category = ""),
    class = "rlang_error"
  )
})

test_that("cf_criterion() rejects NA category", {
  expect_error(
    cf_criterion(~ age >= 18, label = "Adults", category = NA_character_),
    class = "rlang_error"
  )
})

# ---------------------------------------------------------------------------
# format methods

test_that("format.cf_criterion() returns a string", {
  crit <- cf_criterion(~ age >= 18, label = "Adults", type = "include")
  s    <- format(crit)
  expect_type(s, "character")
  expect_true(nzchar(s))
  expect_true(grepl("Adults", s))
})

test_that("format.cf_criterion() works for function predicate", {
  fn   <- function(d) !is.na(d$age)
  crit <- cf_criterion(fn, label = "Age present", type = "exclude")
  s    <- format(crit)
  expect_type(s, "character")
  expect_true(grepl("Age present", s))
})

test_that("format.cf_criterion() works for select_within", {
  crit <- cf_criterion(
    ~ consent_date == min(consent_date, na.rm = TRUE),
    label = "First consent",
    type  = "select_within",
    by    = "participant_id"
  )
  s <- format(crit)
  expect_true(grepl(">", s))
})

# ---------------------------------------------------------------------------
# eval_group_criterion

test_that("eval_group_criterion() works with formula predicate", {
  crit <- cf_criterion(
    ~ n() >= 2,
    label = "Min group size",
    type  = "group_include",
    by    = "grp"
  )
  d <- data.frame(
    grp = c("a", "a", "b"),
    x   = 1:3
  )
  res <- cohortflow:::eval_group_criterion(crit, d)
  expect_equal(unname(res), c(TRUE, TRUE, FALSE))
})

test_that("eval_group_criterion() works with function predicate", {
  # Function must return a data frame with the by column and .pass
  fn <- function(g) {
    dplyr::summarise(g, .pass = dplyr::n() >= 2, .groups = "drop")
  }
  crit <- cf_criterion(
    fn,
    label = "Min group size (fn)",
    type  = "group_include",
    by    = "grp"
  )
  d <- data.frame(grp = c("a", "a", "b"), x = 1:3)
  res <- cohortflow:::eval_group_criterion(crit, d)
  expect_equal(unname(res), c(TRUE, TRUE, FALSE))
})

test_that("eval_group_criterion() errors when by_col missing from data", {
  crit <- cf_criterion(~ n() >= 2, label = "Size", type = "group_include", by = "grp")
  d    <- data.frame(x = 1:3)
  expect_error(cohortflow:::eval_group_criterion(crit, d), class = "rlang_error")
})

test_that("eval_group_criterion() errors when fn does not return .pass column", {
  fn <- function(g) dplyr::summarise(g, result = dplyr::n() >= 2, .groups = "drop")
  crit <- cf_criterion(fn, label = "Bad fn", type = "group_include", by = "grp")
  d    <- data.frame(grp = c("a", "a"), x = 1:2)
  expect_error(cohortflow:::eval_group_criterion(crit, d), class = "rlang_error")
})

# ---------------------------------------------------------------------------
# eval_select_criterion

test_that("eval_select_criterion() works with formula predicate", {
  crit <- cf_criterion(
    ~ x == min(x),
    label = "Min per group",
    type  = "select_within",
    by    = "grp"
  )
  d   <- data.frame(grp = c("a", "a", "b", "b"), x = c(3, 1, 4, 2))
  res <- cohortflow:::eval_select_criterion(crit, d)
  expect_equal(res, c(FALSE, TRUE, FALSE, TRUE))
})

test_that("eval_select_criterion() works with function predicate", {
  fn <- function(g) g$x == min(g$x)
  crit <- cf_criterion(fn, label = "Min fn", type = "select_within", by = "grp")
  d    <- data.frame(grp = c("a", "a", "b", "b"), x = c(3, 1, 4, 2))
  res  <- cohortflow:::eval_select_criterion(crit, d)
  expect_equal(res, c(FALSE, TRUE, FALSE, TRUE))
})

test_that("eval_select_criterion() errors when by_col missing from data", {
  crit <- cf_criterion(~ x == min(x), label = "Min", type = "select_within", by = "grp")
  d    <- data.frame(x = 1:3)
  expect_error(cohortflow:::eval_select_criterion(crit, d), class = "rlang_error")
})

test_that("eval_select_criterion() errors when predicate returns wrong type", {
  fn <- function(g) as.integer(g$x == min(g$x))  # integer, not logical
  crit <- cf_criterion(fn, label = "Bad", type = "select_within", by = "grp")
  d    <- data.frame(grp = c("a", "a"), x = 1:2)
  expect_error(cohortflow:::eval_select_criterion(crit, d), class = "rlang_error")
})
