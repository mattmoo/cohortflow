# `reason`, diagram box text, and messages for old usage (dev/todo.md item 11)

n_of <- function(lbl) as.integer(gsub(",", "", sub(".*\\(n=([0-9,]+).*", "\\1", lbl)))
consort_layout <- function(d) attr(d, "consort_layout")

flat_flow <- function(reason_age = NULL) {
  dat <- mock_parallel_rct(n_participants = 200, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age) & age >= 18, label = "Aged 18 or over", reason = reason_age) |>
    exclude(~ withdrew, label = "Withdrew consent")
  apply_criteria(dat, crit, id = "participant_id")
}

# ---------------------------------------------------------------------------
# The `reason` field

test_that("builders store `reason`, and step records copy it", {
  crit <- cf_criteria() |>
    include(~ age >= 18, "Aged 18 or over", reason = "Under 18") |>
    exclude(~ withdrew, "Withdrew consent") |>
    group_include("cluster_id", ~ n() >= 5, "Cluster size >= 5", reason = "Small cluster") |>
    group_exclude("cluster_id", ~ all(withdrew), "Cluster withdrew", reason = "Whole cluster withdrew") |>
    select_within("participant_id", ~ seq_along(age) == 1L, "First record", reason = "Repeat record")
  reasons <- lapply(crit$steps, `[[`, "reason")
  expect_equal(reasons, list("Under 18", NULL, "Small cluster", "Whole cluster withdrew", "Repeat record"))

  flow <- apply_criteria(mock_cluster_rct(n_participants = 100, seed = 1), crit,
                         id = "participant_id")
  expect_equal(flow$steps[[1]]$reason, "Under 18")
  expect_null(flow$steps[[2]]$reason)
})

test_that("`reason` is validated", {
  expect_error(cf_criterion(~ x, "x", "include", reason = c("a", "b")),
               "`reason` must be a single non-empty string")
  expect_error(cf_criterion(~ x, "x", "include", reason = ""),
               "`reason` must be a single non-empty string")
  expect_error(cf_criterion(~ x, "Step x", "include", reason = 1),
               "Criterion \"Step x\" was given <numeric>", fixed = TRUE)
  expect_error(cf_criterion(NULL, "R", "randomise", by = "id", arms = "arm", reason = "x"),
               "removes no rows")
})

test_that("print() and format() show `reason` only when set", {
  with_reason <- cf_criteria() |> include(~ age >= 18, "Aged 18 or over", reason = "Under 18")
  without     <- cf_criteria() |> include(~ age >= 18, "Aged 18 or over")
  expect_match(paste(capture.output(print(with_reason)), collapse = "\n"), "removes: Under 18")
  expect_no_match(paste(capture.output(print(without)), collapse = "\n"), "removes")
  expect_match(format(with_reason$steps[[1]]), "[removes: Under 18]", fixed = TRUE)
  expect_no_match(format(without$steps[[1]]), "removes")
})

test_that("`reason` round-trips through YAML and is omitted when unset", {
  crit <- cf_criteria() |>
    include(~ age >= 18, "Aged 18 or over", reason = "Under 18") |>
    exclude(~ withdrew, "Withdrew consent")
  yml <- export_criteria(crit)
  expect_equal(lengths(regmatches(yml, gregexpr("reason:", yml))), 1L)
  back <- import_criteria(text = yml)
  expect_equal(back$steps[[1]]$reason, "Under 18")
  expect_null(back$steps[[2]]$reason)
})

# ---------------------------------------------------------------------------
# Diagram box text

test_that("an exclude() step's label sits beside the number removed", {
  flow <- flat_flow()
  lay  <- consort_layout(as_consort_diagram(flow))
  n_withdrew <- flow$steps[[2]]$n_fail
  expect_true(any(lay$excl_boxes$label == sprintf(
    "Withdrew consent (n=%d, %.1f%%)", n_withdrew, 100 * n_withdrew / flow$steps[[2]]$n_in
  )))
  expect_false(any(grepl("Withdrew consent", lay$main_boxes$label)))
  remaining <- lay$main_boxes$label[startsWith(lay$main_boxes$label, "Remaining\n")]
  expect_length(remaining, 1L)
  expect_equal(n_of(remaining), flow$steps[[2]]$n_pass)
})

test_that("remaining_label renames the box below an exclusion step", {
  lay <- consort_layout(as_consort_diagram(flat_flow(), remaining_label = "Still consented"))
  expect_true(any(startsWith(lay$main_boxes$label, "Still consented\n(n=")))
  expect_error(as_consort_diagram(flat_flow(), remaining_label = ""),
               "`remaining_label` must be a single non-empty string")
})

test_that("an include() step keeps its label on the main box; its exclusion box uses `reason`", {
  flow <- flat_flow()
  lay  <- consort_layout(as_consort_diagram(flow))
  kept <- lay$main_boxes$label[startsWith(lay$main_boxes$label, "Aged 18 or over\n")]
  expect_equal(n_of(kept), flow$steps[[1]]$n_pass)
  expect_true(any(startsWith(lay$excl_boxes$label, "Excluded (n=")))

  lay2 <- consort_layout(as_consort_diagram(flat_flow(reason_age = "Under 18 or age missing")))
  expect_true(any(startsWith(lay2$excl_boxes$label, "Under 18 or age missing (n=")))
  expect_false(any(startsWith(lay2$excl_boxes$label, "Excluded")))
})

