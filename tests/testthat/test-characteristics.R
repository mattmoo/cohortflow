# ---------------------------------------------------------------------------
# Helpers

make_flow_chars <- function() {
  dat <- mock_parallel_rct(n_participants = 200, seed = 1)
  dat$sex <- factor(dat$sex, levels = c("F", "M", "O"))
  crit <- cf_criteria() |>
    include(~ !is.na(age),     label = "Age recorded",     category = "Valid age") |>
    include(~ age >= 18,       label = "Adults only",      category = "Valid age") |>
    include(~ eligible_screen, label = "Passed screening") |>
    exclude(~ withdrew,        label = "Withdrew consent")
  apply_criteria(dat, crit, id = "participant_id")
}

# The stat a Table 1 cell should show, computed independently of the package.
expect_cell <- function(tbl, variable, level, step, count, stat) {
  row <- tbl[tbl$variable == variable & tbl$step == step &
               (if (is.na(level)) is.na(tbl$level) else !is.na(tbl$level) & tbl$level == level), ]
  expect_equal(nrow(row), 1L)
  if (!is.null(count)) expect_identical(row$count, as.integer(count))
  expect_identical(row$stat, stat)
}

# ---------------------------------------------------------------------------
# Shape

test_that("long tibble has one row per variable x summary row x step, in order", {
  f   <- make_flow_chars()
  tbl <- as_characteristics_tibble(f, vars = c("age", "sex"))
  expect_s3_class(tbl, "tbl_df")
  expect_named(tbl, c("variable", "level", "step", "label", "n", "count", "pct", "stat"))
  # age: Mean (SD) + Missing; sex: F, M, O (+ no Missing); 5 steps (0..4)
  expect_equal(nrow(tbl), (2L + 3L) * 5L)
  expect_identical(unique(tbl$variable), c("age", "sex"))
  expect_identical(tbl$step[tbl$variable == "age" & tbl$level == "Mean (SD)"], 0:4)
  expect_identical(unique(tbl$label), c("Assessed for eligibility", "Age recorded", "Adults only",
                                        "Passed screening", "Withdrew consent"))
  expect_true(all(vapply(0:4, function(k) tbl$n[tbl$step == k][[1L]] == nrow(cohort(f, step_number = k)),
                         logical(1L))))
})

test_that("every column comes from cohort(step_number = k)", {
  f   <- make_flow_chars()
  tbl <- as_characteristics_tibble(f, vars = "age", missing = "always")
  for (k in 0:4) {
    x <- cohort(f, step_number = k)$age
    expect_cell(tbl, "age", "Mean (SD)", k, NULL,
                sprintf("%.1f (%.1f)", mean(x, na.rm = TRUE), stats::sd(x, na.rm = TRUE)))
    n_na <- sum(is.na(x))
    expect_cell(tbl, "age", "Missing", k, n_na, sprintf("%d (%.1f%%)", n_na, 100 * n_na / length(x)))
  }
})

# ---------------------------------------------------------------------------
# Summaries by type

test_that("factor levels are all shown in level order with % of non-missing", {
  f   <- make_flow_chars()
  tbl <- as_characteristics_tibble(f, vars = "sex")
  expect_identical(unique(tbl$level), c("F", "M", "O"))
  x <- f$data$sex
  n_f <- sum(x == "F", na.rm = TRUE)
  expect_cell(tbl, "sex", "F", 0, n_f, sprintf("%d (%.1f%%)", n_f, 100 * n_f / sum(!is.na(x))))
  expect_equal(sum(tbl$count[tbl$step == 0L]), sum(!is.na(x)))
})

test_that("character levels are the sorted distinct starting values, fixed across steps", {
  f   <- make_flow_chars()
  tbl <- as_characteristics_tibble(f, vars = "ethnicity")
  lv  <- sort(unique(f$data$ethnicity))
  expect_identical(unique(tbl$level), lv)
  # The same rows appear for every step even where a level has no rows
  expect_equal(nrow(tbl), length(lv) * 5L)
})

