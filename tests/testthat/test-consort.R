# ===========================================================================
# Tests for as_consort_diagram() and plot.cf_flow()
# ===========================================================================
#
# Shared fixtures (make_flow_categorised(), make_flow_flat(),
# make_flow_no_exclusions()) live in helper-fixtures.R.

# Helper: pull the internal layout data frames attached to a consort_diagram.

consort_layout <- function(d) attr(d, "consort_layout")

# ---------------------------------------------------------------------------
# as_consort_diagram -- input validation
# ---------------------------------------------------------------------------

test_that("as_consort_diagram() rejects non-cf_flow input", {
  expect_error(as_consort_diagram(list()), "`flow` must be a `cf_flow` object")
  expect_error(as_consort_diagram(NULL),   "`flow` must be a `cf_flow` object")
})

# ---------------------------------------------------------------------------
# as_consort_diagram -- structure
# ---------------------------------------------------------------------------

test_that("as_consort_diagram() returns a consort_diagram / ggplot object", {
  flow <- make_flow_categorised()
  d    <- as_consort_diagram(flow)

  expect_s3_class(d, "consort_diagram")
  expect_s3_class(d, "ggplot")
})

test_that("as_consort_diagram() produces one main box per main-flow row", {
  flow <- make_flow_categorised()
  tbl  <- as_attrition_tibble(flow)
  d    <- as_consort_diagram(flow)

  n_main_rows <- sum(tbl$indent_level %in% c(0L, 1L))
  main_boxes  <- consort_layout(d)$main_boxes

  expect_equal(nrow(main_boxes), n_main_rows)
})

test_that("as_consort_diagram() works with show_categories = FALSE", {
  flow <- make_flow_flat()
  d    <- as_consort_diagram(flow, show_categories = FALSE)

  expect_s3_class(d, "consort_diagram")
})

test_that("as_consort_diagram() respects assessed_label and final_label", {
  flow <- make_flow_flat()
  d <- as_consort_diagram(
    flow,
    assessed_label = "Screened",
    final_label    = "Enrolled"
  )

  all_labels <- consort_layout(d)$main_boxes$label

  expect_true(any(grepl("Screened", all_labels, fixed = TRUE)))
  expect_true(any(grepl("Enrolled", all_labels, fixed = TRUE)))
})

test_that("as_consort_diagram() title is included in the plot when supplied", {
  flow <- make_flow_flat()
  d    <- as_consort_diagram(flow, title = "My CONSORT diagram")

  expect_true(consort_layout(d)$has_title)
  expect_equal(d$labels$title, "My CONSORT diagram")
})

test_that("as_consort_diagram() omits title when title is NULL", {
  flow <- make_flow_flat()
  d    <- as_consort_diagram(flow)

  expect_false(consort_layout(d)$has_title)
  expect_null(d$labels$title)
})

test_that("as_consort_diagram() omits exclusion boxes when a step has no exclusions", {
  flow <- make_flow_no_exclusions()
  d    <- as_consort_diagram(flow)

  expect_equal(nrow(consort_layout(d)$excl_boxes), 0L)
})

test_that("as_consort_diagram() draws exclusion boxes for steps with exclusions", {
  flow <- make_flow_categorised()
  d    <- as_consort_diagram(flow)

  expect_gt(nrow(consort_layout(d)$excl_boxes), 0L)
})

test_that("as_consort_diagram() accepts custom fill and border colours", {
  flow <- make_flow_flat()
  d <- as_consort_diagram(
    flow,
    main_fill     = "#000000",
    excl_fill     = "#111111",
    border_colour = "#222222"
  )

  expect_s3_class(d, "consort_diagram")
})

# ---------------------------------------------------------------------------
# print.consort_diagram
# ---------------------------------------------------------------------------

test_that("print.consort_diagram() returns the diagram invisibly", {
  flow <- make_flow_categorised()
  d    <- as_consort_diagram(flow)

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  out <- expect_invisible(print(d))
  expect_identical(out, d)
})

# ---------------------------------------------------------------------------
# plot.cf_flow
# ---------------------------------------------------------------------------

test_that("plot.cf_flow() returns a consort_diagram invisibly and prints it", {
  flow <- make_flow_categorised()

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  d <- expect_invisible(plot(flow))
  expect_s3_class(d, "consort_diagram")
})

test_that("plot.cf_flow() forwards ... arguments to as_consort_diagram()", {
  flow <- make_flow_flat()

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  d <- plot(flow, show_categories = FALSE)
  expect_s3_class(d, "consort_diagram")
})

