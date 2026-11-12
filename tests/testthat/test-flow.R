# Tests for cohort(at =) / excluded(at =)

test_that("at = NULL is identical to the default", {
  f <- make_flow_categorised()
  expect_identical(cohort(f, at = NULL), cohort(f))
  expect_identical(cohort(f, flag = TRUE, at = NULL), cohort(f, flag = TRUE))
  expect_identical(excluded(f, at = NULL), excluded(f))
})

test_that("cohort() and excluded() counts agree with step records", {
  f <- make_flow_categorised()
  n <- length(f$steps)
  n_fail <- vapply(f$steps, function(s) s$n_fail, numeric(1L))
  for (k in seq_len(n)) {
    expect_equal(nrow(cohort(f, at = k)), f$steps[[k]]$n_pass)
    ex <- excluded(f, at = k)
    expect_equal(nrow(ex), sum(n_fail[seq_len(k)]))
    if (nrow(ex) > 0L) expect_lte(max(ex$cf_step), k)
  }
  expect_identical(cohort(f, at = n), cohort(f))
  expect_identical(excluded(f, at = n), excluded(f))
})

test_that("at = 0 gives the starting data and no exclusions", {
  f <- make_flow_categorised()
  co <- cohort(f, at = 0)
  expect_equal(nrow(co), nrow(f$data))
  expect_false(".cf_row_id" %in% names(co))
  ex <- excluded(f, at = 0)
  expect_equal(nrow(ex), 0L)
  expect_true(all(c("cf_step", "cf_label", "cf_type", "cf_category") %in% names(ex)))
})

test_that("cohort(at) keeps original order; excluded(at) is in step order", {
  f <- make_flow_categorised()
  co <- cohort(f, at = 3)
  keep <- f$data$.cf_row_id %in% .surviving_ids(f, 3)
  expect_identical(co$participant_id, f$data$participant_id[keep])
  ex <- excluded(f, at = 4)
  expect_false(is.unsorted(ex$cf_step))
})

test_that("label and category lookup resolve to step numbers", {
  f <- make_flow_categorised()
  expect_identical(cohort(f, at = "Adults only"), cohort(f, at = 2))
  expect_identical(excluded(f, at = "Adults only"), excluded(f, at = 2))
  expect_identical(cohort(f, at = "Consent"), cohort(f, at = 5))
  expect_identical(cohort(f, at = "Valid age"), cohort(f, at = 2))
  expect_identical(excluded(f, at = "Consent"), excluded(f, at = 5))
})

test_that("flag = TRUE with at attributes only up to that step", {
  f <- make_flow_categorised()
  full <- cohort(f, flag = TRUE)
  k <- 3
  part <- cohort(f, flag = TRUE, at = k)
  expect_equal(nrow(part), nrow(full))
  late <- !is.na(full$cf_excluded_step) & full$cf_excluded_step > k
  expect_true(any(late))
  expect_true(all(part$cf_included[late]))
  expect_true(all(is.na(part$cf_excluded_step[late])))
  expect_true(all(is.na(part$cf_excluded_label[late])))
  expect_true(all(is.na(part$cf_excluded_category[late])))
  early <- !is.na(full$cf_excluded_step) & full$cf_excluded_step <= k
  expect_identical(part$cf_excluded_step[early], full$cf_excluded_step[early])
  expect_equal(sum(part$cf_included), f$steps[[k]]$n_pass)
})

test_that("flows with no exclusions work at every at", {
  f <- make_flow_no_exclusions()
  expect_equal(nrow(cohort(f, at = 0)), nrow(f$data))
  expect_equal(nrow(cohort(f, at = 1)), nrow(f$data))
  expect_equal(nrow(excluded(f, at = 1)), 0L)
  expect_true(all(cohort(f, flag = TRUE, at = 1)$cf_included))
})

test_that("invalid at values abort with informative messages", {
  f <- make_flow_categorised()
  n <- length(f$steps)
  expect_error(cohort(f, at = -1), "out of range")
  expect_error(cohort(f, at = n + 1), "out of range")
  expect_error(excluded(f, at = n + 1), "out of range")
  expect_error(cohort(f, at = 1.5), "whole step number")
  expect_error(cohort(f, at = NA), "single non-missing")
  expect_error(cohort(f, at = c(1, 2)), "single non-missing")
  expect_error(cohort(f, at = "Nope"), "Nope.*matches no step")
  expect_error(cohort(f, at = TRUE), "step number or a step label")
})

