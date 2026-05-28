test_that("apply_criteria() returns a cf_flow object", {
  dat  <- mock_cohortflow(100, seed = 1)
  crit <- cf_criteria() |>
    include(~ eligible_screen, label = "Screening")
  flow <- apply_criteria(dat, crit)
  expect_s3_class(flow, "cf_flow")
  expect_named(flow, c("data", "criteria", "steps"))
})

test_that("apply_criteria() adds .cf_row_id when absent", {
  dat  <- mock_cohortflow(50, seed = 1)
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  expect_message(
    flow <- apply_criteria(dat, crit),
    "sequential"
  )
  expect_true(".cf_row_id" %in% names(flow$data))
})

test_that("apply_criteria() uses existing .cf_row_id column", {
  dat <- mock_cohortflow(50, seed = 1)
  dat$.cf_row_id <- seq_len(nrow(dat))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- suppressMessages(apply_criteria(dat, crit))
  expect_equal(flow$data$.cf_row_id, seq_len(nrow(dat)))
})

test_that("apply_criteria() uses supplied id column", {
  dat  <- mock_cohortflow(50, seed = 1)
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- apply_criteria(dat, crit, id = "participant_id")
  expect_equal(flow$data$.cf_row_id, dat$participant_id)
})

test_that("include() step keeps TRUE rows cumulatively", {
  dat  <- mock_cohortflow(200, seed = 42)
  crit <- cf_criteria() |>
    include(~ eligible_screen, label = "Screening") |>
    include(~ !is.na(consent_date), label = "Consent")
  flow <- suppressMessages(apply_criteria(dat, crit))

  s1 <- flow$steps[[1]]
  s2 <- flow$steps[[2]]
  expect_equal(s1$n_in, nrow(dat))
  expect_equal(s1$n_in, s1$n_pass + s1$n_fail)
  expect_equal(s2$n_in, s1$n_pass)  # cumulative
})

test_that("exclude() step drops TRUE rows", {
  dat  <- mock_cohortflow(200, seed = 42)
  crit <- cf_criteria() |>
    include(~ eligible_screen, label = "Screening") |>
    exclude(~ withdrew, label = "Withdrew")
  flow <- suppressMessages(apply_criteria(dat, crit))

  s2 <- flow$steps[[2]]
  expect_true(s2$n_fail >= 0)
  expect_equal(s2$n_in, s2$n_pass + s2$n_fail)
})

test_that("group_include() removes all rows from failing groups", {
  dat  <- mock_cohortflow(300, n_clusters = 5, seed = 7)
  crit <- cf_criteria() |>
    group_include(by = "cluster_id", ~ n() >= 50, label = "Large clusters")
  flow <- suppressMessages(apply_criteria(dat, crit))

  surviving <- cohort(flow)
  # All surviving clusters must have >= 50 rows in the ORIGINAL data
  orig_counts <- table(dat$cluster_id)
  surviving_clusters <- unique(surviving$cluster_id)
  expect_true(all(orig_counts[surviving_clusters] >= 50))
})

test_that("group_exclude() removes all rows from matching groups", {
  dat  <- mock_cohortflow(300, n_clusters = 5, seed = 7)
  crit <- cf_criteria() |>
    group_exclude(by = "cluster_id", ~ n() < 50, label = "Small clusters")
  flow <- suppressMessages(apply_criteria(dat, crit))

  surviving <- cohort(flow)
  orig_counts <- table(dat$cluster_id)
  surviving_clusters <- unique(surviving$cluster_id)
  expect_true(all(orig_counts[surviving_clusters] >= 50))
})

test_that("select_within() keeps only predicate-TRUE rows per group", {
  dat <- mock_cohortflow(100, seed = 1)
  # Keep only one row per cluster (the one with the earliest consent_date)
  crit <- cf_criteria() |>
    include(~ !is.na(consent_date), label = "Has consent") |>
    select_within(
      by      = "cluster_id",
      label   = "First consent per cluster",
      ~ consent_date == min(consent_date, na.rm = TRUE)
    )
  flow <- suppressMessages(apply_criteria(dat, crit))
  surviving <- cohort(flow)

  # At most one row per cluster
  cluster_counts <- table(surviving$cluster_id)
  expect_true(all(cluster_counts <= 1))
})

test_that("cohort() returns original columns without .cf_row_id", {
  dat  <- mock_cohortflow(100, seed = 1)
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- suppressMessages(apply_criteria(dat, crit))
  out  <- cohort(flow)

  expect_false(".cf_row_id" %in% names(out))
  expect_true(all(names(dat) %in% names(out)))
})

test_that("excluded() returns flat tibble with cf_step / cf_label / cf_type", {
  dat  <- mock_cohortflow(200, seed = 3)
  crit <- cf_criteria() |>
    include(~ eligible_screen,    label = "Screening") |>
    include(~ !is.na(consent_date), label = "Consent")
  flow <- suppressMessages(apply_criteria(dat, crit))
  ex   <- excluded(flow)

  expect_s3_class(ex, "tbl_df")
  expect_true(all(c("cf_step", "cf_label", "cf_type") %in% names(ex)))
  expect_true(all(ex$cf_step %in% c(1L, 2L)))
})

test_that("cohort() + excluded() together account for all rows", {
  dat  <- mock_cohortflow(200, seed = 5)
  crit <- cf_criteria() |>
    include(~ eligible_screen,      label = "Screening") |>
    include(~ !is.na(consent_date), label = "Consent") |>
    exclude(~ withdrew,             label = "Withdrew")
  flow <- suppressMessages(apply_criteria(dat, crit))

  n_surviving <- nrow(cohort(flow))
  n_excluded  <- nrow(excluded(flow))
  # Every original row appears exactly once (either surviving or excluded)
  expect_equal(n_surviving + n_excluded, nrow(dat))
})

test_that("excluded() returns empty tibble when nothing excluded", {
  dat <- tibble::tibble(x = 1:5, .cf_row_id = 1:5)
  crit <- cf_criteria() |> include(~ x > 0, label = "All positive")
  flow <- apply_criteria(dat, crit)
  ex   <- excluded(flow)
  expect_equal(nrow(ex), 0L)
  expect_true(all(c("cf_step", "cf_label", "cf_type") %in% names(ex)))
})

test_that("print.cf_flow() produces output", {
  dat  <- mock_cohortflow(100, seed = 1)
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- suppressMessages(apply_criteria(dat, crit))
  expect_output(print(flow), "Cohort flow")
  expect_output(print(flow), "Screening")
})

test_that("multiple step types work together in one pipeline", {
  dat  <- mock_cohortflow(300, n_clusters = 6, seed = 99)
  crit <- cf_criteria() |>
    include(~ eligible_screen,         label = "Screening") |>
    include(~ !is.na(consent_date),    label = "Consent") |>
    group_include(by = "cluster_id", ~ n() >= 5, label = "Min cluster size") |>
    exclude(~ withdrew,                label = "Withdrew") |>
    select_within(by = "cluster_id",
                  ~ consent_date == min(consent_date, na.rm = TRUE),
                  label = "First per cluster")
  flow <- suppressMessages(apply_criteria(dat, crit))

  expect_length(flow$steps, 5L)
  expect_equal(flow$steps[[1]]$type, "include")
  expect_equal(flow$steps[[3]]$type, "group_include")
  expect_equal(flow$steps[[5]]$type, "select_within")
  expect_lte(nrow(cohort(flow)), nrow(dat))
})
