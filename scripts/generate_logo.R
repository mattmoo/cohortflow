# Generate the cohortflow hex logo.
#
# Writes man/figures/logo.svg, renders man/figures/logo.png from it, and
# rebuilds the pkgdown favicons in pkgdown/favicon/. Run from the package root:
#
#   Rscript scripts/generate_logo.R
#
# The logo is a small CONSORT cascade: each white box holds the cohort at that
# step (one dot per participant), and the participants removed at each step
# branch off to a dashed box on the right. Everything is laid out from the
# parameters below, so changing `cohort` redraws the whole thing.
#
# The wordmark is set in Inter, embedded in the SVG as a subset fetched from
# Google Fonts, so the script needs an internet connection (as does
# build_favicons()). PNG rendering uses headless Chrome (set the CHROME
# environment variable if it is not in a standard location), falling back to
# rsvg, which ignores embedded fonts.

# ---- Parameters -------------------------------------------------------------

cohort <- c(6, 4, 3) # dots in each cohort box, top to bottom

pal <- list(
  fill      = "#0B6E69", # site primary colour (_pkgdown.yml)
  border    = "#073F3C",
  box       = "#FFFFFF",
  dot       = "#0B6E69",
  excluded  = "#F2A541",
  line      = "#FFFFFF",
  text      = "#FFFFFF"
)

hex_height   <- 600 # pointy-top hexagon; width follows
hex_stroke   <- 16

dot_r        <- 11
dot_gap      <- 30   # centre-to-centre spacing of dots
box_pad      <- 30   # from the outer dot centres to the box edge
box_h        <- 56
box_rx       <- 12
row_step     <- 110  # vertical distance between cohort boxes
first_box_y  <- 125
column_x     <- 210  # centre line of the cohort boxes

excl_x       <- 348  # left edge of the exclusion boxes
excl_w       <- 90
excl_h       <- 44
arrow_gap    <- 7    # gap between an arrow tip and the box it points at

wordmark      <- "cohortflow"
wordmark_y    <- 476
wordmark_size <- 62
wordmark_track <- -1.5 # letter-spacing, px
font_name     <- "Inter"
font_weight   <- 700
font_family   <- paste(font_name, "Segoe UI, Helvetica Neue, Arial, sans-serif", sep = ", ")

svg_path <- "man/figures/logo.svg"
png_path <- "man/figures/logo.png"

# ---- Helpers ----------------------------------------------------------------

fmt <- function(x) as.character(round(x, 1))

# One SVG element per element of the longest attribute (shorter ones recycle).
tag <- function(name, ..., .content = NULL) {
  attrs <- list(...)
  vapply(seq_len(max(lengths(attrs))), function(i) {
    vals <- vapply(attrs, function(v) {
      v <- v[[(i - 1) %% length(v) + 1]]
      if (is.numeric(v)) fmt(v) else as.character(v)
    }, "")
    a <- paste0(" ", names(vals), '="', vals, '"', collapse = "")
    if (is.null(.content)) paste0("<", name, a, "/>")
    else paste0("<", name, a, ">", .content, "</", name, ">")
  }, "")
}

dots <- function(n, cx, cy, fill) {
  xs <- cx + (seq_len(n) - (n + 1) / 2) * dot_gap
  vapply(xs, function(x) tag("circle", cx = x, cy = cy, r = dot_r, fill = fill), "")
}

