make_export_flow <- function(n_steps) {
  dat <- mock_parallel_rct(n_participants = 120, seed = 3)
  crit <- cf_criteria()
  for (i in seq_len(n_steps)) {
    crit <- include(crit, ~ !is.na(age), label = paste("Criterion", i))
  }
  suppressMessages(apply_criteria(dat, crit))
}

expect_nonempty_file <- function(path) {
  testthat::expect_true(file.exists(path))
  testthat::expect_gt(file.size(path), 0)
}

# Pixel width and height from a PNG's IHDR chunk (bytes 17-24, big-endian).
png_dims <- function(path) {
  bytes <- as.integer(readBin(path, "raw", n = 24L))
  be32 <- function(b) sum(b * 256^(3:0))
  c(width = be32(bytes[17:20]), height = be32(bytes[21:24]))
}

test_that("save_consort_diagram() writes PNG and PDF and returns path invisibly", {
  d <- as_consort_diagram(make_export_flow(2))
  for (ext in c(".png", ".pdf")) {
    path <- withr::local_tempfile(fileext = ext)
    expect_invisible(out <- save_consort_diagram(d, path))
    expect_identical(out, path)
    expect_nonempty_file(path)
  }
})

test_that("PDF export falls back to pdf() when cairo will not load", {
  local_mocked_bindings(.cairo_usable = function() FALSE)
  expect_identical(.consort_export_device("pdf"), grDevices::pdf)
  path <- withr::local_tempfile(fileext = ".pdf")
  save_consort_diagram(as_consort_diagram(make_export_flow(2)), path)
  expect_nonempty_file(path)
})

test_that(".cairo_usable() leaves the open devices unchanged", {
  before <- grDevices::dev.list()
  expect_type(.cairo_usable(), "logical")
  expect_identical(grDevices::dev.list(), before)
})

test_that("save_consort_diagram() writes SVG", {
  has_svg <- requireNamespace("svglite", quietly = TRUE) || isTRUE(unname(capabilities("cairo")))
  skip_if_not(has_svg, "needs svglite or cairo")
  path <- withr::local_tempfile(fileext = ".svg")
  save_consort_diagram(as_consort_diagram(make_export_flow(2)), path)
  expect_nonempty_file(path)
  expect_match(readLines(path, n = 5L, warn = FALSE), "<svg", all = FALSE)
})

test_that("save_consort_diagram() accepts a cf_flow", {
  path <- withr::local_tempfile(fileext = ".png")
  save_consort_diagram(make_export_flow(2), path)
  expect_nonempty_file(path)
})

test_that("save_consort_diagram() is silent", {
  path <- withr::local_tempfile(fileext = ".png")
  expect_silent(save_consort_diagram(as_consort_diagram(make_export_flow(2)), path))
})

test_that("unsupported or missing extensions error naming the supported ones", {
  d <- as_consort_diagram(make_export_flow(2))
  expect_error(save_consort_diagram(d, "diagram.docx"), "\\.docx.*\\.png.*\\.pdf.*\\.svg", class = "rlang_error")
  expect_error(save_consort_diagram(d, "diagram"), "Use one of: \\.png", class = "rlang_error")
})

test_that("invalid inputs error", {
  d <- as_consort_diagram(make_export_flow(2))
  expect_error(save_consort_diagram(mtcars, "x.png"), "consort_diagram", class = "rlang_error")
  expect_error(save_consort_diagram(d, c("a.png", "b.png")), "single file name", class = "rlang_error")
  expect_error(save_consort_diagram(d, "x.png", width = -1), "`width`", class = "rlang_error")
  expect_error(save_consort_diagram(d, "x.png", height = "4"), "`height`", class = "rlang_error")
  expect_error(save_consort_diagram(d, "x.png", units = "ft"))
  expect_error(save_consort_diagram(d, "x.png", 5, 4, "in", 300, "white"), "must be named", class = "rlang_error")
})

test_that("auto-sized height grows with the number of steps", {
  short <- .consort_natural_size(as_consort_diagram(make_export_flow(2)))
  long  <- .consort_natural_size(as_consort_diagram(make_export_flow(8)))
  expect_gt(long[["height"]], short[["height"]])
  expect_true(all(short > 0))
})

test_that("auto size scales with text_size and allows for a title", {
  flow <- make_export_flow(2)
  base   <- .consort_natural_size(as_consort_diagram(flow))
  big    <- .consort_natural_size(as_consort_diagram(flow, text_size = 18))
  titled <- .consort_natural_size(as_consort_diagram(flow, title = "Flow"))
  expect_equal(unname(big), unname(base) * 2)
  expect_equal(titled[["width"]], base[["width"]])
  expect_gt(titled[["height"]], base[["height"]])
})

test_that("supplying one dimension keeps the natural aspect ratio", {
  d <- as_consort_diagram(make_export_flow(4))
  natural <- .consort_natural_size(d)
  path <- withr::local_tempfile(fileext = ".png")
  save_consort_diagram(d, path, width = 6, dpi = 100)
  expected <- c(width = 600, height = 600 * natural[["height"]] / natural[["width"]])
  expect_equal(png_dims(path), expected, tolerance = 0.01)
})

test_that("auto size is converted to the requested units", {
  d <- as_consort_diagram(make_export_flow(2))
  natural <- .consort_natural_size(d)
  path <- withr::local_tempfile(fileext = ".png")
  save_consort_diagram(d, path, units = "px", dpi = 100)
  expect_equal(png_dims(path), natural * 100, tolerance = 0.01)
})