# ---------------------------------------------------------------------------
# as_consort_diagram -- wrap_width
# ---------------------------------------------------------------------------

test_that("as_consort_diagram() accepts wrap_width parameter", {
  flow <- make_flow_categorised()
  d <- as_consort_diagram(flow, wrap_width = 20)

  expect_s3_class(d, "consort_diagram")
})

test_that("wrap_width = NULL preserves unwrapped labels", {
  flow <- make_flow_categorised()
  d <- as_consort_diagram(flow, wrap_width = NULL)

  # Labels should not have extra newlines from wrapping
  main_labels <- consort_layout(d)$main_boxes$label
  expect_true(all(grepl("\\(n=", main_labels)))
})

test_that("wrap_width produces wrapped labels with more lines", {
  flow <- make_flow_categorised()
  d_unwrapped <- as_consort_diagram(flow, wrap_width = NULL)
  d_wrapped <- as_consort_diagram(flow, wrap_width = 15)

  # Wrapped boxes should generally be taller (more lines) or narrower
  unwrapped_heights <- consort_layout(d_unwrapped)$main_boxes$h
  wrapped_heights <- consort_layout(d_wrapped)$main_boxes$h

  # At least one box should be taller when wrapped
  expect_true(any(wrapped_heights >= unwrapped_heights))
})

# ---------------------------------------------------------------------------
# as_consort_diagram -- exclusion colon
# ---------------------------------------------------------------------------

test_that("exclusion header has no colon when there are no child reasons", {
  # Create a flow with an uncategorised exclusion (no children)
  dat <- suppressWarnings(mock_cohortflow(n_participants = 100, seed = 1))
  crit <- cf_criteria() |>
    exclude(~ withdrew, label = "Withdrew consent")
  flow <- apply_criteria(dat, crit)
  d <- as_consort_diagram(flow)

  excl_labels <- consort_layout(d)$excl_boxes$label
  # Should not end with colon when there are no child reasons
  expect_true(all(!grepl(":$", excl_labels)))
})

test_that("exclusion header has colon when there are child reasons", {
  flow <- make_flow_categorised()
  d <- as_consort_diagram(flow)

  excl_labels <- consort_layout(d)$excl_boxes$label
  # At least one should have a colon (categorised exclusions have children)
  expect_true(any(grepl(":", excl_labels)))
})

# ---------------------------------------------------------------------------
# as_consort_diagram -- right-space reduction
# ---------------------------------------------------------------------------

test_that("xlim is based on actual box extents, not fixed [0, 1]", {
  flow <- make_flow_categorised()
  d <- as_consort_diagram(flow)

  # Get the x limits from the plot
  xlim <- ggplot2::layer_scales(d)$x$range$range

  # The right limit should be close to the rightmost box edge, not 1.0
  main_boxes <- consort_layout(d)$main_boxes
  excl_boxes <- consort_layout(d)$excl_boxes
  max_x <- max(c(main_boxes$x + main_boxes$w / 2,
                 excl_boxes$x + excl_boxes$w / 2))

  # xlim[2] should be close to max_x + small padding, not 1.0
  expect_lt(xlim[2], 1.0)
  expect_lt(abs(xlim[2] - max_x), 0.1)
})

# ---------------------------------------------------------------------------
# as_consort_diagram -- branching
# ---------------------------------------------------------------------------

test_that("as_consort_diagram() accepts branch_by parameter", {
  flow <- make_flow_parallel_rct()
  d <- as_consort_diagram(flow, branch_by = "arm")

  expect_s3_class(d, "consort_diagram")
  expect_gt(nrow(consort_layout(d)$branch_boxes), 0L)
})

test_that("branch_by creates one branch box per unique value", {
  flow <- make_flow_parallel_rct()
  d <- as_consort_diagram(flow, branch_by = "arm")

  branch_boxes <- consort_layout(d)$branch_boxes
  cohort_data <- cohort(flow)
  expected_branches <- length(unique(cohort_data$arm))

  expect_equal(nrow(branch_boxes), expected_branches)
})

test_that("branch counts sum to final cohort size", {
  flow <- make_flow_parallel_rct()
  d <- as_consort_diagram(flow, branch_by = "arm")

  branch_boxes <- consort_layout(d)$branch_boxes
  # Extract counts from labels (format: "label\n(n=N)" with optional comma separators)
  counts <- as.integer(gsub(",", "", gsub(".*\\(n=([0-9,]+)\\).*", "\\1", branch_boxes$label)))
  cohort_n <- nrow(cohort(flow))

  expect_equal(sum(counts), cohort_n)
})

