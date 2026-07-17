# ===========================================================================
# Tests for design-specific mock data generators
# ===========================================================================

# ---------------------------------------------------------------------------
# mock_parallel_rct
# ---------------------------------------------------------------------------

test_that("mock_parallel_rct() returns a tibble with expected columns", {
  d <- mock_parallel_rct(seed = 1)
  expect_s3_class(d, "tbl_df")

  expected_cols <- c(
    "participant_id", "arm", "age", "age_group", "sex", "ethnicity",
    "eligible_screen", "consent_date", "baseline_complete", "withdrew"
  )
  expect_true(all(expected_cols %in% names(d)))
})

test_that("mock_parallel_rct() respects n_participants", {
  d <- mock_parallel_rct(n_participants = 150, seed = 1)
  expect_equal(nrow(d), 150L)
})

test_that("mock_parallel_rct() arm values come from arm_labels", {
  d <- mock_parallel_rct(n_participants = 200, arm_labels = c("Placebo", "Drug"), seed = 1)
  expect_true(all(d$arm %in% c("Placebo", "Drug")))
  expect_true(all(c("Placebo", "Drug") %in% d$arm))
})

test_that("mock_parallel_rct() is reproducible with same seed", {
  d1 <- mock_parallel_rct(seed = 42)
  d2 <- mock_parallel_rct(seed = 42)
  expect_identical(d1, d2)
})

test_that("mock_parallel_rct() errors with fewer than 2 arm_labels", {
  expect_error(mock_parallel_rct(arm_labels = "OnlyOne"), class = "rlang_error")
})

# ---------------------------------------------------------------------------
# mock_crossover
# ---------------------------------------------------------------------------

test_that("mock_crossover() returns a tibble with expected columns", {
  d <- mock_crossover(seed = 1)
  expect_s3_class(d, "tbl_df")

  expected_cols <- c(
    "participant_id", "event_id", "period", "sequence", "arm",
    "age", "age_group", "sex", "ethnicity",
    "eligible_screen", "consent_date", "baseline_complete", "withdrew"
  )
  expect_true(all(expected_cols %in% names(d)))
})

test_that("mock_crossover() produces one row per participant per period", {
  d <- mock_crossover(n_participants = 50, arm_labels = c("A", "B"), seed = 1)
  expect_equal(nrow(d), 50L * 2L)
  expect_true(all(table(d$participant_id) == 2L))
})

test_that("mock_crossover() arm is derived from sequence and period", {
  d <- mock_crossover(n_participants = 40, arm_labels = c("A", "B"), seed = 1)

  # For sequence "AB": period 1 = A, period 2 = B
  ab_rows <- d[d$sequence == "AB", ]
  expect_true(all(ab_rows$arm[ab_rows$period == 1] == "A"))
  expect_true(all(ab_rows$arm[ab_rows$period == 2] == "B"))

  # For sequence "BA": period 1 = B, period 2 = A
  ba_rows <- d[d$sequence == "BA", ]
  expect_true(all(ba_rows$arm[ba_rows$period == 1] == "B"))
  expect_true(all(ba_rows$arm[ba_rows$period == 2] == "A"))
})

test_that("mock_crossover() consent-flow columns are constant within participant", {
  d <- mock_crossover(n_participants = 30, seed = 1)
  by_pid <- split(d, d$participant_id)
  consistent <- vapply(by_pid, function(rows) {
    length(unique(rows$withdrew)) == 1L && length(unique(rows$consent_date)) == 1L
  }, logical(1))
  expect_true(all(consistent))
})

test_that("mock_crossover() is reproducible with same seed", {
  d1 <- mock_crossover(seed = 7)
  d2 <- mock_crossover(seed = 7)
  expect_identical(d1, d2)
})

test_that("mock_crossover() errors with fewer than 2 arm_labels", {
  expect_error(mock_crossover(arm_labels = "OnlyOne"), class = "rlang_error")
})

# ---------------------------------------------------------------------------
# mock_cluster_rct
# ---------------------------------------------------------------------------

test_that("mock_cluster_rct() returns a tibble with expected columns", {
  d <- mock_cluster_rct(seed = 1)
  expect_s3_class(d, "tbl_df")

  expected_cols <- c(
    "participant_id", "cluster_id", "site_id", "arm",
    "age", "age_group", "sex", "ethnicity",
    "eligible_screen", "consent_date", "baseline_complete", "withdrew"
  )
  expect_true(all(expected_cols %in% names(d)))
})

test_that("mock_cluster_rct() respects n_participants and n_clusters", {
  d <- mock_cluster_rct(n_clusters = 6, n_participants = 240, seed = 1)
  expect_equal(nrow(d), 240L)
  expect_lte(dplyr::n_distinct(d$cluster_id), 6L)
})

test_that("mock_cluster_rct() assigns arm at the cluster level", {
  d <- mock_cluster_rct(n_clusters = 8, n_participants = 200, seed = 1)
  arm_per_cluster <- tapply(d$arm, d$cluster_id, function(x) length(unique(x)))
  expect_true(all(arm_per_cluster == 1L))
})

test_that("mock_cluster_rct() errors if n_sites > n_clusters", {
  expect_error(mock_cluster_rct(n_clusters = 3, n_sites = 5), class = "rlang_error")
})

test_that("mock_cluster_rct() is reproducible with same seed", {
  d1 <- mock_cluster_rct(seed = 3)
  d2 <- mock_cluster_rct(seed = 3)
  expect_identical(d1, d2)
})

# ---------------------------------------------------------------------------
# mock_stepped_wedge
# ---------------------------------------------------------------------------

test_that("mock_stepped_wedge() returns a tibble with expected columns", {
  d <- mock_stepped_wedge(seed = 1)
  expect_s3_class(d, "tbl_df")

  expected_cols <- c(
    "participant_id", "event_id", "cluster_id", "site_id", "period",
    "sequence", "arm", "age", "age_group", "sex", "ethnicity",
    "eligible_screen", "consent_date", "baseline_complete", "withdrew"
  )
  expect_true(all(expected_cols %in% names(d)))
})

test_that("mock_stepped_wedge() produces one row per participant per period", {
  d <- mock_stepped_wedge(n_clusters = 6, n_participants = 60, n_periods = 3, seed = 1)
  expect_equal(nrow(d), 60L * 3L)
})

test_that("mock_stepped_wedge() arm is derived from period >= sequence", {
  d <- mock_stepped_wedge(n_clusters = 8, n_participants = 200, n_periods = 4, seed = 1)

  expected_arm <- ifelse(d$period >= d$sequence, "Intervention", "Control")
  expect_equal(d$arm, expected_arm)
})

test_that("mock_stepped_wedge() every cluster is control in period 1 and intervention in the final period", {
  d <- mock_stepped_wedge(n_clusters = 6, n_participants = 120, n_periods = 4, seed = 1)

  period1 <- d[d$period == 1, ]
  expect_true(all(period1$arm == "Control"))

  last_period <- max(d$period)
  final <- d[d$period == last_period, ]
  expect_true(all(final$arm == "Intervention"))
})

test_that("mock_stepped_wedge() errors if n_periods < 2", {
  expect_error(mock_stepped_wedge(n_periods = 1), class = "rlang_error")
})

test_that("mock_stepped_wedge() errors if n_sites > n_clusters", {
  expect_error(mock_stepped_wedge(n_clusters = 3, n_sites = 5), class = "rlang_error")
})

test_that("mock_stepped_wedge() is reproducible with same seed", {
  d1 <- mock_stepped_wedge(seed = 11)
  d2 <- mock_stepped_wedge(seed = 11)
  expect_identical(d1, d2)
})
