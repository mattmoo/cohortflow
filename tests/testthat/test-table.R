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
# as_attrition_tibble -- branching (per-branch columns on the final row)
# ---------------------------------------------------------------------------

test_that("as_attrition_tibble() accepts branch_by parameter", {
  flow <- make_flow_parallel_rct()
  out  <- as_attrition_tibble(flow, branch_by = "arm")

  expect_s3_class(out, "tbl_df")
  cohort_data <- cohort(flow)
  branch_values <- as.character(sort(unique(cohort_data$arm)))
  expect_true(all(branch_values %in% names(out)))
})

test_that("branch_by creates one column per unique value", {
  flow <- make_flow_parallel_rct()
  out  <- as_attrition_tibble(flow, branch_by = "arm")

  cohort_data <- cohort(flow)
  branch_values <- as.character(sort(unique(cohort_data$arm)))

  expect_true(all(branch_values %in% names(out)))
  expect_equal(length(intersect(branch_values, names(out))), length(branch_values))
})

test_that("branch counts sum to final cohort size", {
  flow <- make_flow_parallel_rct()
  out  <- as_attrition_tibble(flow, branch_by = "arm")

  cohort_data <- cohort(flow)
  branch_values <- as.character(sort(unique(cohort_data$arm)))
  final_row <- out[out$row_type == "final", ]

  branch_total <- sum(vapply(branch_values, function(b) final_row[[b]], numeric(1L)))
  expect_equal(branch_total, final_row$n)
})

test_that("branch columns are NA except on the final row", {
  flow <- make_flow_parallel_rct()
  out  <- as_attrition_tibble(flow, branch_by = "arm")

  cohort_data <- cohort(flow)
  branch_values <- as.character(sort(unique(cohort_data$arm)))
  non_final <- out[out$row_type != "final", ]

  for (b in branch_values) {
    expect_true(all(is.na(non_final[[b]])))
  }
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

  cohort_data <- cohort(flow)
  branch_values <- as.character(sort(unique(cohort_data$sequence)))
  final_row <- out[out$row_type == "final", ]

  for (seq_val in branch_values) {
    expected_n <- dplyr::n_distinct(
      cohort_data$participant_id[cohort_data$sequence == seq_val]
    )
    expect_equal(final_row[[seq_val]], expected_n)
  }
})

test_that("count_by errors when column not found", {
  flow <- make_flow_parallel_rct()
  expect_error(
    as_attrition_tibble(flow, branch_by = "arm", count_by = "nonexistent"),
    "not found"
  )
})

test_that("linear table has no branch columns when branch_by is NULL", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow)

  standard_cols <- c("row_type", "label", "indent_level", "n",
                     "n_removed", "pct_removed", "branch")
  expect_equal(setdiff(names(out), standard_cols), character(0L))
})

# ---------------------------------------------------------------------------
# as_attrition_tibble -- randomise() auto-detection / post_randomisation
# ---------------------------------------------------------------------------

test_that("as_attrition_tibble() auto-detects branch_by from a randomise() step", {
  flow <- make_flow_randomise()
  out  <- as_attrition_tibble(flow)

  cohort_data <- cohort(flow)
  arm_values  <- as.character(sort(unique(cohort_data$arm)))
  expect_true(all(arm_values %in% names(out)))

  final_row <- out[out$row_type == "final", ]
  for (arm_val in arm_values) {
    expected_n <- sum(cohort_data$arm == arm_val)
    expect_equal(final_row[[arm_val]], expected_n)
  }
})

test_that("explicit branch_by overrides the randomise() step default", {
  flow <- make_flow_randomise()
  out  <- as_attrition_tibble(flow, branch_by = "site_id")

  cohort_data <- cohort(flow)
  site_values <- as.character(sort(unique(cohort_data$site_id)))
  expect_true(all(site_values %in% names(out)))
  expect_false(any(as.character(sort(unique(cohort_data$arm))) %in% names(out)))
})

test_that("as_attrition_tibble() adds post_randomisation column when a randomise() step exists", {
  flow <- make_flow_randomise()
  out  <- as_attrition_tibble(flow, show_categories = FALSE)

  expect_true("post_randomisation" %in% names(out))
  expect_false(out$post_randomisation[out$label == "Assessed for eligibility"])
  expect_false(out$post_randomisation[out$label == "Age recorded"])
  expect_true(out$post_randomisation[out$label == "Randomised"])
  expect_true(out$post_randomisation[out$label == "Withdrew after allocation"])
  expect_true(out$post_randomisation[out$row_type == "final"])
})

