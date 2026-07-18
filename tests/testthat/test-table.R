# ===========================================================================
# Tests for as_attrition_tibble() and as_attrition_table()
# ===========================================================================
#
# Shared fixtures (make_flow_categorised(), make_flow_flat(),
# make_flow_no_exclusions()) live in helper-fixtures.R.

# ---------------------------------------------------------------------------
# as_attrition_tibble -- input validation
# ---------------------------------------------------------------------------

test_that("as_attrition_tibble() rejects non-cf_flow input", {
  expect_error(as_attrition_tibble(list()), "`flow` must be a `cf_flow` object")
  expect_error(as_attrition_tibble(NULL),   "`flow` must be a `cf_flow` object")
})


# ---------------------------------------------------------------------------
# as_attrition_tibble -- structure
# ---------------------------------------------------------------------------

test_that("as_attrition_tibble() returns a tibble with required columns", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow)

  expect_s3_class(out, "tbl_df")
  expect_named(out, c("row_type", "label", "indent_level", "n",
                      "n_removed", "pct_removed", "branch"))
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
# as_attrition_tibble, show_categories TRUE (default)
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

test_that("categorised exclude steps appear at indent_level 2 with row_type 'step'", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow, show_categories = TRUE)

  # 'Withdrew consent' is now categorised under 'Consent' -- should be step at level 2
  withdrew_row <- out[out$label == "Withdrew consent", ]
  expect_equal(nrow(withdrew_row), 1L)
  expect_equal(withdrew_row$row_type, "step")
  expect_equal(withdrew_row$indent_level, 2L)
})

test_that("category row n_removed is sum of constituent step n_fail", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow, show_categories = TRUE)

  # Valid age category: two steps
  age_cat   <- out[out$row_type == "category" & out$label == "Valid age", ]
  age_steps <- out[out$row_type == "step" & out$indent_level == 2L &
                     out$label %in% c("Age recorded", "Adults only"), ]

  expect_equal(age_cat$n_removed, sum(age_steps$n_removed))
})

test_that("category pct_removed is relative to entering N of first step", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow, show_categories = TRUE)

  age_cat <- out[out$row_type == "category" & out$label == "Valid age", ]
  expected_pct <- round(100 * age_cat$n_removed / age_cat$n, 1)

  expect_equal(age_cat$pct_removed, expected_pct)
})

test_that("grouped step sub-rows' pct_removed is relative to the category's entering N", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow, show_categories = TRUE)

  age_cat <- out[out$row_type == "category" & out$label == "Valid age", ]
  age_steps <- out[out$row_type == "step" & out$indent_level == 2L &
                     out$label %in% c("Age recorded", "Adults only"), ]

  expected_pct <- round(100 * age_steps$n_removed / age_cat$n, 1)
  expect_equal(age_steps$pct_removed, expected_pct)

  # Sanity check: the second step's own entering N is smaller than the
  # category's entering N (since it enters after the first step has
  # already removed some participants), so its pct_removed differs from
  # what it would be if computed relative to its own entering N.
  adults_step <- age_steps[age_steps$label == "Adults only", ]
  own_n_pct <- round(100 * adults_step$n_removed / adults_step$n, 1)
  if (adults_step$n != age_cat$n) {
    expect_false(isTRUE(all.equal(adults_step$pct_removed, own_n_pct)))
  }
})


# ---------------------------------------------------------------------------
# as_attrition_tibble, show_categories FALSE
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
# as_attrition_tibble -- label customisation
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
# as_attrition_tibble -- numerical consistency
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
# as_attrition_tibble -- edge cases
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
# as_attrition_table -- basic smoke tests (no rendering, just class checks)
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

test_that("as_attrition_table() with gt returns a gt_tbl", {
  skip_if_not_installed("gt")

  flow <- make_flow_categorised()
  gt_tbl <- as_attrition_table(flow, backend = "gt")
  expect_s3_class(gt_tbl, "gt_tbl")
})

test_that("as_attrition_tibble() respects digits argument", {
  flow <- make_flow_flat()
  out0 <- as_attrition_tibble(flow, digits = 0L)
  out2 <- as_attrition_tibble(flow, digits = 2L)

  step_rows0 <- out0[out0$row_type == "step" & !is.na(out0$pct_removed), ]
  step_rows2 <- out2[out2$row_type == "step" & !is.na(out2$pct_removed), ]

  # digits = 0 values are integers (no decimal places)
  expect_true(all(step_rows0$pct_removed == round(step_rows0$pct_removed, 0)))
  # digits = 2 values match round(..., 2)
  expect_true(all(step_rows2$pct_removed == round(step_rows2$pct_removed, 2)))
})

test_that("as_attrition_table() rejects non-cf_flow input", {
  expect_error(as_attrition_table(list()), "`flow` must be a `cf_flow` object")
})

# ---------------------------------------------------------------------------
# as_attrition_tibble -- singleton category handling
# ---------------------------------------------------------------------------

