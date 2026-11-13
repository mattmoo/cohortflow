test_that("cf_hierarchy() constructs correctly", {
  h <- cf_hierarchy(participant = "pid", cluster = "cid")
  expect_s3_class(h, "cf_hierarchy")
  expect_equal(h["participant"], c(participant = "pid"))
  expect_equal(h["cluster"],    c(cluster    = "cid"))
})

test_that("cf_hierarchy() requires named arguments", {
  expect_error(cf_hierarchy("pid", "cid"), class = "rlang_error")
})

test_that("cf_hierarchy() rejects duplicate role names", {
  expect_error(
    cf_hierarchy(participant = "pid", participant = "pid2"),
    class = "rlang_error"
  )
})

test_that("cf_hierarchy() rejects duplicate column names", {
  expect_error(
    cf_hierarchy(participant = "pid", cluster = "pid"),
    class = "rlang_error"
  )
})

test_that("cf_hierarchy() requires at least one level", {
  expect_error(cf_hierarchy(), class = "rlang_error")
})

test_that("print.cf_hierarchy() runs without error", {
  h <- cf_hierarchy(participant = "pid", cluster = "cid", site = "sid")
  expect_output(print(h))
})

test_that("validate_hierarchy() passes when all columns present", {
  h <- cf_hierarchy(participant = "pid", cluster = "cid")
  d <- data.frame(pid = 1, cid = 1)
  expect_invisible(cohortflow:::validate_hierarchy(h, d))
})

test_that("validate_hierarchy() errors on missing columns", {
  h <- cf_hierarchy(participant = "pid", cluster = "cid")
  d <- data.frame(pid = 1)
  expect_error(cohortflow:::validate_hierarchy(h, d), class = "rlang_error")
})

test_that("format.cf_hierarchy() returns a character string", {
  h <- cf_hierarchy(participant = "pid", cluster = "cid")
  s <- format(h)
  expect_type(s, "character")
  expect_true(grepl("pid", s))
  expect_true(grepl("cid", s))
})

test_that("cf_hierarchy() rejects non-character values", {
  expect_error(cf_hierarchy(participant = 1L), class = "rlang_error")
})

test_that("cf_hierarchy() with no arguments reports the missing level", {
  expect_error(cf_hierarchy(), "at least one level", class = "rlang_error")
})

test_that("cf_hierarchy() rejects a non-character value mixed with strings", {
  # c() would otherwise silently coerce 1L to "1"
  expect_error(cf_hierarchy(participant = "pid", cluster = 1L), "character", class = "rlang_error")
})
test_that("cf_hierarchy() supports composite (multi-column) levels", {
  h <- cf_hierarchy(participant = "pid",
                    cluster_period = c("cluster_id", "period"),
                    cluster = "cluster_id")
  expect_s3_class(h, "cf_hierarchy")
  expect_equal(h[["cluster_period"]], c("cluster_id", "period"))
  expect_equal(h["participant"], c(participant = "pid"))
})

test_that("cf_hierarchy() rejects two roles with an identical column set", {
  expect_error(
    cf_hierarchy(cluster_a = c("cluster_id", "period"),
                 cluster_b = c("period", "cluster_id")),
    class = "rlang_error"
  )
})

test_that("validate_hierarchy() checks every column of a composite level", {
  h <- cf_hierarchy(participant = "pid", cluster_period = c("cluster_id", "period"))
  d_ok <- data.frame(pid = 1, cluster_id = 1, period = 1)
  expect_invisible(cohortflow:::validate_hierarchy(h, d_ok))

  d_missing <- data.frame(pid = 1, cluster_id = 1)
  expect_error(cohortflow:::validate_hierarchy(h, d_missing), class = "rlang_error")
})

test_that("print.cf_hierarchy() displays composite levels", {
  h <- cf_hierarchy(participant = "pid", cluster_period = c("cluster_id", "period"))
  expect_output(print(h), "cluster_id \\+ period")
})