test_that("logical variables get a single NA-level row counting TRUE", {
  f   <- make_flow_chars()
  tbl <- as_characteristics_tibble(f, vars = "withdrew")
  expect_true(all(is.na(tbl$level)))
  n_w <- sum(f$data$withdrew)
  expect_cell(tbl, "withdrew", NA, 0, n_w, sprintf("%d (%.1f%%)", n_w, 100 * n_w / nrow(f$data)))
  # Nobody who withdrew survives the last step
  expect_cell(tbl, "withdrew", NA, 4, 0, "0 (0.0%)")
})

test_that("numeric = both gives Mean (SD) then Median [IQR] with quartiles", {
  f   <- make_flow_chars()
  tbl <- as_characteristics_tibble(f, vars = "age", numeric = c("median_iqr", "mean_sd"), digits = 2)
  expect_identical(unique(tbl$level), c("Median [IQR]", "Mean (SD)", "Missing"))
  x <- cohort(f)$age
  q <- stats::quantile(x, c(0.25, 0.5, 0.75), names = FALSE)
  expect_cell(tbl, "age", "Median [IQR]", 4, NULL, sprintf("%.2f [%.2f, %.2f]", q[2], q[1], q[3]))
  expect_cell(tbl, "age", "Mean (SD)", 4, NULL, sprintf("%.2f (%.2f)", mean(x), stats::sd(x)))
})

test_that("missing row: ifany drops it when no step has NA, always keeps it, never drops it", {
  f <- make_flow_chars()
  expect_false("Missing" %in% as_characteristics_tibble(f, vars = "sex")$level)
  expect_true("Missing" %in% as_characteristics_tibble(f, vars = "sex", missing = "always")$level)
  expect_true("Missing" %in% as_characteristics_tibble(f, vars = "age")$level)
  expect_false("Missing" %in% as_characteristics_tibble(f, vars = "age", missing = "never")$level)
  tbl <- as_characteristics_tibble(f, vars = "age", missing_label = "Not recorded")
  expect_true("Not recorded" %in% tbl$level)
})

test_that("an empty column gives NA statistics and zero counts", {
  dat  <- mock_parallel_rct(n_participants = 50, seed = 2)
  crit <- cf_criteria() |> include(~ age > 1000, label = "Nobody")
  f    <- apply_criteria(dat, crit, id = "participant_id")
  tbl  <- as_characteristics_tibble(f, vars = c("age", "sex", "withdrew"), missing = "always")
  at1  <- tbl[tbl$step == 1L, ]
  expect_true(all(at1$n == 0L))
  expect_true(is.na(at1$stat[at1$level %in% "Mean (SD)"]))
  expect_true(all(at1$count[at1$variable != "age"] == 0L))
  expect_true(all(is.na(at1$pct)))
  expect_true(all(at1$stat[at1$variable == "sex"] == "0"))
})

test_that("a single observation shows an em dash for the undefined SD", {
  dat  <- mock_parallel_rct(n_participants = 50, seed = 2)
  crit <- cf_criteria() |> include(~ participant_id == "P0001", label = "One")
  f    <- apply_criteria(dat, crit, id = "participant_id")
  tbl  <- as_characteristics_tibble(f, vars = "age", steps = 1)
  expect_match(tbl$stat[tbl$level == "Mean (SD)"], "\\(\u2014\\)$")
})

# ---------------------------------------------------------------------------
# Step selection

test_that("steps restricts and reorders using cohort()'s selectors", {
  f   <- make_flow_chars()
  tbl <- as_characteristics_tibble(f, vars = "age", steps = list("Withdrew consent", 0, "Valid age"))
  expect_identical(unique(tbl$step), c(4L, 0L, 2L))
  expect_identical(unique(tbl$label), c("Withdrew consent", "Assessed for eligibility", "Adults only"))
  expect_identical(unique(as_characteristics_tibble(f, vars = "age", steps = c(3, 1))$step), c(3L, 1L))
})

