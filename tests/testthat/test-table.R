# ===========================================================================
# Tests for as_attrition_tibble() and as_attrition_table()
# ===========================================================================

# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------

make_flow_categorised <- function() {
  dat <- mock_cohortflow(n_participants = 200, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age),     label = "Age recorded",    category = "Age") |>
    include(~ age >= 18,       label = "Adults only",     category = "Age") |>
    include(~ eligible_screen, label = "Passed screening", category = "Screening") |>
    exclude(~ withdrew,        label = "Withdrew consent")
  apply_criteria(dat, crit)
}

make_flow_flat <- function() {
  dat <- mock_cohortflow(n_participants = 200, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age),     label = "Age recorded") |>
    include(~ age >= 18,       label = "Adults only") |>
    exclude(~ withdrew,        label = "Withdrew consent")
  apply_criteria(dat, crit)
}

make_flow_no_exclusions <- function() {
  dat <- mock_cohortflow(n_participants = 100, seed = 42)
  # A criterion that keeps everyone
  crit <- cf_criteria() |>
    include(~ !is.na(participant_id), label = "Has ID")
  apply_criteria(dat, crit)
}

# ---------------------------------------------------------------------------
# as_attrition_tibble — input validation
# ---------------------------------------------------------------------------

test_that("as_attrition_tibble() rejects non-cf_flow input", {
  expect_error(as_attrition_tibble(list()), "`flow` must be a `cf_flow` object")
  expect_error(as_attrition_tibble(NULL),   "`flow` must be a `cf_flow` object")
})

# ---------------------------------------------------------------------------
# as_attrition_tibble — structure
# ---------------------------------------------------------------------------

test_that("as_attrition_tibble() returns a tibble with required columns", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow)

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("row_type", "label", "indent_level", "n",
                       "n_removed", "pct_removed"))
})

test_that("first row is the header, last row is the final cohort", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow)

  expect_equal(out$row_type[[1]], "header")
  expect_equal(out$row_type[[nrow(out)]], "final")
  expect_equal(out$indent_level[[1]], 0L)
  expect_equal(out$indent_level[[nrow(out)]], 0L)
})

test_that("header row has NA n_removed and NA pct_removed", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow)

  expect_true(is.na(out$n_removed[[1]]))
  expect_true(is.na(out$pct_removed[[1]]))
})

test_that("header n equals nrow(flow$data)", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow)

  expect_equal(out$n[[1]], nrow(flow$data))
})

test_that("final row n equals cohort size", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow)
  n_final <- nrow(cohort(flow))

  expect_equal(out$n[[nrow(out)]], n_final)
})

test_that("final row pct_removed is retention percentage", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow)
  expected_pct <- round(100 * nrow(cohort(flow)) / nrow(flow$data), 1)

  expect_equal(out$pct_removed[[nrow(out)]], expected_pct)
})

# ---------------------------------------------------------------------------
# as_attrition_tibble — show_categories = TRUE (default)
# ---------------------------------------------------------------------------

test_that("show_categories=TRUE produces category rows with indent_level 1", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow, show_categories = TRUE)

  cat_rows <- out[out$row_type == "category", ]
  expect_gt(nrow(cat_rows), 0L)
  expect_true(all(cat_rows$indent_level == 1L))
})

test_that("step sub-rows under categories have indent_level 2", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow, show_categories = TRUE)

  sub_rows <- out[out$row_type == "step" & out$indent_level == 2L, ]
  expect_gt(nrow(sub_rows), 0L)
})

test_that("uncategorised steps appear at indent_level 1 with row_type 'step'", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow, show_categories = TRUE)

  # 'Withdrew consent' has no category — should be step at level 1
  withdrew_row <- out[out$label == "Withdrew consent", ]
  expect_equal(nrow(withdrew_row), 1L)
  expect_equal(withdrew_row$row_type, "step")
  expect_equal(withdrew_row$indent_level, 1L)
})

test_that("category row n_removed is sum of constituent step n_fail", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow, show_categories = TRUE)

  # Age category: two steps
  age_cat   <- out[out$row_type == "category" & out$label == "Age", ]
  age_steps <- out[out$row_type == "step" & out$indent_level == 2L &
                     out$label %in% c("Age recorded", "Adults only"), ]

  expect_equal(age_cat$n_removed, sum(age_steps$n_removed))
})

