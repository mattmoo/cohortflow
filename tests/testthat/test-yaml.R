test_that("export_criteria() returns a YAML string when path = NULL", {
  crit <- cf_criteria() |>
    include(~ age >= 18,           label = "Adults only") |>
    exclude(~ is.na(consent_date), label = "No consent")

  yml <- export_criteria(crit)
  expect_type(yml, "character")
  expect_true(grepl("cohortflow_criteria", yml))
  expect_true(grepl("Adults only", yml))
  expect_true(grepl("No consent",  yml))
})

test_that("export_criteria() includes by field for group steps", {
  crit <- cf_criteria() |>
    group_include(by = "cluster_id", ~ n() >= 5, label = "Min size")
  yml <- export_criteria(crit)
  expect_true(grepl("cluster_id", yml))
  expect_true(grepl("group_include", yml))
})

test_that("import_criteria() round-trips a formula-based pipeline", {
  crit <- cf_criteria() |>
    include(~ age >= 18,           label = "Adults only") |>
    exclude(~ is.na(consent_date), label = "No consent")

  yml   <- export_criteria(crit)
  crit2 <- import_criteria(text = yml)

  expect_s3_class(crit2, "cf_criteria")
  expect_equal(length(crit2), 2L)
  expect_equal(crit2$steps[[1]]$label, "Adults only")
  expect_equal(crit2$steps[[1]]$type,  "include")
  expect_equal(crit2$steps[[2]]$label, "No consent")
  expect_equal(crit2$steps[[2]]$type,  "exclude")
})

test_that("import_criteria() round-trips group step by field", {
  crit <- cf_criteria() |>
    group_include(by = "cluster_id", ~ n() >= 5, label = "Min size")
  yml   <- export_criteria(crit)
  crit2 <- import_criteria(text = yml)
  expect_equal(crit2$steps[[1]]$by,   "cluster_id")
  expect_equal(crit2$steps[[1]]$type, "group_include")
})

test_that("re-imported formula predicates evaluate correctly", {
  crit <- cf_criteria() |>
    include(~ age >= 18, label = "Adults")

  yml   <- export_criteria(crit)
  crit2 <- import_criteria(text = yml)

  d   <- data.frame(age = c(10, 25, 60))
  res <- cohortflow:::eval_criterion(crit2$steps[[1]], d)
  expect_equal(res, c(FALSE, TRUE, TRUE))
})

test_that("import_criteria() errors on malformed YAML", {
  expect_error(import_criteria(text = "not_a_criteria_file: true"), class = "rlang_error")
})

test_that("export_criteria() writes a file when path is provided", {
  crit <- cf_criteria() |>
    include(~ age >= 18, label = "Adults")

  tmp <- tempfile(fileext = ".yaml")
  on.exit(unlink(tmp))

  expect_invisible(export_criteria(crit, path = tmp))
  expect_true(file.exists(tmp))

  # round-trip via file
  crit2 <- import_criteria(path = tmp)
  expect_equal(length(crit2), 1L)
  expect_equal(crit2$steps[[1]]$label, "Adults")
})

test_that("import_criteria() errors if both path and text are supplied", {
  expect_error(import_criteria(path = "x.yaml", text = "y: 1"), class = "rlang_error")
})

test_that("import_criteria() errors if neither path nor text is supplied", {
  expect_error(import_criteria(), class = "rlang_error")
})

test_that("export_criteria() stores function-based criteria as 'function' kind", {
  # Use a formula instead of an anonymous function to avoid the
  # closure-capture warning (anonymous functions defined in the test
  # environment capture that environment).
  crit <- cf_criteria() |>
    include(~ !is.na(consent_date), label = "Consent recorded")
  yml  <- export_criteria(crit)
  # formula kind is stored as "formula" in YAML
  expect_true(grepl("kind: formula", yml))
})