test_that("as_attrition_tibble() omits post_randomisation when there is no randomise() step", {
  flow <- make_flow_categorised()
  out  <- as_attrition_tibble(flow)
  expect_false("post_randomisation" %in% names(out))
})

test_that("group_x/group_y never leak branch_by columns from a randomise() step", {
  flow <- make_flow_randomise()
  out  <- as_attrition_tibble(flow, group_x = "site_id")

  cohort_data <- cohort(flow)
  arm_values  <- as.character(sort(unique(cohort_data$arm)))
  expect_false(any(arm_values %in% names(out)))
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

# ---------------------------------------------------------------------------
# as_attrition_tibble -- grouping via group_x / group_y
# ---------------------------------------------------------------------------

test_that("group_x alone repeats the attrition block per group_x value", {
  flow <- make_flow_stepped_wedge()
  out  <- as_attrition_tibble(flow, group_x = "site_id")

  x_vals <- sort(unique(flow$data$site_id))
  expect_true(all(c("group_x", "group_y") %in% names(out)))
  expect_true(all(is.na(out$group_y)))
  expect_setequal(unique(out$group_x), x_vals)

  # Each group_x value should have a full attrition block (same nrow)
  block_sizes <- table(out$group_x)
  expect_true(length(unique(as.integer(block_sizes))) == 1L)
})

test_that("group_y alone repeats the attrition block per group_y value", {
  flow <- make_flow_stepped_wedge()
  out  <- as_attrition_tibble(flow, group_y = "period")

  y_vals <- sort(unique(flow$data$period))
  expect_true(all(is.na(out$group_x)))
  expect_setequal(unique(out$group_y), as.character(y_vals))
})

test_that("group_x and group_y together produce one block per combination", {
  flow <- make_flow_stepped_wedge()
  out  <- as_attrition_tibble(flow, group_x = "site_id", group_y = "period")

  x_vals <- unique(flow$data$site_id)
  y_vals <- unique(flow$data$period)
  n_combos <- length(x_vals) * length(y_vals)

  block_sizes <- table(paste(out$group_x, out$group_y))
  expect_equal(length(block_sizes), n_combos)
  expect_true(length(unique(as.integer(block_sizes))) == 1L)
})

test_that("grouped row skeleton (row_type/label/indent_level) is identical across blocks", {
  flow <- make_flow_stepped_wedge()
  out  <- as_attrition_tibble(flow, group_x = "site_id", group_y = "period")

  skeletons <- split(out[c("row_type", "label", "indent_level")],
                     paste(out$group_x, out$group_y))
  first <- skeletons[[1]]
  for (s in skeletons[-1]) {
    rownames(s) <- NULL
    rownames(first) <- NULL
    expect_equal(s, first)
  }
})

test_that("grouping errors when group_x column not found", {
  flow <- make_flow_stepped_wedge()
  expect_error(
    as_attrition_tibble(flow, group_x = "nonexistent"),
    "not found"
  )
})

test_that("grouping errors when group_y column not found", {
  flow <- make_flow_stepped_wedge()
  expect_error(
    as_attrition_tibble(flow, group_y = "nonexistent"),
    "not found"
  )
})

test_that("group_x/group_y cannot be combined with branch_by or count_by", {
  flow <- make_flow_stepped_wedge()
  expect_error(
    as_attrition_tibble(flow, group_x = "site_id", branch_by = "arm"),
    "cannot be combined"
  )
  expect_error(
    as_attrition_table(flow, group_x = "site_id", branch_by = "arm"),
    "cannot be combined"
  )
})

test_that("grouped numbers within each block are internally consistent", {
  flow <- make_flow_stepped_wedge()
  out  <- as_attrition_tibble(flow, group_x = "site_id")

  for (x in unique(out$group_x)) {
    block <- out[out$group_x == x, ]
    n_start <- block$n[block$row_type == "header"]
    n_end   <- block$n[block$row_type == "final"]
    step_removed <- sum(block$n_removed[block$row_type == "step"], na.rm = TRUE)
    expect_equal(step_removed, n_start - n_end)
  }
})

test_that("NA values in group_x form their own 'Missing' group, not folded into every other group", {
  flow <- make_flow_stepped_wedge()

  # Introduce NAs into the grouping column on the underlying data.
  na_idx <- seq_len(nrow(flow$data)) <= 20
  flow$data$site_id[na_idx] <- NA
  n_na <- sum(na_idx)

  expect_true(n_na > 0L)

  out    <- as_attrition_tibble(flow, group_x = "site_id")
  x_vals <- sort(unique(flow$data$site_id))

  # No group_x value should be NA -- the missing rows get an explicit label.
  expect_false(any(is.na(out$group_x)))
  expect_true("Missing" %in% unique(out$group_x))

  # Every real (non-missing) group's "assessed" (header) N must match the
  # true non-NA subset count -- i.e. must NOT include the NA rows.
  for (x in x_vals) {
    expected_n <- sum(flow$data$site_id == x, na.rm = TRUE)
    block <- out[out$group_x == as.character(x), ]
    header_n <- block$n[block$row_type == "header"]
    expect_equal(header_n, expected_n)
  }

  # The "Missing" group's header N must equal the count of NA rows exactly.
  missing_block <- out[out$group_x == "Missing", ]
  expect_equal(missing_block$n[missing_block$row_type == "header"], n_na)

  # Sanity check: total assessed across all group blocks (including
  # "Missing") sums to exactly the full dataset -- no double-counting and
  # no silent dropping.
  total_assessed <- sum(out$n[out$row_type == "header"])
  expect_equal(total_assessed, nrow(flow$data))
})

test_that("NA values in group_y form their own 'Missing' group, not folded into every other group", {
  flow <- make_flow_stepped_wedge()

  na_idx <- seq_len(nrow(flow$data)) <= 20
  flow$data$period[na_idx] <- NA
  n_na <- sum(na_idx)

  expect_true(n_na > 0L)

  out    <- as_attrition_tibble(flow, group_y = "period")
  y_vals <- sort(unique(flow$data$period))

  expect_false(any(is.na(out$group_y)))
  expect_true("Missing" %in% unique(out$group_y))

  for (y in y_vals) {
    expected_n <- sum(flow$data$period == y, na.rm = TRUE)
    block <- out[out$group_y == as.character(y), ]
    header_n <- block$n[block$row_type == "header"]
    expect_equal(header_n, expected_n)
  }

  missing_block <- out[out$group_y == "Missing", ]
  expect_equal(missing_block$n[missing_block$row_type == "header"], n_na)

  total_assessed <- sum(out$n[out$row_type == "header"])
  expect_equal(total_assessed, nrow(flow$data))
})

test_that("group_na_label customises the label used for the missing-value group", {
  flow <- make_flow_stepped_wedge()
  na_idx <- seq_len(nrow(flow$data)) <= 20
  flow$data$site_id[na_idx] <- NA

  out <- as_attrition_tibble(flow, group_x = "site_id", group_na_label = "Unknown site")
  expect_true("Unknown site" %in% unique(out$group_x))
  expect_false("Missing" %in% unique(out$group_x))
})

test_that("grouping with no NA values does not introduce a spurious 'Missing' group", {
  flow <- make_flow_stepped_wedge()
  out  <- as_attrition_tibble(flow, group_x = "site_id")
  expect_false("Missing" %in% unique(out$group_x))
})

# ---------------------------------------------------------------------------
# as_attrition_table -- grouped grid rendering
# ---------------------------------------------------------------------------

test_that("as_attrition_table() with flextable accepts group_x/group_y", {
  skip_if_not_installed("flextable")
  skip_if_not_installed("officer")

  flow <- make_flow_stepped_wedge()
  ft   <- as_attrition_table(flow, backend = "flextable",
                             group_x = "site_id", group_y = "period")
  expect_s3_class(ft, "flextable")
})

test_that("as_attrition_table() with gt accepts group_x/group_y", {
  skip_if_not_installed("gt")

  flow <- make_flow_stepped_wedge()
  gt_tbl <- as_attrition_table(flow, backend = "gt",
                               group_x = "site_id", group_y = "period")
  expect_s3_class(gt_tbl, "gt_tbl")
})

test_that("as_attrition_table() with huxtable accepts group_x/group_y", {
  skip_if_not_installed("huxtable")

  flow <- make_flow_stepped_wedge()
  ht <- as_attrition_table(flow, backend = "huxtable",
                           group_x = "site_id", group_y = "period")
  expect_s3_class(ht, "huxtable")
})

test_that("as_attrition_table() accepts group_x alone (no group_y)", {
  skip_if_not_installed("flextable")
  skip_if_not_installed("officer")

  flow <- make_flow_stepped_wedge()
  ft   <- as_attrition_table(flow, backend = "flextable", group_x = "site_id")
  expect_s3_class(ft, "flextable")
})

test_that("as_attrition_table() accepts group_y alone (no group_x)", {
  skip_if_not_installed("flextable")
  skip_if_not_installed("officer")

  flow <- make_flow_stepped_wedge()
  ft   <- as_attrition_table(flow, backend = "flextable", group_y = "period")
  expect_s3_class(ft, "flextable")
})

test_that("group_x_label / group_y_label prefix the grid headings", {
  skip_if_not_installed("flextable")
  skip_if_not_installed("officer")

  flow <- make_flow_stepped_wedge()
  ft   <- as_attrition_table(
    flow, backend = "flextable",
    group_x = "site_id", group_y = "period",
    group_x_label = "Site", group_y_label = "Period"
  )
  expect_s3_class(ft, "flextable")
})

# ---------------------------------------------------------------------------
# Shading -- .attrition_shade_colours() (internal helper)
# ---------------------------------------------------------------------------

test_that("shade = NULL and shade_fn = NULL produces all-NA colours", {
  flow <- make_flow_categorised()
  tbl  <- as_attrition_tibble(flow)
  cols <- cohortflow:::.attrition_shade_colours(tbl, NULL, NULL, c("#FFFFFF", "#F8696B"))

  expect_equal(length(cols), nrow(tbl))
  expect_true(all(is.na(cols)))
})

test_that("shade = 'pct_removed' shades step/category rows only", {
  flow <- make_flow_categorised()
  tbl  <- as_attrition_tibble(flow)
  cols <- cohortflow:::.attrition_shade_colours(tbl, "pct_removed", NULL, c("#FFFFFF", "#F8696B"))

  expect_equal(length(cols), nrow(tbl))
  shadeable <- tbl$row_type %in% c("step", "category") & !is.na(tbl$pct_removed)
  expect_true(all(!is.na(cols[shadeable])))
  expect_true(all(is.na(cols[tbl$row_type %in% c("header", "final")])))
})

test_that("shade = 'n_removed' produces valid hex colours", {
  flow <- make_flow_categorised()
  tbl  <- as_attrition_tibble(flow)
  cols <- cohortflow:::.attrition_shade_colours(tbl, "n_removed", NULL, c("#FFFFFF", "#F8696B"))

  non_na <- cols[!is.na(cols)]
  expect_true(length(non_na) > 0L)
  expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", non_na)))
})

test_that("shade rejects invalid string values", {
  flow <- make_flow_categorised()
  tbl  <- as_attrition_tibble(flow)
  expect_error(
    cohortflow:::.attrition_shade_colours(tbl, "not_a_column", NULL, c("#FFFFFF", "#F8696B")),
    "pct_removed.*n_removed"
  )
})

test_that("shade_fn takes precedence over shade and is applied verbatim", {
  flow <- make_flow_categorised()
  tbl  <- as_attrition_tibble(flow)

  fn <- function(t) ifelse(t$row_type == "final", "#00FF00", NA_character_)
  cols <- cohortflow:::.attrition_shade_colours(tbl, "pct_removed", fn, c("#FFFFFF", "#F8696B"))

  expect_equal(cols[tbl$row_type == "final"], "#00FF00")
  expect_true(all(is.na(cols[tbl$row_type != "final"])))
})

test_that("shade_fn returning wrong length errors informatively", {
  flow <- make_flow_categorised()
  tbl  <- as_attrition_tibble(flow)

  bad_fn <- function(t) c("#FFFFFF", "#000000")
  expect_error(
    cohortflow:::.attrition_shade_colours(tbl, NULL, bad_fn, c("#FFFFFF", "#F8696B")),
    "same length"
  )
})

test_that("as_attrition_table() accepts shade = 'pct_removed'", {
  skip_if_not_installed("flextable")
  skip_if_not_installed("officer")

  flow <- make_flow_categorised()
  ft   <- as_attrition_table(flow, shade = "pct_removed")
  expect_s3_class(ft, "flextable")
})

test_that("as_attrition_table() accepts shade_fn", {
  skip_if_not_installed("flextable")
  skip_if_not_installed("officer")

  flow <- make_flow_categorised()
  fn <- function(t) {
    ifelse(t$row_type == "step" & !is.na(t$pct_removed) & t$pct_removed > 2,
           "#FFCCCC", NA_character_)
  }
  ft <- as_attrition_table(flow, shade_fn = fn)
  expect_s3_class(ft, "flextable")
})

test_that("as_attrition_table() with gt accepts shade", {
  skip_if_not_installed("gt")

  flow <- make_flow_categorised()
  gt_tbl <- as_attrition_table(flow, backend = "gt", shade = "n_removed")
  expect_s3_class(gt_tbl, "gt_tbl")
})

test_that("as_attrition_table() with huxtable accepts shade", {
  skip_if_not_installed("huxtable")

  flow <- make_flow_categorised()
  ht <- as_attrition_table(flow, backend = "huxtable", shade = "n_removed")
  expect_s3_class(ht, "huxtable")
})

test_that("shade works together with group_x/group_y grid rendering", {
  skip_if_not_installed("flextable")
  skip_if_not_installed("officer")

  flow <- make_flow_stepped_wedge()
  ft <- as_attrition_table(
    flow, backend = "flextable",
    group_x = "site_id", group_y = "period",
    shade = "pct_removed"
  )
  expect_s3_class(ft, "flextable")
})

# ---------------------------------------------------------------------------
# as_attrition_tibble -- levels (hierarchy-aware counting)
# ---------------------------------------------------------------------------

test_that("as_attrition_tibble() default (levels = character(0)) is unaffected by hierarchy", {
  flow <- make_flow_hierarchy()
  out  <- as_attrition_tibble(flow)

  expect_named(out, c("row_type", "label", "indent_level", "n",
                      "n_removed", "pct_removed", "branch"))
  expect_equal(out$n[[1]], nrow(flow$data))
})

test_that("as_attrition_tibble(levels = NULL) returns one stacked block per hierarchy level", {
  flow <- make_flow_hierarchy()
  out  <- as_attrition_tibble(flow, levels = NULL)

  expect_true("level" %in% names(out))
  expect_true("n_consequential" %in% names(out))
  expect_setequal(unique(out$level), c("participant", "cluster"))

  # Each level's block has its own header + final row
  participant_block <- out[out$level == "participant", ]
  cluster_block      <- out[out$level == "cluster", ]
  expect_equal(participant_block$row_type[[1]], "header")
  expect_equal(participant_block$row_type[[nrow(participant_block)]], "final")
  expect_equal(cluster_block$row_type[[1]], "header")
  expect_equal(cluster_block$n[[1]], length(unique(flow$data$cluster_id)))
})

test_that("as_attrition_tibble(levels = <name>) returns only the requested level(s)", {
  flow <- make_flow_hierarchy()
  out  <- as_attrition_tibble(flow, levels = "cluster")

  expect_equal(unique(out$level), "cluster")
  expect_equal(out$n[[1]], length(unique(flow$data$cluster_id)))
})

test_that("as_attrition_tibble(levels=) errors without a hierarchy on flow", {
  flow <- make_flow_flat()
  expect_error(as_attrition_tibble(flow, levels = NULL), "hierarchy")
})

test_that("as_attrition_tibble(levels=) errors on an unknown level name", {
  flow <- make_flow_hierarchy()
  expect_error(as_attrition_tibble(flow, levels = "site"), "Unknown hierarchy level")
})

test_that("as_attrition_tibble(levels=) cannot be combined with group_x/branch_by", {
  flow <- make_flow_hierarchy()
  expect_error(
    as_attrition_tibble(flow, levels = NULL, group_x = "cluster_id"),
    "cannot be combined"
  )
  expect_error(
    as_attrition_tibble(flow, levels = NULL, branch_by = "arm"),
    "cannot be combined"
  )
})

test_that("as_attrition_tibble(levels=) group_include step shows n_consequential at finer levels", {
  flow <- make_flow_hierarchy()
  out  <- as_attrition_tibble(flow, levels = NULL, show_categories = FALSE)

  participant_rows <- out[out$level == "participant" & out$row_type == "step", ]
  cluster_step_label <- "Cluster size >= 15"
  conseq <- participant_rows$n_consequential[participant_rows$label == cluster_step_label]
  expect_true(is.na(conseq) || conseq >= 0L)
})
