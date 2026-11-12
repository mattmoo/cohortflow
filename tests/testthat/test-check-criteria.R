# ---------------------------------------------------------------------------
# check_criteria() as a standalone function
# ---------------------------------------------------------------------------

test_that("check_criteria() passes silently on valid criteria", {
  dat  <- mock_parallel_rct(n_participants = 30, seed = 1)
  crit <- cf_criteria() |>
    include(~ age >= 18, label = "Adults only") |>
    include(~ !is.na(consent_date), label = "Consent recorded") |>
    randomise(by = "participant_id", arms = "arm")
  expect_invisible(res <- check_criteria(crit, dat))
  expect_null(res)
  expect_silent(check_criteria(crit, dat))
})

test_that("a missing variable names the step number, label and column", {
  d    <- data.frame(age = c(20, 30))
  crit <- cf_criteria() |>
    include(~ age >= 18, label = "Adults only") |>
    include(~ !is.na(consent_date), label = "Consent recorded")
  expect_error(
    check_criteria(crit, d),
    'Criterion 2 "Consent recorded" refers to column\\(s\\) not in data: consent_date\\.',
    class = "rlang_error"
  )
})

test_that("all offending steps and all missing variables are reported", {
  d    <- data.frame(age = c(20, 30))
  crit <- cf_criteria() |>
    include(~ a > 1 & b > 2, label = "Step one") |>
    include(~ age >= 18, label = "Fine") |>
    exclude(~ lost, label = "Step three")
  err <- expect_error(check_criteria(crit, d), class = "rlang_error")
  msg <- conditionMessage(err)
  expect_match(msg, 'Criterion 1 "Step one" refers to column\\(s\\) not in data: a, b\\.')
  expect_match(msg, 'Criterion 3 "Step three" refers to column\\(s\\) not in data: lost\\.')
  expect_no_match(msg, "Criterion 2")
})

test_that("variables bound in the formula environment are not flagged", {
  d       <- data.frame(age = c(20, 30))
  min_age <- 18
  cfg     <- list(max_age = 65)
  crit <- cf_criteria() |>
    include(~ age >= min_age, label = "Env scalar") |>
    include(~ age <= cfg$max_age, label = "Env list field") |>
    include(~ dplyr::between(age, min_age, cfg$max_age), label = "Namespaced call") |>
    include(~ age %in% vapply(c(20, 30), function(a) a, numeric(1)), label = "Lambda")
  expect_silent(check_criteria(crit, d))
})

test_that("an unbound env-style reference is still flagged", {
  d    <- data.frame(age = c(20, 30))
  crit <- cf_criteria() |> include(~ age <= no_such_cfg$max_age, label = "Bad cfg")
  expect_error(check_criteria(crit, d), "not in data: no_such_cfg\\.")
})

test_that(".data pronoun references are checked as columns", {
  d <- data.frame(age = c(20, 30))
  expect_silent(check_criteria(cf_criteria() |> include(~ .data$age > 1, label = "ok"), d))
  expect_error(
    check_criteria(cf_criteria() |> include(~ .data$weight > 1, label = "Weight"), d),
    "not in data: weight\\."
  )
  expect_error(
    check_criteria(cf_criteria() |> include(~ .data[["weight"]] > 1, label = "Weight"), d),
    "not in data: weight\\."
  )
})

test_that("dplyr helpers in group predicates are not flagged", {
  d <- data.frame(cid = c(1, 1, 2), pid = c(1, 2, 3))
  crit <- cf_criteria() |>
    group_include(by = "cid", ~ n() >= 2, label = "Size") |>
    group_exclude(by = "cid", ~ n_distinct(pid) > 5, label = "Distinct")
  expect_silent(check_criteria(crit, d))
})

test_that("missing by and arms columns are flagged", {
  d <- data.frame(pid = 1:3, age = c(20, 30, 40))
  crit <- cf_criteria() |>
    group_include(by = "cluster_id", ~ n() >= 2, label = "Cluster size") |>
    randomise(by = "pid", arms = "arm", label = "Randomised")
  err <- expect_error(check_criteria(crit, d), class = "rlang_error")
  msg <- conditionMessage(err)
  expect_match(msg, 'Criterion 1 "Cluster size" refers to column\\(s\\) not in data: cluster_id\\.')
  expect_match(msg, 'Criterion 2 "Randomised" refers to column\\(s\\) not in data: arm\\.')
})

test_that("function predicates are skipped, with a note when another step fails", {
  d <- data.frame(age = c(20, 30))
  fn_only <- cf_criteria() |> include(function(x) x$nope > 1, label = "Function step")
  expect_silent(check_criteria(fn_only, d))

  crit <- fn_only |> include(~ missing_col, label = "Bad")
  err <- expect_error(check_criteria(crit, d), class = "rlang_error")
  expect_match(conditionMessage(err), "Function predicates \\(criterion 1\\) cannot be checked")
})

test_that("check_criteria() validates its arguments", {
  d <- data.frame(age = 1)
  expect_error(check_criteria(list(), d), "cf_criteria", class = "rlang_error")
  expect_error(check_criteria(cf_criteria(), list(age = 1)), "data frame", class = "rlang_error")
})

test_that("empty criteria pass", {
  expect_silent(check_criteria(cf_criteria(), data.frame(age = 1)))
})
