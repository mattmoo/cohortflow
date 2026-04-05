test_that("cf_criteria() creates an empty pipeline", {
  crit <- cf_criteria()
  expect_s3_class(crit, "cf_criteria")
  expect_equal(length(crit), 0L)

})

test_that("include() adds an inclusion criterion", {
  crit <- cf_criteria() |> include(~ age >= 18, label = "Adults")
  expect_equal(length(crit), 1L)
  expect_equal(crit$steps[[1]]$type,  "include")
  expect_equal(crit$steps[[1]]$label, "Adults")
})

test_that("exclude() adds an exclusion criterion", {
  crit <- cf_criteria() |> exclude(~ withdrew == TRUE, label = "Withdrew")
  expect_equal(length(crit), 1L)
  expect_equal(crit$steps[[1]]$type, "exclude")
})

test_that("piped include/exclude accumulates steps in order", {
  crit <- cf_criteria() |>
    include(~ age >= 18,         label = "Adults") |>
    include(~ !is.na(age),       label = "Age known") |>
    exclude(~ withdrew == TRUE,  label = "Withdrew")

  expect_equal(length(crit), 3L)
  expect_equal(crit$steps[[1]]$label, "Adults")
  expect_equal(crit$steps[[3]]$label, "Withdrew")
})

test_that("group_include() adds a group step", {
  crit <- cf_criteria() |>
    group_include(by = "cluster_id", ~ n() >= 5, label = "Min size")
  expect_equal(crit$steps[[1]]$type, "group_include")
  expect_equal(crit$steps[[1]]$by,   "cluster_id")
})


test_that("include()/exclude() accept function predicates", {
  has_consent <- function(d) !is.na(d$consent_date)
  crit <- cf_criteria() |> include(has_consent, label = "Consent")
  expect_true(is.function(crit$steps[[1]]$predicate))
})

test_that("[ subsetting preserves class", {
  crit <- cf_criteria() |>
    include(~ age >= 18,   label = "Adults") |>
    exclude(~ is.na(age),  label = "Missing age")
  sub  <- crit[1]
  expect_s3_class(sub, "cf_criteria")
  expect_equal(length(sub), 1L)
  expect_equal(sub$steps[[1]]$label, "Adults")
})

test_that("c() combines two cf_criteria pipelines", {
  crit1 <- cf_criteria() |> include(~ age >= 18,  label = "Adults")
  crit2 <- cf_criteria() |> exclude(~ withdrew,   label = "Withdrew")
  both  <- c(crit1, crit2)
  expect_s3_class(both, "cf_criteria")
  expect_equal(length(both), 2L)
})

test_that("c() combines steps from two pipelines", {
  a  <- cf_criteria() |> include(~ x > 0,  label = "Positive")
  b  <- cf_criteria() |> exclude(~ is.na(x), label = "Missing")
  ab <- c(a, b)
  expect_length(ab, 2L)
  expect_equal(ab$steps[[1]]$label, "Positive")
  expect_equal(ab$steps[[2]]$label, "Missing")
})

test_that("print.cf_criteria() runs without error", {
  crit <- cf_criteria() |>
    include(~ age >= 18, label = "Adults") |>
    exclude(~ withdrew,  label = "Withdrew")
  expect_output(print(crit))
})

test_that("print.cf_criteria() handles an empty pipeline", {
  expect_output(print(cf_criteria()), "empty")
})