test_that("ambiguous labels / label-category clashes abort", {
  dat <- mock_parallel_rct(n_participants = 100, seed = 1)
  dup_crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Check") |>
    include(~ age >= 18, label = "Check")
  dup <- apply_criteria(dat, dup_crit)
  expect_error(cohort(dup, at = "Check"), "matches 2 steps by label")

  clash_crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age", category = "Eligibility") |>
    include(~ age >= 18, label = "Adults", category = "Age")
  clash <- apply_criteria(dat, clash_crit)
  expect_error(cohort(clash, at = "Age"), "both a step label and a category")
})

test_that("explicit step_number / label / category match the at= auto-select", {
  f <- make_flow_categorised()
  expect_identical(cohort(f, step_number = 3), cohort(f, at = 3))
  expect_identical(cohort(f, step_number = 0), cohort(f, at = 0))
  expect_identical(cohort(f, label = "Adults only"), cohort(f, at = 2))
  expect_identical(cohort(f, category = "Consent"), cohort(f, at = 5))
  expect_identical(excluded(f, label = "Adults only"), excluded(f, at = 2))
  expect_identical(excluded(f, category = "Valid age"), excluded(f, at = 2))
  expect_identical(excluded(f, step_number = 4), excluded(f, at = 4))
  expect_identical(cohort(f, flag = TRUE, label = "Adults only"),
                   cohort(f, flag = TRUE, at = 2))
})

test_that("explicit selectors error on bad input; at most one selector", {
  f <- make_flow_categorised()
  expect_error(cohort(f, step_number = 99), "`step_number` = 99 is out of range")
  expect_error(cohort(f, step_number = 1.5), "whole step number")
  expect_error(cohort(f, step_number = "2"), "whole number")
  expect_error(cohort(f, label = "Nope"), "matches no step label")
  expect_error(cohort(f, label = "Consent"), "matches no step label")  # a category only
  expect_error(cohort(f, category = "Nope"), "matches no category")
  expect_error(cohort(f, category = "Adults only"), "matches no category")  # a label only
  expect_error(cohort(f, label = 3), "single non-missing string")
  expect_error(cohort(f, at = 1, label = "Adults only"), "at most one")
  expect_error(excluded(f, step_number = 1, category = "Consent"), "at most one")
})

test_that("label and category can be used explicitly when at= is ambiguous", {
  dat <- mock_parallel_rct(n_participants = 100, seed = 1)
  clash_crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age", category = "Eligibility") |>
    include(~ age >= 18, label = "Adults", category = "Age")
  clash <- apply_criteria(dat, clash_crit)
  expect_identical(cohort(clash, label = "Age"), cohort(clash, step_number = 1))
  expect_identical(cohort(clash, category = "Age"), cohort(clash, step_number = 2))

  dup_crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Check") |>
    include(~ age >= 18, label = "Check")
  dup <- apply_criteria(dat, dup_crit)
  expect_error(cohort(dup, label = "Check"), "use `step_number`")
})

test_that("at works across a continue_criteria() stage boundary", {
  dat <- mock_parallel_rct(n_participants = 200, seed = 1)
  crit1 <- cf_criteria() |> include(~ eligible_screen, label = "Passed screening")
  f1 <- apply_criteria(dat, crit1, id = "participant_id")
  extra <- data.frame(participant_id = dat$participant_id,
                      keep_flag = dat$age >= 40 & !is.na(dat$age))
  f2 <- continue_criteria(
    f1,
    cf_criteria() |> include(~ keep_flag, label = "Older"),
    join = extra, by = "participant_id"
  )
  # f2$data carries the joined column; compare on the original columns
  expect_identical(cohort(f2, at = 1)[names(cohort(f1))], cohort(f1))
  expect_equal(nrow(cohort(f2, at = 2)), f2$steps[[2]]$n_pass)
  expect_lt(nrow(cohort(f2, at = 2)), nrow(cohort(f2, at = 1)))
  expect_identical(cohort(f2, at = "Older"), cohort(f2))
})
