test_that("apply_criteria() returns a cf_flow object", {
  dat  <- suppressWarnings(mock_cohortflow(100, seed = 1))
  crit <- cf_criteria() |>
    include(~ eligible_screen, label = "Screening")
  flow <- apply_criteria(dat, crit)
  expect_s3_class(flow, "cf_flow")
  expect_named(flow, c("data", "criteria", "steps", "hierarchy"))
})


test_that("apply_criteria() adds .cf_row_id when absent", {
  dat  <- suppressWarnings(mock_cohortflow(50, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  expect_message(
    flow <- apply_criteria(dat, crit),
    "sequential"
  )
  expect_true(".cf_row_id" %in% names(flow$data))
})

test_that("apply_criteria() uses existing .cf_row_id column", {
  dat <- suppressWarnings(mock_cohortflow(50, seed = 1))
  dat$.cf_row_id <- seq_len(nrow(dat))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- suppressMessages(apply_criteria(dat, crit))
  expect_equal(flow$data$.cf_row_id, seq_len(nrow(dat)))
})

test_that("apply_criteria() uses supplied id column", {
  dat  <- suppressWarnings(mock_cohortflow(50, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- apply_criteria(dat, crit, id = "participant_id")
  expect_equal(flow$data$.cf_row_id, dat$participant_id)
})

test_that("apply_criteria() supports a composite (multi-column) id", {
  dat  <- suppressWarnings(mock_cohortflow(50, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- apply_criteria(dat, crit, id = c("participant_id", "period"))
  expect_equal(
    flow$data$.cf_row_id,
    paste(dat$participant_id, dat$period, sep = "\r")
  )
})

test_that("apply_criteria() warns on a duplicated composite id", {
  dat  <- suppressWarnings(mock_cohortflow(50, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  expect_warning(
    apply_criteria(dat, crit, id = c("cluster_id", "site_id")),
    "duplicate"
  )
})

test_that("apply_criteria() errors naming a missing composite id column", {
  dat  <- suppressWarnings(mock_cohortflow(50, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  expect_error(
    apply_criteria(dat, crit, id = c("participant_id", "nonexistent")),
    "nonexistent"
  )
})

test_that("include() step keeps TRUE rows cumulatively", {
  dat  <- suppressWarnings(mock_cohortflow(200, seed = 42))
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
  dat  <- suppressWarnings(mock_cohortflow(200, seed = 42))
  crit <- cf_criteria() |>
    include(~ eligible_screen, label = "Screening") |>
    exclude(~ withdrew, label = "Withdrew")
  flow <- suppressMessages(apply_criteria(dat, crit))

  s2 <- flow$steps[[2]]
  expect_true(s2$n_fail >= 0)
  expect_equal(s2$n_in, s2$n_pass + s2$n_fail)
})

test_that("group_include() removes all rows from failing groups", {
  dat  <- suppressWarnings(mock_cohortflow(300, n_clusters = 5, seed = 7))
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
  dat  <- suppressWarnings(mock_cohortflow(300, n_clusters = 5, seed = 7))
  crit <- cf_criteria() |>
    group_exclude(by = "cluster_id", ~ n() < 50, label = "Small clusters")
  flow <- suppressMessages(apply_criteria(dat, crit))

  surviving <- cohort(flow)
  orig_counts <- table(dat$cluster_id)
  surviving_clusters <- unique(surviving$cluster_id)
  expect_true(all(orig_counts[surviving_clusters] >= 50))
})

test_that("select_within() keeps only predicate-TRUE rows per group", {
  dat <- suppressWarnings(mock_cohortflow(100, seed = 1))
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

test_that("group_include() supports a composite (multi-column) by", {
  dat  <- suppressWarnings(mock_cohortflow(300, n_clusters = 5, seed = 7))
  crit <- cf_criteria() |>
    group_include(by = c("cluster_id", "period"), ~ n() >= 10,
                  label = "Sufficient cluster-period size")
  flow <- suppressMessages(apply_criteria(dat, crit))

  surviving <- cohort(flow)
  key_orig    <- paste(dat$cluster_id, dat$period)
  orig_counts <- table(key_orig)
  key_surv    <- unique(paste(surviving$cluster_id, surviving$period))
  expect_true(all(orig_counts[key_surv] >= 10))
})

test_that("select_within() supports a composite (multi-column) by", {
  dat <- suppressWarnings(mock_cohortflow(200, seed = 3))
  crit <- cf_criteria() |>
    include(~ !is.na(consent_date), label = "Has consent") |>
    select_within(
      by      = c("cluster_id", "period"),
      label   = "First consent per cluster-period",
      ~ consent_date == min(consent_date, na.rm = TRUE)
    )
  flow <- suppressMessages(apply_criteria(dat, crit))
  surviving <- cohort(flow)

  # Every surviving row must hold the minimum consent_date within its
  # (cluster_id, period) group (computed on the pre-selection, non-NA data).
  eligible <- dat[!is.na(dat$consent_date), ]
  eligible_key <- paste(eligible$cluster_id, eligible$period)
  min_by_key <- tapply(eligible$consent_date, eligible_key, min, na.rm = TRUE)

  surv_key <- paste(surviving$cluster_id, surviving$period)
  expect_true(all(surviving$consent_date == min_by_key[surv_key]))
  # No group should retain more rows than it has ties for the minimum
  expect_true(all(table(surv_key) <= table(eligible_key)[names(table(surv_key))]))
})

test_that("cohort() returns original columns without .cf_row_id", {
  dat  <- suppressWarnings(mock_cohortflow(100, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- suppressMessages(apply_criteria(dat, crit))
  out  <- cohort(flow)

  expect_false(".cf_row_id" %in% names(out))
  expect_true(all(names(dat) %in% names(out)))
})

test_that("cohort(flag = TRUE) returns all rows with attribution", {
  dat  <- suppressWarnings(mock_cohortflow(80, seed = 1))
  crit <- cf_criteria() |>
    include(~ eligible_screen, label = "Screening") |>
    exclude(~ withdrew, label = "Withdrew", category = "Consent")
  flow <- suppressMessages(apply_criteria(dat, crit))

  flagged <- cohort(flow, flag = TRUE)
  expect_equal(nrow(flagged), nrow(dat))
  expect_false(".cf_row_id" %in% names(flagged))
  expect_equal(sum(flagged$cf_included), nrow(cohort(flow)))
  expect_true(all(is.na(flagged$cf_excluded_step[flagged$cf_included])))
  expect_true(all(!is.na(flagged$cf_excluded_step[!flagged$cf_included])))
})

test_that("cohort(flag = TRUE) attributes to the first failing step only", {
  dat  <- tibble::tibble(id = 1:3, a = c(TRUE, FALSE, FALSE), b = c(TRUE, TRUE, FALSE))
  crit <- cf_criteria() |>
    include(~ a, label = "A") |>
    include(~ b, label = "B")
  flow    <- apply_criteria(dat, crit, id = "id")
  flagged <- cohort(flow, flag = TRUE)
  expect_equal(flagged$cf_excluded_step, c(NA_integer_, 1L, 1L))
})

test_that("cohort(flag = TRUE) marks everyone included when nothing is excluded", {
  dat  <- tibble::tibble(id = 1:5, x = TRUE)
  crit <- cf_criteria() |> include(~ x, label = "All true")
  flow <- apply_criteria(dat, crit, id = "id")
  flagged <- cohort(flow, flag = TRUE)
  expect_true(all(flagged$cf_included))
  expect_true(all(is.na(flagged$cf_excluded_step)))
})

test_that("excluded() returns flat tibble with cf_step / cf_label / cf_type", {
  dat  <- suppressWarnings(mock_cohortflow(200, seed = 3))
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
  dat  <- suppressWarnings(mock_cohortflow(200, seed = 5))
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
  dat  <- suppressWarnings(mock_cohortflow(100, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- suppressMessages(apply_criteria(dat, crit))
  expect_output(print(flow), "Cohort flow")
  expect_output(print(flow), "Screening")
})

test_that("multiple step types work together in one pipeline", {
  dat  <- suppressWarnings(mock_cohortflow(300, n_clusters = 6, seed = 99))
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

# ---------------------------------------------------------------------------
# randomise() step type

test_that("apply_criteria() passes all rows through a randomise() step unchanged", {
  dat  <- mock_cluster_rct(n_clusters = 6, n_participants = 150, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age recorded") |>
    randomise(by = "cluster_id", arms = "arm")
  flow <- suppressMessages(apply_criteria(dat, crit, id = "participant_id"))

  randomise_step <- flow$steps[[2]]
  expect_equal(randomise_step$type, "randomise")
  expect_equal(randomise_step$n_fail, 0L)
  expect_equal(randomise_step$n_in, randomise_step$n_pass)
  expect_equal(randomise_step$by,   "cluster_id")
  expect_equal(randomise_step$arms, "arm")
  expect_length(randomise_step$excluded_ids, 0L)
})

test_that("apply_criteria() records `arms` only for randomise steps", {
  dat  <- mock_cluster_rct(n_clusters = 6, n_participants = 150, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age recorded") |>
    randomise(by = "cluster_id", arms = "arm")
  flow <- suppressMessages(apply_criteria(dat, crit, id = "participant_id"))

  expect_null(flow$steps[[1]]$arms)
  expect_equal(flow$steps[[2]]$arms, "arm")
})

test_that("randomise() steps after exclusions still see the reduced entering N", {
  dat  <- mock_cluster_rct(n_clusters = 6, n_participants = 150, seed = 1)
  crit <- cf_criteria() |>
    exclude(~ withdrew, label = "Withdrew") |>
    randomise(by = "cluster_id", arms = "arm") |>
    include(~ !is.na(age), label = "Age recorded")
  flow <- suppressMessages(apply_criteria(dat, crit, id = "participant_id"))

  expect_equal(flow$steps[[2]]$n_in, flow$steps[[1]]$n_pass)
  expect_equal(flow$steps[[3]]$n_in, flow$steps[[2]]$n_pass)
})
