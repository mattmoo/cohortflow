test_that("continue_criteria() appends steps with continuing step numbers", {
  dat  <- suppressWarnings(mock_cohortflow(50, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- apply_criteria(dat, crit, id = "participant_id")

  more <- cf_criteria() |> include(~ !is.na(consent_date), label = "Consent")
  flow2 <- continue_criteria(flow, more)

  expect_length(flow2$steps, 2L)
  expect_equal(flow2$steps[[1]]$step, 1L)
  expect_equal(flow2$steps[[2]]$step, 2L)
  expect_equal(flow2$steps[[2]]$n_in, flow$steps[[1]]$n_pass)
})

test_that("continue_criteria() is a no-op when criteria is empty", {
  dat  <- suppressWarnings(mock_cohortflow(50, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- apply_criteria(dat, crit, id = "participant_id")

  expect_identical(continue_criteria(flow, cf_criteria()), flow)
})

test_that("continue_criteria() joins new columns and denominates on the surviving cohort", {
  dat  <- suppressWarnings(mock_cohortflow(50, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- apply_criteria(dat, crit, id = "participant_id")

  n_surviving <- flow$steps[[1]]$n_pass
  followup <- tibble::tibble(
    participant_id = dat$participant_id,
    followup_ok    = dat$eligible_screen
  )
  more <- cf_criteria() |> include(~ followup_ok, label = "Follow-up ok")
  flow2 <- continue_criteria(flow, more, join = followup, by = "participant_id")

  expect_equal(flow2$steps[[2]]$n_in, n_surviving)
  expect_true("followup_ok" %in% names(flow2$data))
  # Rows already excluded at step 1 still gain the new column (not dropped)
  expect_equal(nrow(flow2$data), nrow(dat))
})

test_that("continue_criteria() aborts on a duplicated key in `join`", {
  dat  <- suppressWarnings(mock_cohortflow(50, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- apply_criteria(dat, crit, id = "participant_id")

  dup_join <- tibble::tibble(
    participant_id = c(dat$participant_id[1], dat$participant_id[1], dat$participant_id[2]),
    x = 1:3
  )
  more <- cf_criteria() |> include(~ TRUE, label = "noop")

  expect_error(
    continue_criteria(flow, more, join = dup_join, by = "participant_id"),
    "uniquely identify"
  )
})

test_that("continue_criteria() requires `by` when `join` is supplied", {
  dat  <- suppressWarnings(mock_cohortflow(50, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- apply_criteria(dat, crit, id = "participant_id")

  join_df <- tibble::tibble(participant_id = dat$participant_id, x = 1)
  more <- cf_criteria() |> include(~ TRUE, label = "noop")

  expect_error(continue_criteria(flow, more, join = join_df), "`by`")
})

test_that("continue_criteria() errors on colliding non-by columns in `join`", {
  dat  <- suppressWarnings(mock_cohortflow(50, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- apply_criteria(dat, crit, id = "participant_id")

  join_df <- tibble::tibble(participant_id = dat$participant_id, eligible_screen = TRUE)
  more <- cf_criteria() |> include(~ TRUE, label = "noop")

  expect_error(
    continue_criteria(flow, more, join = join_df, by = "participant_id"),
    "also present"
  )
})

test_that("continue_criteria() handles a fully-excluded (0-row) surviving cohort", {
  dat  <- suppressWarnings(mock_cohortflow(50, seed = 1))
  crit <- cf_criteria() |> include(~ participant_id < 0, label = "Fails everyone")
  flow <- apply_criteria(dat, crit, id = "participant_id")
  expect_equal(flow$steps[[1]]$n_pass, 0L)

  more <- cf_criteria() |> include(~ participant_id > -Inf, label = "noop")
  flow2 <- continue_criteria(flow, more)

  expect_equal(flow2$steps[[2]]$n_in, 0L)
  expect_equal(flow2$steps[[2]]$n_pass, 0L)
})

test_that("continue_criteria() combined criteria/steps concatenate correctly", {
  dat  <- suppressWarnings(mock_cohortflow(50, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")
  flow <- apply_criteria(dat, crit, id = "participant_id")

  more <- cf_criteria() |> include(~ !is.na(consent_date), label = "Consent")
  flow2 <- continue_criteria(flow, more)

  expect_length(flow2$criteria, 2L)
  expect_s3_class(flow2, "cf_flow")
  expect_lte(nrow(cohort(flow2)), nrow(cohort(flow)))
})