test_that("category bullets use `reason`, and warn for inclusion steps without one", {
  withr::local_options(rlib_warning_verbosity = "verbose", cohortflow.warn_missing_reason = TRUE)
  dat <- mock_parallel_rct(n_participants = 200, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age), "Age recorded", category = "Valid age", reason = "Age missing") |>
    include(~ age >= 18, "Aged 18 or over", category = "Valid age")
  flow <- apply_criteria(dat, crit, id = "participant_id")

  w <- expect_warning(d <- as_consort_diagram(flow), class = "cohortflow_missing_reason")
  expect_match(conditionMessage(w), "\"Aged 18 or over\"", fixed = TRUE)
  expect_match(conditionMessage(w), "reason = \"Under 18\"", fixed = TRUE)
  excl <- consort_layout(d)$excl_boxes$label
  expect_match(excl, "• Age missing (n=", fixed = TRUE)
  expect_match(excl, "• Aged 18 or over (n=", fixed = TRUE)

  crit_ok <- cf_criteria() |>
    include(~ !is.na(age), "Age recorded", category = "Valid age", reason = "Age missing") |>
    include(~ age >= 18, "Aged 18 or over", category = "Valid age", reason = "Under 18") |>
    exclude(~ withdrew, "Withdrew consent", category = "Valid age")
  expect_no_warning(as_consort_diagram(apply_criteria(dat, crit_ok, id = "participant_id")))
})

test_that("flows built before `reason` existed still draw", {
  flow <- flat_flow()
  for (i in seq_along(flow$steps)) flow$steps[[i]]$reason <- NULL
  lay <- consort_layout(as_consort_diagram(flow))
  expect_true(any(startsWith(lay$excl_boxes$label, "Withdrew consent (n=")))
})

# ---------------------------------------------------------------------------
# Step selectors: numbers given as text (11d)

test_that("a numeric-looking string that matches no step gets a hint", {
  flow <- flat_flow()
  err <- expect_error(as_characteristics_tibble(flow, vars = "age", steps = c(0, "Aged 18 or over")))
  msg <- conditionMessage(err)
  expect_match(msg, "matches no step label or category", fixed = TRUE)
  expect_match(msg, "Did you mean step 0?", fixed = TRUE)
  expect_match(msg, "list(0, ", fixed = TRUE)

  expect_error(cohort(flow, at = "1"), "Did you mean step 1?", fixed = TRUE)
  expect_error(cohort(flow, label = "2"), "Did you mean step 2?", fixed = TRUE)
  # no hint for ordinary strings or numbers beyond the last step
  expect_no_match(conditionMessage(expect_error(cohort(flow, at = "Nope"))), "Did you mean")
  expect_no_match(conditionMessage(expect_error(cohort(flow, at = "9"))), "Did you mean")
})

test_that("a step labelled with a number still resolves by label", {
  dat  <- mock_parallel_rct(n_participants = 50, seed = 1)
  crit <- cf_criteria() |> include(~ age >= 18, "Adults") |> exclude(~ withdrew, "1")
  flow <- apply_criteria(dat, crit, id = "participant_id")
  expect_equal(nrow(cohort(flow, at = "1")), flow$steps[[2]]$n_pass)
})

# ---------------------------------------------------------------------------
# Old usage

test_that("legacy `fn_args` YAML imports with a warning saying how to upgrade", {
  yml <- "
cohortflow_criteria:
  version: 1
  steps:
    - label: Adults
      type: include
      kind: function
      expr: d$age >= 18
      fn_args: d
"
  w <- expect_warning(crit <- import_criteria(text = yml), class = "cohortflow_legacy_yaml")
  msg <- conditionMessage(w)
  expect_match(msg, "Step 1 (\"Adults\") uses the old `fn_args`", fixed = TRUE)
  expect_match(msg, "default argument values were lost", fixed = TRUE)
  expect_match(msg, "export_criteria(", fixed = TRUE)
  expect_true(is.function(crit$steps[[1]]$predicate))
})

test_that("a criteria file from a newer schema version is refused", {
  yml <- "
cohortflow_criteria:
  version: 2
  steps: []
"
  expect_error(import_criteria(text = yml), "schema version 2.*Update the package")
})

test_that("mock_cohortflow() names the replacement generators", {
  withr::local_options(rlib_warning_verbosity = "verbose")
  w <- expect_warning(mock_cohortflow(n_participants = 20, seed = 1),
                      class = "cohortflow_deprecated")
  msg <- conditionMessage(w)
  for (fn in c("mock_parallel_rct()", "mock_cluster_rct()", "mock_stepped_wedge()",
               "mock_crossover()")) {
    expect_match(msg, fn, fixed = TRUE)
  }
})