test_that("category pct_removed is relative to entering N of first step", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow, show_categories = TRUE)

  age_cat <- out[out$row_type == "category" & out$label == "Age", ]
  expected_pct <- round(100 * age_cat$n_removed / age_cat$n, 1)

  expect_equal(age_cat$pct_removed, expected_pct)
})

# ---------------------------------------------------------------------------
# as_attrition_tibble — show_categories = FALSE
# ---------------------------------------------------------------------------

test_that("show_categories=FALSE produces one step row per criterion", {
  flow    <- make_flow_flat()
  out     <- as_attrition_tibble(flow, show_categories = FALSE)
  n_steps <- length(flow$steps)

  step_rows <- out[out$row_type == "step", ]
  expect_equal(nrow(step_rows), n_steps)
})

test_that("show_categories=FALSE produces no category rows", {
  flow <- make_flow_flat()
  out  <- as_attrition_tibble(flow, show_categories = FALSE)

  expect_equal(sum(out$row_type == "category"), 0L)
})

test_that("show_categories=FALSE: all step rows at indent_level 1", {
  flow <- make_flow_flat()
  out  <- as_attrition_tibble(flow, show_categories = FALSE)

  step_rows <- out[out$row_type == "step", ]
  expect_true(all(step_rows$indent_level == 1L))
})

# ---------------------------------------------------------------------------
# as_attrition_tibble — label customisation
# ---------------------------------------------------------------------------

test_that("custom assessed_label appears in header row", {
  flow <- make_flow_flat()
  out  <- as_attrition_tibble(flow, assessed_label = "Screened")

  expect_equal(out$label[[1]], "Screened")
})

test_that("custom final_label appears in final row", {
  flow <- make_flow_flat()
  out  <- as_attrition_tibble(flow, final_label = "Enrolled")

  expect_equal(out$label[[nrow(out)]], "Enrolled")
})

# ---------------------------------------------------------------------------
# as_attrition_tibble — numerical consistency
# ---------------------------------------------------------------------------

test_that("step pct_removed = n_removed / n * 100 (rounded to 1 dp)", {
  flow <- make_flow_flat()
  out  <- as_attrition_tibble(flow, show_categories = FALSE)

  step_rows <- out[out$row_type == "step" & !is.na(out$n_removed), ]
  expected  <- round(100 * step_rows$n_removed / step_rows$n, 1)
  expect_equal(step_rows$pct_removed, expected)
})

test_that("total n_removed across steps equals n_start - n_end", {
  flow <- make_flow_flat()
  out  <- as_attrition_tibble(flow, show_categories = FALSE)

  step_removed <- sum(out$n_removed[out$row_type == "step"], na.rm = TRUE)
  n_start      <- out$n[[1]]
  n_end        <- out$n[[nrow(out)]]

  expect_equal(step_removed, n_start - n_end)
})

# ---------------------------------------------------------------------------
# as_attrition_tibble — edge cases
# ---------------------------------------------------------------------------

test_that("flow with no exclusions produces correct table", {
  flow <- make_flow_no_exclusions()
  out  <- as_attrition_tibble(flow)

  n_start <- out$n[[1]]
  n_end   <- out$n[[nrow(out)]]
  expect_equal(n_start, n_end)
  expect_equal(out$pct_removed[[nrow(out)]], 100.0)
})

# ---------------------------------------------------------------------------
# as_attrition_table — basic smoke tests (no rendering, just class checks)
# ---------------------------------------------------------------------------

test_that("as_attrition_table() with flextable returns a flextable", {
  skip_if_not_installed("flextable")
  skip_if_not_installed("officer")

  flow <- make_flow_categorised()
  ft   <- as_attrition_table(flow, backend = "flextable")
  expect_s3_class(ft, "flextable")
})

test_that("as_attrition_table() with huxtable returns a huxtable", {
  skip_if_not_installed("huxtable")

  flow <- make_flow_categorised()
  ht   <- as_attrition_table(flow, backend = "huxtable")
  expect_s3_class(ht, "huxtable")
})

test_that("as_attrition_table() errors informatively when backend package missing", {
  flow <- make_flow_categorised()

  # Mock the internal helper in the cohortflow namespace so we don't need the
  # packages installed; this is cleaner than patching base::requireNamespace.
  local_mocked_bindings(
    .has_namespace = function(pkg, ...) FALSE,
    .package = "cohortflow"
  )

  expect_error(
    as_attrition_table(flow, backend = "flextable"),
    "flextable"
  )
  expect_error(
    as_attrition_table(flow, backend = "huxtable"),
    "huxtable"
  )
})