test_that("step selection errors are clear", {
  f <- make_flow_chars()
  expect_error(as_characteristics_tibble(f, vars = "age", steps = c(1, 1)), "more than once")
  expect_error(as_characteristics_tibble(f, vars = "age", steps = "Nope"), "matches no step label")
  expect_error(as_characteristics_tibble(f, vars = "age", steps = 9), "out of range")
  expect_error(as_characteristics_tibble(f, vars = "age", steps = character(0)), "`steps` must be")
  expect_error(as_characteristics_tibble(f, vars = "age", steps = 0, excluded = TRUE), "step 0")
})

test_that("randomise() steps are dropped by default but kept when named", {
  f   <- make_flow_randomise()
  rnd <- .step_numbers(f)[vapply(f$steps, function(s) s$type, character(1L)) == "randomise"]
  expect_false(rnd %in% as_characteristics_tibble(f, vars = "age")$step)
  expect_true(rnd %in% as_characteristics_tibble(f, vars = "age", drop_randomise = FALSE)$step)
  expect_true(rnd %in% as_characteristics_tibble(f, vars = "age", steps = rnd)$step)
})

test_that("repeated step labels are made unique in headings", {
  dat  <- mock_parallel_rct(n_participants = 100, seed = 3)
  crit <- cf_criteria() |>
    include(~ age >= 18, label = "Check") |>
    include(~ eligible_screen, label = "Check")
  f   <- apply_criteria(dat, crit, id = "participant_id")
  tbl <- as_characteristics_tibble(f, vars = "age")
  expect_identical(unique(tbl$label), c("Assessed for eligibility", "Check", "Check #1"))
})

# ---------------------------------------------------------------------------
# Excluded mode

test_that("excluded = TRUE describes the rows removed at each step", {
  f   <- make_flow_chars()
  tbl <- as_characteristics_tibble(f, vars = c("age", "withdrew"), excluded = TRUE)
  expect_identical(unique(tbl$step), 1:4)
  ex <- excluded(f)
  for (k in 1:4) {
    rows <- ex[ex$cf_step == k, ]
    expect_equal(tbl$n[tbl$step == k][[1L]], nrow(rows))
  }
  # Everyone removed by "Withdrew consent" withdrew; everyone removed by
  # "Age recorded" has a missing age.
  expect_cell(tbl, "withdrew", NA, 4, sum(ex$cf_step == 4L),
              sprintf("%d (100.0%%)", sum(ex$cf_step == 4L)))
  n1 <- sum(ex$cf_step == 1L)
  expect_cell(tbl, "age", "Missing", 1, n1, sprintf("%d (100.0%%)", n1))
  expect_true(is.na(tbl$stat[tbl$step == 1L & tbl$level %in% "Mean (SD)"]))
})

# ---------------------------------------------------------------------------
# Hierarchy levels

test_that("level summarises one row per complete unit and counts units", {
  f   <- make_flow_hierarchy()
  tbl <- as_characteristics_tibble(f, vars = "arm", level = "cluster", steps = c(0, 3))
  n_clusters <- length(unique(f$data$cluster_id))
  expect_equal(tbl$n[tbl$step == 0L][[1L]], n_clusters)
  expect_equal(tbl$n[tbl$step == 3L][[1L]], length(unique(cohort(f, step_number = 3)$cluster_id)))
  expect_equal(sum(tbl$count[tbl$step == 0L]), n_clusters)
})

test_that("level rejects variables that vary within a unit, flows without a hierarchy, unknown levels", {
  f <- make_flow_hierarchy()
  expect_error(as_characteristics_tibble(f, vars = c("arm", "age"), level = "cluster"),
               "`age` vary within `cluster` units")
  expect_error(as_characteristics_tibble(f, vars = "age", level = "site"), "not a hierarchy level")
  expect_error(as_characteristics_tibble(make_flow_chars(), vars = "age", level = "cluster"),
               "requires a flow built with")
  expect_error(as_characteristics_tibble(f, vars = "age", level = c("a", "b")), "single hierarchy level")
})

