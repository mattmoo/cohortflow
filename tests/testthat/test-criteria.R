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

test_that("format.cf_criteria() returns a character string", {
  crit <- cf_criteria() |>
    include(~ age >= 18, label = "Adults") |>
    exclude(~ withdrew,  label = "Withdrew")
  s <- format(crit)
  expect_type(s, "character")
  expect_true(nzchar(s))
})

test_that("group_exclude() adds a group_exclude step", {
  crit <- cf_criteria() |>
    group_exclude(by = "cluster_id", ~ n() < 5, label = "Small clusters")
  expect_equal(crit$steps[[1]]$type, "group_exclude")
  expect_equal(crit$steps[[1]]$by,   "cluster_id")
})

test_that("select_within() adds a select_within step", {
  crit <- cf_criteria() |>
    select_within(
      by    = "participant_id",
      label = "First per patient",
      ~ consent_date == min(consent_date, na.rm = TRUE)
    )
  expect_equal(crit$steps[[1]]$type, "select_within")
  expect_equal(crit$steps[[1]]$by,   "participant_id")
})

test_that("cf_criteria() constructed with cf_criterion objects directly", {
  cr <- cf_criterion(~ age >= 18, label = "Adults")
  crit <- cf_criteria(cr)
  expect_equal(length(crit), 1L)
  expect_equal(crit$steps[[1]]$label, "Adults")
})

test_that("cf_criteria() errors if non-cf_criterion passed directly", {
  expect_error(cf_criteria(list(a = 1)), class = "rlang_error")
})

# ---------------------------------------------------------------------------
# randomise() -- criterion builder

test_that("randomise() adds a randomise step with a default label", {
  crit <- cf_criteria() |> randomise(by = "cluster_id", arms = "arm")
  expect_equal(length(crit), 1L)
  expect_equal(crit$steps[[1]]$type,  "randomise")
  expect_equal(crit$steps[[1]]$label, "Randomised")
  expect_equal(crit$steps[[1]]$by,    "cluster_id")
  expect_equal(crit$steps[[1]]$arms,  "arm")
  expect_null(crit$steps[[1]]$predicate)
})

test_that("randomise() accepts an explicit label", {
  crit <- cf_criteria() |> randomise(by = "cluster_id", arms = "arm", label = "Allocation")
  expect_equal(crit$steps[[1]]$label, "Allocation")
})

test_that("randomise() can be combined with other builders in a pipeline", {
  crit <- cf_criteria() |>
    include(~ eligible, label = "Eligible") |>
    randomise(by = "cluster_id", arms = "arm") |>
    exclude(~ withdrew, label = "Withdrew after allocation")

  expect_equal(length(crit), 3L)
  expect_equal(vapply(crit$steps, `[[`, character(1L), "type"),
               c("include", "randomise", "exclude"))
})

test_that("print.cf_criteria() displays randomise steps without error", {
  crit <- cf_criteria() |> randomise(by = "cluster_id", arms = "arm")
  expect_output(print(crit), "Randomised")
  expect_output(print(crit), "arms: arm")
})