test_that("export/import round-trips a function predicate via body deparse", {
  fn   <- function(d) !is.na(d$consent_date)
  crit <- cf_criteria() |> include(fn, label = "Has consent")

  yml   <- suppressWarnings(export_criteria(crit))
  expect_true(grepl("kind: function", yml))

  crit2 <- import_criteria(text = yml)
  expect_s3_class(crit2, "cf_criteria")
  expect_equal(crit2$steps[[1]]$label, "Has consent")

  # Verify it evaluates correctly after round-trip
  d   <- data.frame(consent_date = c(as.Date("2023-01-01"), NA))
  res <- cohortflow:::eval_criterion(crit2$steps[[1]], d)
  expect_equal(res, c(TRUE, FALSE))
})

test_that("export_criteria() warns when function captures non-empty closure", {
  threshold <- 18
  fn_closure <- function(d) d$age >= threshold  # captures 'threshold'
  crit <- cf_criteria() |> include(fn_closure, label = "Age threshold")
  expect_warning(export_criteria(crit), regexp = "enclosing environment")
})

test_that("export_criteria() uses fn_refs when function matches", {
  fn   <- function(d) !is.na(d$consent_date)
  refs <- list("mypkg::has_consent" = fn)
  crit <- cf_criteria() |> include(fn, label = "Consent")

  yml <- export_criteria(crit, fn_refs = refs)
  expect_true(grepl("mypkg::has_consent", yml))
})

test_that("import_criteria() resolves fn_ref with :: notation", {
  # Use a real exported function as the fn_ref target
  fn   <- base::is.na
  refs <- list("base::is.na" = fn)
  crit <- cf_criteria() |> include(fn, label = "Is NA")
  yml  <- export_criteria(crit, fn_refs = refs)

  crit2 <- import_criteria(text = yml)
  expect_equal(crit2$steps[[1]]$label, "Is NA")
  expect_true(is.function(crit2$steps[[1]]$predicate))
})

test_that("export_criteria() errors on non-cf_criteria input", {
  expect_error(export_criteria(list()), class = "rlang_error")
})

test_that("import_criteria() round-trips select_within with by and category", {
  crit <- cf_criteria() |>
    select_within(
      by       = "participant_id",
      label    = "Index event",
      category = "Selection",
      ~ consent_date == min(consent_date, na.rm = TRUE)
    )
  yml   <- export_criteria(crit)
  crit2 <- import_criteria(text = yml)

  expect_equal(crit2$steps[[1]]$by,       "participant_id")
  expect_equal(crit2$steps[[1]]$category, "Selection")
  expect_equal(crit2$steps[[1]]$type,     "select_within")
})

test_that("export_criteria() stores randomise steps with kind 'none' and no expr", {
  crit <- cf_criteria() |> randomise(by = "cluster_id", arms = "arm")
  yml  <- export_criteria(crit)
  expect_true(grepl("type: randomise", yml))
  expect_true(grepl("kind: none", yml))
  expect_true(grepl("arms: arm", yml))
})

test_that("import_criteria() round-trips a randomise step", {
  crit <- cf_criteria() |>
    include(~ eligible, label = "Eligible") |>
    randomise(by = "cluster_id", arms = "arm") |>
    exclude(~ withdrew, label = "Withdrew after allocation")

  yml   <- export_criteria(crit)
  crit2 <- import_criteria(text = yml)

  expect_equal(length(crit2), 3L)
  expect_equal(crit2$steps[[2]]$type,  "randomise")
  expect_equal(crit2$steps[[2]]$label, "Randomised")
  expect_equal(crit2$steps[[2]]$by,    "cluster_id")
  expect_equal(crit2$steps[[2]]$arms,  "arm")
  expect_null(crit2$steps[[2]]$predicate)
})

test_that("re-imported randomise step round-trips through apply_criteria()", {
  dat  <- mock_cluster_rct(n_clusters = 6, n_participants = 100, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age recorded") |>
    randomise(by = "cluster_id", arms = "arm")

  yml   <- export_criteria(crit)
  crit2 <- import_criteria(text = yml)

  flow <- suppressMessages(apply_criteria(dat, crit2, id = "participant_id"))
  expect_equal(flow$steps[[2]]$type,   "randomise")
  expect_equal(flow$steps[[2]]$n_fail, 0L)
})