test_that("rows with an NA level key are not units", {
  dat <- mock_cluster_rct(n_clusters = 6, n_participants = 120, seed = 1)
  dat$cluster_id[1:5] <- NA
  h   <- cf_hierarchy(participant = "participant_id", cluster = "cluster_id")
  f   <- apply_criteria(dat, cf_criteria() |> include(~ age >= 18, label = "Adults"),
                        id = "participant_id", hierarchy = h)
  tbl <- as_characteristics_tibble(f, vars = "arm", level = "cluster", steps = 0)
  expect_equal(tbl$n[[1L]], length(unique(stats::na.omit(dat$cluster_id))))
})

# ---------------------------------------------------------------------------
# Wide form

test_that("wide = TRUE pivots to one column per step headed by label and n", {
  f    <- make_flow_chars()
  long <- as_characteristics_tibble(f, vars = c("age", "sex"))
  wide <- as_characteristics_tibble(f, vars = c("age", "sex"), wide = TRUE)
  expect_named(wide, c("variable", "level",
                       sprintf("%s (n = %d)", unique(long$label), unique(long$n))))
  expect_equal(nrow(wide), nrow(long) / 5L)
  expect_identical(wide[[3L]][wide$variable == "age" & wide$level == "Mean (SD)"],
                   long$stat[long$variable == "age" & long$level == "Mean (SD)" & long$step == 0L])
  expect_identical(wide$level[wide$variable == "sex"], c("F", "M", "O"))
})

# ---------------------------------------------------------------------------
# Argument validation

test_that("vars are validated", {
  f <- make_flow_chars()
  expect_error(as_characteristics_tibble(f, vars = character(0)), "`vars` must be")
  expect_error(as_characteristics_tibble(f, vars = c("age", "age")), "more than once")
  expect_error(as_characteristics_tibble(f, vars = "nope"), "not found in the flow data: `nope`")
  expect_error(as_characteristics_tibble(f, vars = ".cf_row_id"), "not found")
  expect_error(as_characteristics_tibble(f, vars = "consent_date"), "is <Date>")
  expect_error(as_characteristics_tibble("x", vars = "age"), "`flow` must be")
})

test_that("other arguments are validated", {
  f <- make_flow_chars()
  expect_error(as_characteristics_tibble(f, vars = "age", numeric = "mode"), "`numeric` must be")
  expect_error(as_characteristics_tibble(f, vars = "age", digits = -1), "`digits` must be")
  expect_error(as_characteristics_tibble(f, vars = "age", digits = 1.5), "`digits` must be")
  expect_error(as_characteristics_tibble(f, vars = "age", excluded = NA), "`excluded` must be")
  expect_error(as_characteristics_tibble(f, vars = "age", wide = "yes"), "`wide` must be")
  expect_error(as_characteristics_tibble(f, vars = "age", missing = "sometimes"), "should be one of")
  expect_error(as_characteristics_tibble(f, vars = "age", assessed_label = 1), "`assessed_label` must be")
})

# ---------------------------------------------------------------------------
# Stacked cohorts

test_that("stack_cohorts() stacks each step's cohort with a step factor", {
  f  <- make_flow_chars()
  st <- stack_cohorts(f)
  expect_s3_class(st, "tbl_df")
  expect_identical(names(st)[1:2], c("step_number", "step"))
  expect_identical(names(st)[-(1:2)], setdiff(names(f$data), ".cf_row_id"))
  expect_true(is.factor(st$step))
  expect_identical(levels(st$step), c("Assessed for eligibility", "Age recorded", "Adults only",
                                      "Passed screening", "Withdrew consent"))
  expect_identical(unname(c(table(st$step_number))),
                   vapply(0:4, function(k) nrow(cohort(f, step_number = k)), integer(1L)))
  expect_identical(st$participant_id[st$step_number == 4L], cohort(f)$participant_id)
  # Totals agree with the characteristics tibble
  tbl <- as_characteristics_tibble(f, vars = "age")
  expect_identical(unname(c(table(st$step_number))), unique(tbl$n))
})

test_that("stack_cohorts() excluded mode and step selection", {
  f  <- make_flow_chars()
  st <- stack_cohorts(f, steps = list("Withdrew consent", 1), excluded = TRUE)
  expect_identical(levels(st$step), c("Withdrew consent", "Age recorded"))
  expect_identical(unique(st$step_number), c(4L, 1L))
  ex <- excluded(f)
  expect_identical(sort(st$participant_id[st$step_number == 4L]), sort(ex$participant_id[ex$cf_step == 4L]))
  expect_false(any(c("cf_step", "cf_label") %in% names(st)))
})

