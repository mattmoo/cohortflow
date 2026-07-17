test_that("mock_cohortflow() is deprecated", {
  expect_warning(mock_cohortflow(seed = 1), "deprecated")
})


test_that("mock_cohortflow() returns a tibble with expected columns", {
  d <- suppressWarnings(mock_cohortflow(seed = 1))
  expect_s3_class(d, "tbl_df")

  expected_cols <- c(
    "participant_id", "event_id", "cluster_id", "site_id", "period", "sequence",
    "age", "age_group", "sex", "ethnicity",
    "eligible_screen", "consent_date", "baseline_complete", "withdrew"
  )
  expect_true(all(expected_cols %in% names(d)))
})

test_that("mock_cohortflow() respects n_participants", {
  d <- suppressWarnings(mock_cohortflow(n_participants = 100, seed = 1))
  expect_equal(nrow(d), 100L)
})

test_that("mock_cohortflow() respects n_clusters", {
  d <- suppressWarnings(mock_cohortflow(n_participants = 200, n_clusters = 5, seed = 1))
  expect_lte(dplyr::n_distinct(d$cluster_id), 5L)
})

test_that("mock_cohortflow() respects n_periods", {
  d <- suppressWarnings(mock_cohortflow(n_periods = 3, seed = 1))
  expect_true(all(d$period %in% 1:3))
})

test_that("mock_cohortflow() is reproducible with same seed", {
  d1 <- suppressWarnings(mock_cohortflow(seed = 42))
  d2 <- suppressWarnings(mock_cohortflow(seed = 42))
  expect_identical(d1, d2)
})

test_that("mock_cohortflow() differs with different seeds", {
  d1 <- suppressWarnings(mock_cohortflow(seed = 1))
  d2 <- suppressWarnings(mock_cohortflow(seed = 2))
  expect_false(identical(d1, d2))
})

test_that("mock_cohortflow() sequence is NA when n_periods == 1", {
  d <- suppressWarnings(mock_cohortflow(n_periods = 1, seed = 1))
  expect_true(all(is.na(d$sequence)))
})

test_that("mock_cohortflow() errors if n_sites > n_clusters", {
  expect_error(suppressWarnings(mock_cohortflow(n_clusters = 3, n_sites = 5)), class = "rlang_error")
})

test_that("mock_cohortflow() has some NAs in age (missing data)", {
  d <- suppressWarnings(mock_cohortflow(n_participants = 500, seed = 1))
  expect_true(any(is.na(d$age)))
})

test_that("mock_cohortflow() has some rows without consent (NA consent_date)", {
  d <- suppressWarnings(mock_cohortflow(n_participants = 500, seed = 1))
  expect_true(any(is.na(d$consent_date)))
})

test_that("mock_cohortflow() withdrew is only TRUE for baseline-complete rows", {
  d <- suppressWarnings(mock_cohortflow(seed = 1))
  # Anyone who withdrew must have completed baseline
  withdrew_rows <- d[d$withdrew, ]
  expect_true(all(withdrew_rows$baseline_complete))
})