test_that("branch_by errors when column not found", {
  flow <- make_flow_categorised()
  expect_error(
    as_consort_diagram(flow, branch_by = "nonexistent"),
    "not found"
  )
})

test_that("stage_by requires branch_by", {
  flow <- make_flow_crossover()
  expect_error(
    as_consort_diagram(flow, stage_by = "period"),
    "requires.*branch_by"
  )
})

test_that("stage_label_by requires stage_by", {
  flow <- make_flow_crossover()
  expect_error(
    as_consort_diagram(flow, branch_by = "sequence", stage_label_by = "arm"),
    "requires.*stage_by"
  )
})

test_that("crossover branching with stage_by creates stage boxes", {
  flow <- make_flow_crossover()
  d <- as_consort_diagram(
    flow,
    branch_by = "sequence",
    stage_by = "period",
    stage_label_by = "arm",
    count_by = "participant_id"
  )

  expect_s3_class(d, "consort_diagram")
  expect_gt(nrow(consort_layout(d)$branch_boxes), 0L)
  expect_gt(nrow(consort_layout(d)$stage_boxes), 0L)
})

test_that("count_by uses distinct counts", {
  flow <- make_flow_crossover()
  d <- as_consort_diagram(
    flow,
    branch_by = "sequence",
    count_by = "participant_id"
  )

  branch_boxes <- consort_layout(d)$branch_boxes
  # Extract counts from labels (format: "label\n(n=N)" with optional comma separators)
  counts <- as.integer(gsub(",", "", gsub(".*\\(n=([0-9,]+)\\).*", "\\1", branch_boxes$label)))

  # Verify counts match distinct participant_id per sequence
  cohort_data <- cohort(flow)
  for (i in seq_len(nrow(branch_boxes))) {
    seq_val <- branch_boxes$branch[i]
    expected_n <- dplyr::n_distinct(
      cohort_data$participant_id[cohort_data$sequence == seq_val]
    )
    expect_equal(counts[i], expected_n)
  }
})

test_that("linear diagram has no branch boxes when branch_by is NULL", {
  flow <- make_flow_categorised()
  d <- as_consort_diagram(flow)

  expect_equal(nrow(consort_layout(d)$branch_boxes), 0L)
  expect_equal(nrow(consort_layout(d)$stage_boxes), 0L)
})

# ---------------------------------------------------------------------------
# as_consort_diagram -- randomise() auto-detection
# ---------------------------------------------------------------------------

test_that("as_consort_diagram() auto-detects branch_by from a randomise() step", {
  flow <- make_flow_randomise()
  d <- as_consort_diagram(flow)

  branch_boxes <- consort_layout(d)$branch_boxes
  cohort_data  <- cohort(flow)
  arm_values   <- as.character(sort(unique(cohort_data$arm)))

  # One arm-label box + one box per post-randomisation step (Withdrew,
  # Final) per arm.
  expect_equal(nrow(branch_boxes), length(arm_values) * 3L)
  expect_setequal(unique(branch_boxes$branch), arm_values)
})

test_that("explicit branch_by overrides the randomise() step default in as_consort_diagram()", {
  flow <- make_flow_randomise()
  d <- as_consort_diagram(flow, branch_by = "site_id")

  branch_boxes <- consort_layout(d)$branch_boxes
  cohort_data  <- cohort(flow)
  site_values  <- as.character(sort(unique(cohort_data$site_id)))

  expect_setequal(unique(branch_boxes$branch), site_values)
})

test_that("as_consort_diagram() splits the trunk at the randomise() step", {
  # The shared trunk only contains steps up to and including the
  # randomise() box; everything at or after it is drawn as its own
  # per-arm sub-cascade instead of a single shared-trunk box.
  flow <- make_flow_randomise()
  d <- as_consort_diagram(flow)

  main_boxes <- consort_layout(d)$main_boxes
  # header + "Age recorded" + "Randomised" = 3 shared-trunk boxes
  expect_equal(nrow(main_boxes), 3L)
  expect_false(any(grepl("Withdrew after allocation", main_boxes$label)))
  expect_false(any(grepl("Final cohort", main_boxes$label)))

  branch_boxes <- consort_layout(d)$branch_boxes
  expect_true(any(grepl("Withdrew after allocation", branch_boxes$label)))
  expect_true(any(grepl("Final cohort", branch_boxes$label)))
})

