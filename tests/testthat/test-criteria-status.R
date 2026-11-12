# ---------------------------------------------------------------------------
# Helpers

# Criterion columns of a criteria_status() tibble, as a plain logical matrix.
status_crit <- function(st, n_lead) unname(as.matrix(st[, -seq_len(n_lead), drop = FALSE]))

# The cascade's expected cumulative matrix, from cohort(flag = TRUE).
expected_cumulative <- function(flow, steps = seq_along(flow$steps)) {
  e <- cohort(flow, flag = TRUE)$cf_excluded_step
  out <- outer(e, steps, function(e, k) ifelse(is.na(e) | k < e, TRUE, ifelse(k == e, FALSE, NA)))
  storage.mode(out) <- "logical"
  out
}

make_flow_continue <- function() {
  dat <- mock_parallel_rct(n_participants = 200, seed = 1)
  f1  <- apply_criteria(dat, cf_criteria() |> include(~ eligible_screen, label = "Passed screening"),
                        id = "participant_id")
  # Follow-up data only exists for the stage-1 survivors
  survivors <- cohort(f1)$participant_id
  follow <- data.frame(participant_id = survivors, score = seq_along(survivors) %% 10)
  continue_criteria(f1, cf_criteria() |> include(~ score > 2, label = "Score above 2"),
                    join = follow, by = "participant_id")
}

# ---------------------------------------------------------------------------
# Shape and identifiers

test_that("criteria_status() has one row per data row and one column per criterion", {
  f  <- make_flow_categorised()
  st <- criteria_status(f)
  expect_s3_class(st, "tbl_df")
  expect_equal(nrow(st), nrow(f$data))
  expect_named(st, c(".cf_row_id", vapply(f$steps, `[[`, character(1L), "label")))
  expect_true(all(vapply(st[-1L], is.logical, logical(1L))))
  expect_identical(st$.cf_row_id, f$data$.cf_row_id)
})