test_that("apply_criteria(hierarchy=) validates hierarchy columns against data", {
  dat  <- mock_cluster_rct(n_clusters = 5, n_participants = 100, seed = 1)
  h    <- cf_hierarchy(participant = "participant_id", cluster = "cluster_id")
  crit <- cf_criteria() |> include(~ !is.na(age), label = "Age recorded")

  expect_no_error(apply_criteria(dat, crit, id = "participant_id", hierarchy = h))

  bad_h <- cf_hierarchy(participant = "participant_id", cluster = "nonexistent_col")
  expect_error(
    apply_criteria(dat, crit, id = "participant_id", hierarchy = bad_h),
    "not found in data"
  )
})

test_that("apply_criteria(hierarchy=) requires a cf_hierarchy object", {
  dat  <- mock_cluster_rct(n_clusters = 5, n_participants = 100, seed = 1)
  crit <- cf_criteria() |> include(~ !is.na(age), label = "Age recorded")
  expect_error(
    apply_criteria(dat, crit, hierarchy = list(participant = "participant_id")),
    class = "rlang_error"
  )
})

test_that("apply_criteria(hierarchy=) attributes include() losses bottom-up per level", {
  flow <- make_flow_hierarchy()
  hc1  <- flow$steps[[1]]$hierarchy_counts  # "Age recorded" (include)

  expect_s3_class(hc1, "tbl_df")
  expect_setequal(hc1$level, c("participant", "cluster"))
  # A single participant excluded should never fully empty a whole cluster
  # (clusters have far more than 1 participant each), so cluster n_fail is 0.
  cluster_row <- hc1[hc1$level == "cluster", ]
  expect_equal(cluster_row$n_fail, 0L)
  expect_equal(cluster_row$n_consequential, 0L)
})

test_that("apply_criteria(hierarchy=) attributes group_include() losses top-down", {
  flow <- make_flow_hierarchy()
  # Step 3 is the group_include(by = "cluster_id", ~ n() >= 15, ...)
  step <- Filter(function(s) s$type == "group_include", flow$steps)[[1]]
  hc   <- step$hierarchy_counts

  cluster_row     <- hc[hc$level == "cluster", ]
  participant_row <- hc[hc$level == "participant", ]

  # The by-level (cluster) is the primary exclusion; any losses are real
  # exclusions, never consequential.
  expect_equal(cluster_row$n_consequential, 0L)
  # The finer level (participant) records the same units' loss as
  # consequential, never as a primary exclusion.
  expect_equal(participant_row$n_fail, 0L)
  # If any clusters were removed, their participants must show up as
  # consequential losses (same count as removed clusters would remove >0
  # participants collectively).
  if (cluster_row$n_fail > 0L) {
    expect_gt(participant_row$n_consequential, 0L)
  }
})

test_that("hierarchy_counts n_risk/n_pass are consistent across the pipeline", {
  flow <- make_flow_hierarchy()
  for (s in flow$steps) {
    hc <- s$hierarchy_counts
    expect_equal(hc$n_pass, hc$n_risk - hc$n_fail - hc$n_consequential)
  }
})

test_that("flow$hierarchy is stored and NULL by default", {
  dat  <- suppressWarnings(mock_cohortflow(50, seed = 1))
  crit <- cf_criteria() |> include(~ eligible_screen, label = "Screening")

  flow_no_h <- suppressMessages(apply_criteria(dat, crit))
  expect_null(flow_no_h$hierarchy)
  expect_null(flow_no_h$steps[[1]]$hierarchy_counts)

  flow_h <- make_flow_hierarchy()
  expect_s3_class(flow_h$hierarchy, "cf_hierarchy")
})

test_that("continue_criteria() preserves and continues hierarchy counting", {
  flow <- make_flow_hierarchy()
  more <- cf_criteria() |> include(~ !is.na(age), label = "Age still present")
  flow2 <- continue_criteria(flow, more)

  expect_s3_class(flow2$hierarchy, "cf_hierarchy")
  last_step <- flow2$steps[[length(flow2$steps)]]
  expect_false(is.null(last_step$hierarchy_counts))
})