test_that("singleton category has NA n_removed and pct_removed on category row", {
  # Create a flow with a category that has only one step
  dat <- suppressWarnings(mock_cohortflow(n_participants = 100, seed = 1))
  crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age recorded", category = "Valid age") |>
    include(~ eligible_screen, label = "Passed screening", category = "Screening")
  flow <- apply_criteria(dat, crit)
  out  <- as_attrition_tibble(flow)

  # Both categories have only one step each
  cat_rows <- out[out$row_type == "category", ]
  expect_true(all(is.na(cat_rows$n_removed)))
  expect_true(all(is.na(cat_rows$pct_removed)))

  # But the child step rows should have the actual values
  step_rows <- out[out$row_type == "step" & out$indent_level == 2L, ]
  expect_gt(nrow(step_rows), 0L)
  expect_false(any(is.na(step_rows$n_removed)))
})

test_that("multi-step category has n_removed and pct_removed on category row", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow)

  # "Valid age" category has two steps
  age_cat <- out[out$row_type == "category" & out$label == "Valid age", ]
  expect_equal(nrow(age_cat), 1L)
  expect_false(is.na(age_cat$n_removed))
  expect_false(is.na(age_cat$pct_removed))
})

# ---------------------------------------------------------------------------
# as_attrition_tibble -- branching
# ---------------------------------------------------------------------------

test_that("as_attrition_tibble() accepts branch_by parameter", {
  flow <- make_flow_parallel_rct()
  out  <- as_attrition_tibble(flow, branch_by = "arm")

  expect_s3_class(out, "tbl_df")
  expect_true("branch" %in% names(out))
})

test_that("branch_by creates one branch row per unique value", {
  flow <- make_flow_parallel_rct()
  out  <- as_attrition_tibble(flow, branch_by = "arm")

  branch_rows <- out[out$row_type == "branch", ]
  cohort_data <- cohort(flow)
  expected_branches <- length(unique(cohort_data$arm))

  expect_equal(nrow(branch_rows), expected_branches)
})

test_that("branch counts sum to final cohort size", {
  flow <- make_flow_parallel_rct()
  out  <- as_attrition_tibble(flow, branch_by = "arm")

  branch_rows <- out[out$row_type == "branch", ]
  final_row   <- out[out$row_type == "final", ]

  expect_equal(sum(branch_rows$n), final_row$n)
})

test_that("branch rows have NA n_removed and pct_removed", {
  flow <- make_flow_parallel_rct()
  out  <- as_attrition_tibble(flow, branch_by = "arm")

  branch_rows <- out[out$row_type == "branch", ]
  expect_true(all(is.na(branch_rows$n_removed)))
  expect_true(all(is.na(branch_rows$pct_removed)))
})

test_that("branch rows have indent_level 1", {
  flow <- make_flow_parallel_rct()
  out  <- as_attrition_tibble(flow, branch_by = "arm")

  branch_rows <- out[out$row_type == "branch", ]
  expect_true(all(branch_rows$indent_level == 1L))
})

test_that("branch_by errors when column not found", {
  flow <- make_flow_categorised()
  expect_error(
    as_attrition_tibble(flow, branch_by = "nonexistent"),
    "not found"
  )
})

test_that("count_by requires branch_by", {
  flow <- make_flow_crossover()
  expect_error(
    as_attrition_tibble(flow, count_by = "participant_id"),
    "requires.*branch_by"
  )
})

test_that("count_by uses distinct counts", {
  flow <- make_flow_crossover()
  out  <- as_attrition_tibble(
    flow,
    branch_by = "sequence",
    count_by = "participant_id"
  )

  branch_rows <- out[out$row_type == "branch", ]
  cohort_data <- cohort(flow)

  for (i in seq_len(nrow(branch_rows))) {
    seq_val <- branch_rows$branch[i]
    expected_n <- dplyr::n_distinct(
      cohort_data$participant_id[cohort_data$sequence == seq_val]
    )
    expect_equal(branch_rows$n[i], expected_n)
  }
})

test_that("count_by errors when column not found", {
  flow <- make_flow_parallel_rct()
  expect_error(
    as_attrition_tibble(flow, branch_by = "arm", count_by = "nonexistent"),
    "not found"
  )
})

test_that("linear table has no branch rows when branch_by is NULL", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow)

  expect_equal(sum(out$row_type == "branch"), 0L)
})

test_that("as_attrition_table() accepts branch_by parameter", {
  skip_if_not_installed("flextable")
  skip_if_not_installed("officer")

  flow <- make_flow_parallel_rct()
  ft   <- as_attrition_table(flow, backend = "flextable", branch_by = "arm")
  expect_s3_class(ft, "flextable")
})

test_that("as_attrition_table() with gt accepts branch_by", {
  skip_if_not_installed("gt")

  flow <- make_flow_parallel_rct()
  gt_tbl <- as_attrition_table(flow, backend = "gt", branch_by = "arm")
  expect_s3_class(gt_tbl, "gt_tbl")
})

test_that("as_attrition_table() with huxtable accepts branch_by", {
  skip_if_not_installed("huxtable")

  flow <- make_flow_parallel_rct()
  ht   <- as_attrition_table(flow, backend = "huxtable", branch_by = "arm")
  expect_s3_class(ht, "huxtable")
})