test_that("stack_cohorts() at a level keeps the key and unit-constant columns only", {
  f  <- make_flow_hierarchy()
  st <- stack_cohorts(f, level = "cluster", steps = 0)
  expect_true("cluster_id" %in% names(st))
  expect_true("arm" %in% names(st))
  expect_false(any(c("participant_id", "age") %in% names(st)))
  expect_equal(nrow(st), length(unique(f$data$cluster_id)))
})

# ---------------------------------------------------------------------------
# Rendered tables

test_that("display frame has a bold variable row, indented levels, inline logicals", {
  f   <- make_flow_chars()
  tbl <- as_characteristics_tibble(f, vars = c("age", "withdrew"), steps = c(0, 4))
  d   <- .characteristics_display(tbl, var_labels = c(withdrew = "Withdrew"))
  expect_identical(d$row_type, c("variable", "level", "level", "variable"))
  expect_identical(d$df$label, c("age", "Mean (SD)", "Missing", "Withdrew"))
  expect_identical(d$df$s1[[1L]], "")
  expect_match(d$df$s1[[4L]], "^[0-9]+ \\([0-9.]+%\\)$")
  expect_identical(d$df$s2[[4L]], "0 (0.0%)")
  expect_identical(unname(d$headers), sprintf("%s (n = %d)", unique(tbl$label), unique(tbl$n)))
})

test_that("var_labels are validated and applied", {
  f <- make_flow_chars()
  expect_error(as_characteristics_table(f, vars = "age", var_labels = c(nope = "x")), "not in `vars`")
  expect_error(as_characteristics_table(f, vars = "age", var_labels = c("a", "b")), "has 2 label")
  tbl <- as_characteristics_tibble(f, vars = c("age", "sex"), steps = 0)
  d   <- .characteristics_display(tbl, .resolve_var_labels(c("age", "sex"), c("Age", "Sex")))
  expect_identical(d$df$label[d$row_type == "variable"], c("Age", "Sex"))
})

test_that("flextable backend renders", {
  skip_if_not_installed("flextable")
  skip_if_not_installed("officer")
  f  <- make_flow_chars()
  ft <- as_characteristics_table(f, vars = c("age", "sex", "withdrew"))
  expect_s3_class(ft, "flextable")
  expect_equal(nrow(ft$body$dataset), 2L + 3L + 1L + 1L + 1L)
  html <- paste(as.character(flextable::htmltools_value(ft)), collapse = "")
  expect_match(html, "Characteristic", fixed = TRUE)
  expect_match(html, "Assessed for eligibility (n = 200)", fixed = TRUE)
})

test_that("gt backend renders", {
  skip_if_not_installed("gt")
  f <- make_flow_chars()
  g <- as_characteristics_table(f, vars = c("age", "sex"), backend = "gt", excluded = TRUE)
  expect_s3_class(g, "gt_tbl")
  expect_equal(ncol(g[["_data"]]), 1L + 4L)
})

test_that("huxtable backend renders", {
  skip_if_not_installed("huxtable")
  f <- make_flow_chars()
  h <- as_characteristics_table(f, vars = c("age", "sex"), backend = "huxtable",
                                variable_col_label = "Measure", steps = c(0, 4))
  expect_s3_class(h, "huxtable")
  expect_identical(h[[1L, 1L]], "Measure")
  # Column header, then three rows for age and four for sex
  expect_equal(nrow(h), 1L + 3L + 4L)
})

test_that("renderers report a missing backend package", {
  f <- make_flow_chars()
  local_mocked_bindings(.has_namespace = function(pkg) FALSE)
  expect_error(as_characteristics_table(f, vars = "age"), "flextable")
  expect_error(as_characteristics_table(f, vars = "age", backend = "gt"), "gt")
  expect_error(as_characteristics_table(f, vars = "age", backend = "huxtable"), "huxtable")
})