test_that("id columns: single, composite and automatic", {
  single <- criteria_status(make_flow_hierarchy())
  expect_identical(names(single)[1L], "participant_id")
  expect_false(".cf_row_id" %in% names(single))

  dat  <- mock_crossover(n_participants = 30, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age recorded") |>
    exclude(~ withdrew, label = "Withdrew")
  comp <- criteria_status(apply_criteria(dat, crit, id = c("participant_id", "period")))
  expect_identical(names(comp)[1:2], c("participant_id", "period"))
  expect_identical(comp$period, dat$period)
  expect_false(".cf_row_id" %in% names(comp))

  auto <- criteria_status(make_flow_categorised())
  expect_identical(names(auto)[1L], ".cf_row_id")
})

test_that("keep_data carries the original columns, without .cf_row_id", {
  f  <- make_flow_hierarchy()
  st <- criteria_status(f, keep_data = TRUE)
  data_cols <- setdiff(names(f$data), ".cf_row_id")
  labels    <- vapply(f$steps, `[[`, character(1L), "label")
  expect_named(st, c("participant_id", setdiff(data_cols, "participant_id"), labels))
  expect_identical(as.list(st[data_cols]), as.list(f$data[data_cols]))
})

# ---------------------------------------------------------------------------
# Cumulative mode

test_that("cumulative counts match the cascade at every step", {
  flows <- list(make_flow_categorised(), make_flow_hierarchy(), make_flow_continue())
  for (f in flows) {
    st <- criteria_status(f)
    n_lead <- ncol(st) - length(f$steps)
    m <- status_crit(st, n_lead)
    for (k in seq_along(f$steps)) {
      s <- f$steps[[k]]
      expect_equal(sum(m[, k], na.rm = TRUE), s$n_pass)
      expect_equal(sum(!m[, k], na.rm = TRUE), s$n_fail)
      expect_equal(sum(is.na(m[, k])), nrow(f$data) - s$n_in)
    }
  }
})

test_that("cumulative: TRUE before, FALSE at, NA after the excluding step", {
  f <- make_flow_categorised()
  m <- status_crit(criteria_status(f), 1L)
  expect_identical(m, expected_cumulative(f))
  expect_true(all(rowSums(!m, na.rm = TRUE) <= 1L))
  # Rows that pass every step are all TRUE
  survivors <- f$data$.cf_row_id %in% .surviving_ids(f)
  expect_true(all(m[survivors, ]))
})

# ---------------------------------------------------------------------------
# Independent mode

test_that("independent: first step equals cumulative; row-wise steps equal the predicate", {
  f   <- make_flow_categorised()
  ind <- criteria_status(f, mode = "independent")
  cum <- criteria_status(f)
  # Everyone enters step 1, and its predicate (!is.na(age)) is never NA, so
  # the two modes agree there.
  expect_identical(ind[["Age recorded"]], cum[["Age recorded"]])
  # include(~ age >= 18): the raw predicate, NA preserved
  expect_identical(ind[["Adults only"]], f$data$age >= 18)
  expect_true(anyNA(ind[["Adults only"]]))
  # exclude(~ withdrew): negated predicate
  expect_identical(ind[["Withdrew consent"]], !f$data$withdrew)
})

test_that("independent: group_include is evaluated on the full data", {
  f   <- make_flow_hierarchy()
  col <- criteria_status(f, mode = "independent")[["Cluster size >= 15"]]
  expect_type(col, "logical")
  expect_length(col, nrow(f$data))
  expect_identical(is.na(col), is.na(f$data$cluster_id))
  cluster_n <- stats::ave(rep(1L, nrow(f$data)), f$data$cluster_id, FUN = length)
  expect_identical(col, cluster_n >= 15)
})

test_that("independent: select_within reports NA for rows with no group", {
  dat <- mock_crossover(n_participants = 20, seed = 1)
  dat$participant_id[1:2] <- NA
  crit <- cf_criteria() |>
    select_within(by = "participant_id", ~ period == min(period), label = "First period")
  f   <- apply_criteria(dat, crit, id = "event_id")
  col <- criteria_status(f, mode = "independent")[["First period"]]
  expect_identical(is.na(col), is.na(dat$participant_id))
  expect_identical(col[-(1:2)], dat$period[-(1:2)] == 1L)
  # The cascade removes the NA-key rows, so cumulative says FALSE there
  expect_false(any(criteria_status(f)[["First period"]][1:2]))
})

test_that("independent: later-stage criteria are NA for rows excluded before a join", {
  f   <- make_flow_continue()
  ind <- criteria_status(f, mode = "independent")
  stage1_out <- !f$data$.cf_row_id %in% .surviving_ids(f, 1L)
  expect_true(any(stage1_out))
  expect_true(all(is.na(ind[["Score above 2"]][stage1_out])))
  expect_false(anyNA(ind[["Score above 2"]][!stage1_out]))
})

# ---------------------------------------------------------------------------
# sets, na, names

test_that("sets = 'fail' negates the criterion columns, keeping NA", {
  f    <- make_flow_categorised()
  pass <- status_crit(criteria_status(f), 1L)
  fail <- status_crit(criteria_status(f, sets = "fail"), 1L)
  expect_identical(fail, !pass)
  expect_identical(is.na(fail), is.na(pass))
})

test_that("na = 'false' and na = 'drop'", {
  f    <- make_flow_categorised()
  keep <- status_crit(criteria_status(f), 1L)
  expect_true(anyNA(keep))

  fls <- status_crit(criteria_status(f, na = "false"), 1L)
  expect_false(anyNA(fls))
  expect_identical(fls, replace(keep, is.na(keep), FALSE))

  dropped <- criteria_status(f, na = "drop")
  expect_equal(nrow(dropped), sum(stats::complete.cases(keep)))
  expect_false(anyNA(dropped))

  # na is applied after sets
  fail_false <- status_crit(criteria_status(f, sets = "fail", na = "false"), 1L)
  expect_identical(fail_false, replace(!keep, is.na(keep), FALSE))
})

test_that("names = 'step' uses cf_step_<n>", {
  f <- make_flow_categorised()
  expect_named(criteria_status(f, names = "step"), c(".cf_row_id", paste0("cf_step_", 1:5)))
})

test_that("duplicate labels and name clashes are made unique with a warning", {
  dat <- mock_parallel_rct(n_participants = 50, seed = 1)
  dup <- apply_criteria(dat, cf_criteria() |>
                          include(~ !is.na(age), label = "Check") |>
                          include(~ age >= 18, label = "Check"), id = "participant_id")
  expect_warning(st <- criteria_status(dup), "more than once")
  expect_named(st, c("participant_id", "Check", "Check #1"))

  clash <- apply_criteria(dat, cf_criteria() |> include(~ !is.na(age), label = "age"),
                          id = "participant_id")
  expect_silent(criteria_status(clash))
  expect_warning(st <- criteria_status(clash, keep_data = TRUE), "clash")
  expect_identical(names(st)[ncol(st)], "age #1")
  expect_identical(st$age, dat$age)

  id_clash <- apply_criteria(dat, cf_criteria() |> include(~ !is.na(age), label = "participant_id"),
                             id = "participant_id")
  expect_warning(st <- criteria_status(id_clash), "clash")
  expect_named(st, c("participant_id", "participant_id #1"))
})

# ---------------------------------------------------------------------------
# Return types

test_that("as = 'matrix' returns a logical matrix keyed by the row id", {
  f <- make_flow_hierarchy()
  m <- criteria_status(f, as = "matrix")
  expect_true(is.matrix(m))
  expect_true(is.logical(m))
  expect_equal(dim(m), c(nrow(f$data), length(f$steps)))
  expect_identical(rownames(m), f$data$participant_id)
  expect_identical(colnames(m), vapply(f$steps, `[[`, character(1L), "label"))
  expect_identical(unname(m), status_crit(criteria_status(f), 1L))
  expect_message(criteria_status(f, keep_data = TRUE, as = "matrix"), "ignored")

  dat  <- mock_crossover(n_participants = 10, seed = 1)
  comp <- apply_criteria(dat, cf_criteria() |> exclude(~ withdrew, label = "Withdrew"),
                         id = c("participant_id", "period"))
  expect_identical(rownames(criteria_status(comp, as = "matrix")),
                   paste(dat$participant_id, dat$period, sep = "|"))

  dropped <- criteria_status(f, na = "drop", as = "matrix")
  expect_false(anyNA(dropped))
})

test_that("as = 'data.table' returns a data.table", {
  skip_if_not_installed("data.table")
  f  <- make_flow_hierarchy()
  dt <- criteria_status(f, as = "data.table")
  expect_s3_class(dt, "data.table")
  expect_identical(as.data.frame(dt), as.data.frame(criteria_status(f)))
})

# ---------------------------------------------------------------------------
# randomise and edge cases

test_that("randomise steps are dropped by default and kept on request", {
  f <- make_flow_randomise()
  expect_named(criteria_status(f), c("participant_id", "Age recorded", "Withdrew after allocation"))

  cum <- criteria_status(f, drop_randomise = FALSE)
  expect_named(cum, c("participant_id", "Age recorded", "Randomised", "Withdrew after allocation"))
  # Cumulative: TRUE where reached, NA for rows removed earlier, never FALSE
  expect_false(any(!cum$Randomised, na.rm = TRUE))
  expect_equal(sum(cum$Randomised, na.rm = TRUE), f$steps[[2]]$n_in)
  expect_identical(status_crit(cum, 1L), expected_cumulative(f))

  ind <- criteria_status(f, mode = "independent", drop_randomise = FALSE)
  expect_true(all(ind$Randomised))
})

test_that("zero-step flows return only the id columns", {
  dat <- mock_parallel_rct(n_participants = 20, seed = 1)
  f   <- apply_criteria(dat, cf_criteria(), id = "participant_id")
  for (mode in c("cumulative", "independent")) {
    st <- criteria_status(f, mode = mode)
    expect_named(st, "participant_id")
    expect_equal(nrow(st), 20L)
  }
  m <- criteria_status(f, as = "matrix")
  expect_equal(dim(m), c(20L, 0L))
  expect_equal(nrow(criteria_status(f, na = "drop")), 20L)
  # A flow whose only step is randomise() has no criterion columns by default
  r <- apply_criteria(dat, cf_criteria() |> randomise(by = "participant_id", arms = "arm"),
                      id = "participant_id")
  expect_named(criteria_status(r), "participant_id")
})

test_that("zero-row flows return zero rows with the right columns", {
  dat  <- mock_cluster_rct(n_clusters = 4, n_participants = 40, seed = 1)[0, ]
  crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age recorded") |>
    group_include(by = "cluster_id", ~ n() >= 2, label = "Cluster size") |>
    exclude(~ withdrew, label = "Withdrew")
  f <- apply_criteria(dat, crit, id = "participant_id")
  for (mode in c("cumulative", "independent")) {
    st <- criteria_status(f, mode = mode)
    expect_equal(nrow(st), 0L)
    expect_named(st, c("participant_id", "Age recorded", "Cluster size", "Withdrew"))
    expect_true(all(vapply(st[-1L], is.logical, logical(1L))))
  }
  expect_equal(dim(criteria_status(f, as = "matrix")), c(0L, 3L))
})

test_that("argument checks", {
  f <- make_flow_categorised()
  expect_error(criteria_status(list()), "cf_flow")
  expect_error(criteria_status(f, mode = "bogus"))
  expect_error(criteria_status(f, keep_data = NA), "keep_data")
  expect_error(criteria_status(f, drop_randomise = "yes"), "drop_randomise")
})