# An SVG used as an <img> cannot load web fonts, and few viewers have Inter
# installed, so embed it: Google Fonts serves a subset holding only the glyphs
# in `text`, which keeps it to a couple of KB.
embed_font <- function(family, weight, text) {
  ua <- c(`User-Agent` = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0 Safari/537.36")
  css_url <- sprintf("https://fonts.googleapis.com/css2?family=%s:wght@%d&text=%s",
                     utils::URLencode(family), weight, utils::URLencode(text, reserved = TRUE))
  con <- url(css_url, headers = ua)
  css <- paste(readLines(con, warn = FALSE), collapse = "\n")
  close(con)
  font_url <- regmatches(css, regexpr("https://fonts\\.gstatic\\.com/[^)]+", css))
  if (!length(font_url)) stop("No font URL in Google Fonts response:\n", css)
  tmp <- tempfile(fileext = ".woff2")
  utils::download.file(font_url, tmp, mode = "wb", quiet = TRUE, headers = ua)
  b64 <- jsonlite::base64_enc(readBin(tmp, "raw", file.size(tmp)))
  b64 <- gsub("\\s", "", b64)
  sprintf(paste0("@font-face{font-family:'%s';font-weight:%d;",
                 "src:url(data:font/woff2;base64,%s) format('woff2');}"),
          family, weight, b64)
}

# Pointy-top hexagon whose outer stroke edge spans the full height.
hexagon <- function(height, stroke) {
  r_outer <- height / 2
  r <- r_outer - (stroke / 2) / cos(pi / 6)
  cx <- r_outer * cos(pi / 6)
  cy <- r_outer
  angles <- pi / 2 + (0:5) * pi / 3
  pts <- paste(fmt(cx + r * cos(angles)), fmt(cy - r * sin(angles)), sep = ",", collapse = " ")
  list(
    width = 2 * cx,
    svg = tag("polygon", points = pts, fill = pal$fill, stroke = pal$border,
              `stroke-width` = stroke, `stroke-linejoin` = "round")
  )
}

# ---- Layout -----------------------------------------------------------------

stopifnot(all(diff(cohort) <= 0), length(cohort) >= 2)
excluded <- -diff(cohort)
n_steps  <- length(cohort)

hex <- hexagon(hex_height, hex_stroke)

box_y   <- first_box_y + (seq_len(n_steps) - 1) * row_step
box_w   <- (cohort - 1) * dot_gap + 2 * box_pad
box_mid <- box_y + box_h / 2

# One branch per transition, halfway down the connecting line.
branch_y <- (box_y[-n_steps] + box_h + box_y[-1]) / 2

lines <- c(
  sprintf("M%s,%s V%s", fmt(column_x), fmt(box_y[-n_steps] + box_h), fmt(box_y[-1] - arrow_gap)),
  sprintf("M%s,%s H%s", fmt(column_x), fmt(branch_y), fmt(excl_x - arrow_gap))
)

body <- c(
  "  <!-- hexagon -->",
  paste0("  ", hex$svg),
  "  <!-- flow lines -->",
  paste0('  <g stroke="', pal$line, '" stroke-width="5" fill="none" stroke-linecap="round">'),
  paste0("    ", vapply(lines, function(d) tag("path", d = d, `marker-end` = "url(#arr)"), "")),
  "  </g>",
  "  <!-- cohort boxes, narrowing -->",
  paste0("  ", tag("rect", x = column_x - box_w / 2, y = box_y, width = box_w, height = box_h,
                   rx = box_rx, fill = pal$box)),
  paste0("  ", unlist(Map(dots, cohort, column_x, box_mid, pal$dot))),
  "  <!-- exclusion boxes -->",
  paste0("  ", tag("rect", x = excl_x, y = branch_y - excl_h / 2, width = excl_w, height = excl_h,
                   rx = 10, fill = pal$box, `fill-opacity` = 0.1, stroke = pal$box,
                   `stroke-width` = 3, `stroke-dasharray` = "7 5")),
  paste0("  ", unlist(Map(dots, excluded, excl_x + excl_w / 2, branch_y, pal$excluded))),
  "  <!-- name -->",
  paste0("  ", tag("text", x = hex$width / 2, y = wordmark_y, `text-anchor` = "middle",
                   `font-family` = font_family, `font-size` = wordmark_size, `font-weight` = font_weight,
                   `letter-spacing` = wordmark_track, fill = pal$text, .content = wordmark))
)

svg <- c(
  sprintf(paste0('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %s %s" width="%s" height="%s"',
                 ' role="img" aria-labelledby="t">'),
          fmt(hex$width), hex_height, fmt(hex$width), hex_height),
  '  <title id="t">cohortflow</title>',
  "  <defs>",
  paste0("    <style>", embed_font(font_name, font_weight, wordmark), "</style>"),
  paste0('    <marker id="arr" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="5" markerHeight="5"',
         ' orient="auto">'),
  paste0('      <path d="M0,0 L10,5 L0,10 z" fill="', pal$line, '"/>'),
  "    </marker>",
  "  </defs>",
  body,
  "</svg>"
)

writeLines(svg, svg_path)
message("Wrote ", svg_path)

# ---- PNG --------------------------------------------------------------------

png_w <- round(hex$width)
png_h <- hex_height

find_chrome <- function() {
  candidates <- c(
    Sys.getenv("CHROME"),
    "C:/Program Files/Google/Chrome/Application/chrome.exe",
    "C:/Program Files (x86)/Google/Chrome/Application/chrome.exe",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    Sys.which(c("google-chrome", "chromium", "chromium-browser"))
  )
  candidates <- candidates[nzchar(candidates) & file.exists(candidates)]
  if (length(candidates)) candidates[[1]] else NULL
}

if (!is.null(chrome <- find_chrome())) {
  html <- tempfile(fileext = ".html")
  svg_url <- paste0("file:///", normalizePath(svg_path, winslash = "/"))
  writeLines(sprintf(
    '<html><body style="margin:0"><img src="%s" width="%d" height="%d" style="display:block"></body></html>',
    svg_url, png_w, png_h
  ), html)
  status <- system2(chrome, c(
    "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
    "--default-background-color=00000000", "--force-device-scale-factor=1",
    sprintf("--window-size=%d,%d", png_w, png_h),
    shQuote(paste0("--screenshot=", normalizePath(png_path, winslash = "/", mustWork = FALSE))),
    shQuote(paste0("file:///", normalizePath(html, winslash = "/")))
  ), stdout = FALSE, stderr = FALSE)
  if (status != 0 || !file.exists(png_path)) stop("Chrome failed to render ", png_path)
  message("Wrote ", png_path, " (headless Chrome)")
} else if (requireNamespace("rsvg", quietly = TRUE)) {
  rsvg::rsvg_png(svg_path, png_path, width = png_w, height = png_h)
  warning("Rendered ", png_path, " with rsvg, which ignores the embedded font; ",
          "the wordmark will use a fallback font. Install Chrome for an exact render.")
} else {
  warning("Neither rsvg nor Chrome found; ", png_path, " not updated.")
}

# ---- Favicons ---------------------------------------------------------------

if (requireNamespace("pkgdown", quietly = TRUE)) {
  pkgdown::build_favicons(overwrite = TRUE)
}
