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

test_that("export_criteria() includes hierarchy when set", {
  h <- cf_hierarchy(participant = "pid", cluster = "cid")
  crit <- cf_criteria() |>
    set_hierarchy(h) |>
    include(~ age >= 18, label = "Adults")

  yml <- export_criteria(crit)
  expect_true(grepl("hierarchy", yml))
  expect_true(grepl("participant", yml))
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

test_that("import_criteria() round-trips the hierarchy", {
  h <- cf_hierarchy(participant = "pid", cluster = "cid")
  crit <- cf_criteria() |>
    set_hierarchy(h) |>
    include(~ age >= 18, label = "Adults")

  yml   <- export_criteria(crit)
  crit2 <- import_criteria(text = yml)

  expect_s3_class(crit2$hierarchy, "cf_hierarchy")
  expect_equal(unname(crit2$hierarchy["participant"]), "pid")
  expect_equal(unname(crit2$hierarchy["cluster"]),    "cid")
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