# ---------------------------------------------------------------------------
# NA keys are not units (smoke-test 5b)

level_counts <- function(flow, step, level) {
  hc <- flow$steps[[step]]$hierarchy_counts
  hc[hc$level == level, ]
}

test_that("expected rows with no cluster add no phantom cluster", {
  dat <- mock_cluster_rct(n_participants = 50, seed = 1)
  exp <- data.frame(participant_id = c(dat$participant_id, "PX1", "PX2"))
  h   <- cf_hierarchy(participant = "participant_id", cluster = "cluster_id")
  crit <- cf_criteria() |>
    include(~ !is.na(cluster_id), label = "Has cluster") |>
    include(~ !is.na(age),        label = "Age recorded")
  flow <- suppressMessages(apply_criteria(dat, crit, id = "participant_id", expected = exp,
                                          by = "participant_id", hierarchy = h))

  cl1 <- level_counts(flow, 1L, "cluster")
  expect_equal(cl1$n_risk, length(unique(dat$cluster_id)))
  expect_equal(cl1$n_fail, 0L)
  pt1 <- level_counts(flow, 1L, "participant")
  expect_equal(pt1$n_risk, nrow(dat) + 2L)
  expect_equal(pt1$n_fail, 2L)
})

test_that("NA cluster_id in plain data is not counted as a cluster", {
  dat <- mock_cluster_rct(n_participants = 50, seed = 1)
  dat$cluster_id[1:5] <- NA
  h   <- cf_hierarchy(participant = "participant_id", cluster = "cluster_id")
  crit <- cf_criteria() |> include(~ !is.na(age), label = "Age recorded")
  flow <- apply_criteria(dat, crit, id = "participant_id", hierarchy = h)

  expect_equal(level_counts(flow, 1L, "cluster")$n_risk,
               length(unique(stats::na.omit(dat$cluster_id))))
  expect_equal(level_counts(flow, 1L, "participant")$n_risk, nrow(dat))
})

test_that("composite level ignores keys with an NA component", {
  dat <- mock_stepped_wedge(n_clusters = 4, n_participants = 40, n_periods = 3, seed = 1)
  dat$period[1] <- NA
  h <- cf_hierarchy(event = "event_id", cluster_period = c("cluster_id", "period"),
                    cluster = "cluster_id")
  crit <- cf_criteria() |> include(~ !is.na(age), label = "Age recorded")
  flow <- apply_criteria(dat, crit, id = "event_id", hierarchy = h)

  complete <- !is.na(dat$period)
  n_cp <- nrow(unique(dat[complete, c("cluster_id", "period")]))
  expect_equal(level_counts(flow, 1L, "cluster_period")$n_risk, n_cp)
  expect_equal(level_counts(flow, 1L, "cluster")$n_risk, length(unique(dat$cluster_id)))
  expect_equal(level_counts(flow, 1L, "event")$n_risk, nrow(dat))
})

test_that("as_attrition_tibble(levels =) header n matches corrected n_risk", {
  dat <- mock_cluster_rct(n_participants = 50, seed = 1)
  exp <- data.frame(participant_id = c(dat$participant_id, "PX1", "PX2"))
  h   <- cf_hierarchy(participant = "participant_id", cluster = "cluster_id")
  crit <- cf_criteria() |> include(~ !is.na(age), label = "Age recorded")
  flow <- suppressMessages(apply_criteria(dat, crit, id = "participant_id", expected = exp,
                                          by = "participant_id", hierarchy = h))
  tbl <- as_attrition_tibble(flow, levels = NULL)
  hdr <- tbl[tbl$row_type == "header", ]
  for (lvl in names(h)) {
    expect_equal(hdr$n[hdr$level == lvl], level_counts(flow, 1L, lvl)$n_risk, info = lvl)
  }
  expect_equal(hdr$n[hdr$level == "cluster"], length(unique(dat$cluster_id)))
})
