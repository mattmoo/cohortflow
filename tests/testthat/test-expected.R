test_that("cf_expected() cross-joins named vectors", {
  exp <- cf_expected(participant_id = 1:3, visit = c("baseline", "3mo"))
  expect_s3_class(exp, "tbl_df")
  expect_equal(nrow(exp), 6L)
  expect_named(exp, c("participant_id", "visit"))
  expect_setequal(exp$participant_id, 1:3)
  expect_setequal(exp$visit, c("baseline", "3mo"))
})

test_that("cf_expected() requires at least one named argument", {
  expect_error(cf_expected(), "at least one")
})

test_that("cf_expected() requires all arguments to be named", {
  expect_error(cf_expected(1:3), "must be named")
})

test_that("apply_criteria(expected=, by=) adds missing units as NA rows", {
  exp  <- cf_expected(participant_id = 1:5)
  dat  <- tibble::tibble(participant_id = c(1, 2, 4), x = c(TRUE, FALSE, TRUE))
  crit <- cf_criteria() |> include(~ x, label = "X true")

  flow <- suppressMessages(
    apply_criteria(dat, crit, id = "participant_id", expected = exp, by = "participant_id")
  )

  expect_equal(flow$steps[[1]]$n_in, 5L)
  surviving <- cohort(flow)
  expect_equal(sort(surviving$participant_id), c(1, 4))
})

test_that("apply_criteria(expected=) messages how many units were missing", {
  exp  <- cf_expected(participant_id = 1:5)
  dat  <- tibble::tibble(participant_id = c(1, 2, 4), x = TRUE)
  crit <- cf_criteria() |> include(~ x, label = "X true")

  expect_message(
    apply_criteria(dat, crit, id = "participant_id", expected = exp, by = "participant_id"),
    "2 expected unit"
  )
})

test_that("apply_criteria(expected=) is a no-op when every unit is present", {
  exp  <- cf_expected(participant_id = 1:3)
  dat  <- tibble::tibble(participant_id = 1:3, x = TRUE)
  crit <- cf_criteria() |> include(~ x, label = "X true")

  expect_no_message(
    flow <- apply_criteria(dat, crit, id = "participant_id", expected = exp, by = "participant_id")
  )
  expect_equal(flow$steps[[1]]$n_in, 3L)
})

test_that("apply_criteria() requires `by` when `expected` is supplied", {
  exp  <- cf_expected(participant_id = 1:3)
  dat  <- tibble::tibble(participant_id = 1:3, x = TRUE)
  crit <- cf_criteria() |> include(~ x, label = "X true")

  expect_error(
    apply_criteria(dat, crit, expected = exp),
    "`by`"
  )
})

test_that("apply_criteria() rejects `by` without `expected`", {
  dat  <- tibble::tibble(participant_id = 1:3, x = TRUE)
  crit <- cf_criteria() |> include(~ x, label = "X true")

  expect_error(
    apply_criteria(dat, crit, by = "participant_id"),
    "expected"
  )
})

test_that("apply_criteria(expected=) errors if `by` is missing from `expected`", {
  exp  <- tibble::tibble(pid = 1:3)
  dat  <- tibble::tibble(participant_id = 1:3, x = TRUE)
  crit <- cf_criteria() |> include(~ x, label = "X true")

  expect_error(
    apply_criteria(dat, crit, expected = exp, by = "participant_id"),
    "expected"
  )
})

test_that("apply_criteria(expected=) errors if `by` is missing from `data`", {
  exp  <- cf_expected(participant_id = 1:3)
  dat  <- tibble::tibble(pid = 1:3, x = TRUE)
  crit <- cf_criteria() |> include(~ x, label = "X true")

  expect_error(
    apply_criteria(dat, crit, expected = exp, by = "participant_id"),
    "data"
  )
})

test_that("apply_criteria(expected=) errors on colliding non-by columns", {
  exp  <- tibble::tibble(participant_id = 1:3, x = c(TRUE, FALSE, TRUE))
  dat  <- tibble::tibble(participant_id = 1:3, x = TRUE)
  crit <- cf_criteria() |> include(~ x, label = "X true")

  expect_error(
    apply_criteria(dat, crit, expected = exp, by = "participant_id"),
    "also present"
  )
})

test_that("apply_criteria(expected=) aborts on a duplicated key in `expected`", {
  exp  <- tibble::tibble(participant_id = c(1, 1, 2))
  dat  <- tibble::tibble(participant_id = 1:2, x = TRUE)
  crit <- cf_criteria() |> include(~ x, label = "X true")

  expect_error(
    apply_criteria(dat, crit, expected = exp, by = "participant_id"),
    "uniquely identify"
  )
})

test_that("apply_criteria(expected=) supports a composite (multi-column) by", {
  exp  <- cf_expected(participant_id = 1:2, visit = c("baseline", "3mo"))
  dat  <- tibble::tibble(
    participant_id = c(1, 1, 2),
    visit          = c("baseline", "3mo", "baseline"),
    x              = c(TRUE, TRUE, FALSE)
  )
  crit <- cf_criteria() |> include(~ x, label = "X true")

  flow <- suppressMessages(
    apply_criteria(dat, crit, id = c("participant_id", "visit"),
                   expected = exp, by = c("participant_id", "visit"))
  )
  expect_equal(flow$steps[[1]]$n_in, 4L)
  surviving <- cohort(flow)
  expect_equal(nrow(surviving), 2L)
})