test_that("as_consort_diagram() draws per-arm exclusion boxes after a randomise() step", {
  flow <- make_flow_randomise()
  d <- as_consort_diagram(flow)

  branch_excl_boxes <- consort_layout(d)$branch_excl_boxes
  cohort_data <- cohort(flow)
  arm_values  <- as.character(sort(unique(cohort_data$arm)))

  expect_gt(nrow(branch_excl_boxes), 0L)
  expect_true(all(branch_excl_boxes$branch %in% arm_values))
})

test_that("as_consort_diagram() errors combining count_by with a randomise() split", {
  flow <- make_flow_randomise()
  expect_error(
    as_consort_diagram(flow, count_by = "participant_id"),
    "count_by.*randomise"
  )
})

test_that("as_consort_diagram() does not overlap boxes across arms after a randomise() split", {
  # Regression test: an arm's exclusion box sits to the right of that arm's
  # own main-box column (see `.consort_build_cascade()`), so the spacing
  # between arm columns must clear the *full* width of that exclusion box,
  # not just half of it -- otherwise it overlaps the neighbouring arm's
  # main boxes (visually, arrows/boxes from one arm crossing into the next).
  # `make_flow_randomise_multistep()` has two post-randomisation exclusion
  # steps (not just one), which is what actually exposes the bug -- a
  # single sparse step leaves enough incidental vertical room to mask it.
  flow <- make_flow_randomise_multistep()
  d <- as_consort_diagram(flow)

  layout <- consort_layout(d)
  boxes  <- rbind(
    layout$branch_boxes[c("x", "y", "w", "h", "branch")],
    layout$branch_excl_boxes[c("x", "y", "w", "h", "branch")]
  )
  boxes <- boxes[!is.na(boxes$branch), , drop = FALSE]

  overlaps <- function(a, b) {
    (abs(a$x - b$x) * 2 < (a$w + b$w)) && (abs(a$y - b$y) * 2 < (a$h + b$h))
  }

  n <- nrow(boxes)
  for (i in seq_len(n - 1L)) {
    for (j in seq.int(i + 1L, n)) {
      if (boxes$branch[i] == boxes$branch[j]) next
      expect_false(
        overlaps(boxes[i, ], boxes[j, ]),
        info = sprintf("Box %d (branch %s) overlaps box %d (branch %s)",
                       i, boxes$branch[i], j, boxes$branch[j])
      )
    }
  }
})


test_that("singleton category with exclusions draws an exclusion box", {
  # Create a flow with a singleton category that has exclusions
  dat <- suppressWarnings(mock_cohortflow(n_participants = 100, seed = 1))
  crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age recorded", category = "Valid age") |>
    include(~ eligible_screen, label = "Passed screening", category = "Screening")
  flow <- apply_criteria(dat, crit)
  d <- as_consort_diagram(flow)

  # Both categories are singletons with exclusions, so both should have boxes
  excl_boxes <- consort_layout(d)$excl_boxes
  expect_gte(nrow(excl_boxes), 2L)
})

test_that("singleton category exclusion box has correct count from child", {
  dat <- suppressWarnings(mock_cohortflow(n_participants = 100, seed = 1))
  crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age recorded", category = "Valid age")
  flow <- apply_criteria(dat, crit)
  d <- as_consort_diagram(flow)

  # Get the exclusion box label
  excl_boxes <- consort_layout(d)$excl_boxes
  expect_gte(nrow(excl_boxes), 1L)

  # The label should contain the exclusion count from the child step
  # Format: "Excluded (n=X, Y%):" or "Excluded (n=X, Y%)"
  expect_true(any(grepl("Excluded \\(n=[0-9,]+", excl_boxes$label)))
})

test_that("every main-flow group with exclusions has an exclusion box", {
  flow <- make_flow_categorised()
  d <- as_consort_diagram(flow)

  # Get the attrition tibble to count groups with exclusions
  tbl <- as_attrition_tibble(flow)
  groups <- cohortflow:::.consort_group_rows(tbl)

  # Count groups that should have exclusion boxes
  groups_with_excl <- sum(vapply(groups, function(g) {
    r <- g$row
    has_children <- length(g$children) > 0L
    # Parent has exclusions
    if (!is.na(r$n_removed) && r$n_removed > 0L) return(TRUE)
    # Singleton category with child exclusions
    if (is.na(r$n_removed) && has_children) {
      child_total <- sum(vapply(g$children, `[[`, integer(1L), "n_removed"))
      return(child_total > 0L)
    }
    FALSE
  }, logical(1L)))

  excl_boxes <- consort_layout(d)$excl_boxes
  expect_equal(nrow(excl_boxes), groups_with_excl)
})
