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
