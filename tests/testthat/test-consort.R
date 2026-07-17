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
# print.consort_diagram()
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
# plot.cf_flow()
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
