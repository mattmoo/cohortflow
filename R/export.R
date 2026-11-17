# Export a CONSORT diagram to a file ----------------------------------------

# File extensions accepted by `save_consort_diagram()`.
.consort_export_exts <- c("png", "tiff", "tif", "jpeg", "jpg", "pdf", "svg", "eps")

# Inches per layout unit at the default `text_size = 9`. Box widths and
# heights are computed from character and line counts (`.consort_box_dims()`:
# `char_w = 0.0105`, `line_h = 0.038`) in non-isotropic units, so the two
# axes need separate scales for 9 pt text to sit comfortably in its boxes.
.consort_in_per_x <- 8
.consort_in_per_y <- 4

# Natural size (inches) of a diagram: its layout extent scaled so the box
# text fits, plus room for the title. Falls back to 7 x 8 in if the panel
# ranges can't be read (e.g. a future ggplot2 changes `ggplot_build()`).
.consort_natural_size <- function(diagram) {
  layout <- attr(diagram, "consort_layout")
  text_size <- rlang::`%||%`(layout$text_size, 9)
  ranges <- tryCatch({
    pp <- ggplot2::ggplot_build(diagram)$layout$panel_params[[1]]
    c(diff(pp$x.range), diff(pp$y.range))
  }, error = function(e) NULL)
  if (!is.numeric(ranges) || length(ranges) != 2L || !all(is.finite(ranges) & ranges > 0)) {
    return(c(width = 7, height = 8))
  }
  scale <- text_size / 9
  width  <- ranges[1] * .consort_in_per_x * scale
  height <- ranges[2] * .consort_in_per_y * scale
  if (isTRUE(layout$has_title)) height <- height + 2 * (text_size + 3) / 72
  c(width = width, height = height)
}

# Graphics device for `ggplot2::ggsave()`: cairo PDF (embeds fonts) and SVG
# via svglite with a cairo fallback; `NULL` lets ggsave pick by extension
# (ragg for raster formats when installed).
.consort_export_device <- function(ext) {
  cairo <- isTRUE(unname(capabilities("cairo")))
  switch(ext,
    pdf = if (cairo) grDevices::cairo_pdf else grDevices::pdf,
    svg = if (requireNamespace("svglite", quietly = TRUE)) {
      svglite::svglite
    } else if (cairo) {
      grDevices::svg
    } else {
      rlang::abort("Saving to SVG needs the svglite package or a cairo-capable R build.")
    },
    NULL
  )
}

#' Save a CONSORT diagram for manuscript submission
#'
#' Writes a CONSORT flow diagram to a PNG, TIFF, JPEG, PDF, SVG or EPS file
#' via [ggplot2::ggsave()], with defaults suited to journal submission:
#' 300 dpi raster output, a white background, and a page size derived from
#' the diagram's layout so that box text fits its boxes.
#'
#' The file format is chosen from the extension of `path`. PNG, TIFF and
#' JPEG use the `ragg` devices when that package is installed (sharper,
#' anti-aliased text), otherwise the base [grDevices::png()] family. PDF uses
#' [grDevices::cairo_pdf()] when R has cairo support, which embeds fonts (so
#' a custom `font_family` renders correctly), otherwise [grDevices::pdf()].
#' SVG uses `svglite::svglite()` when installed, otherwise
#' [grDevices::svg()].
#'
#' When `width` and `height` are both `NULL`, the size is taken from the
#' diagram's layout so that `text_size`-point text fills its boxes, scaled
#' up proportionally for larger `text_size`. A longer pipeline therefore
#' produces a taller file. Supply only one of `width` / `height` to fix it
#' and keep the diagram's aspect ratio. Text is always drawn at
#' `text_size` points, so a size much smaller than the natural one will
#' overflow the boxes and a much larger one leaves them sparse. To fit a
#' wide diagram (e.g. a two-arm trial) on the page, build it with a smaller
#' `text_size` in [as_consort_diagram()]; the natural size shrinks in
#' proportion.
#'
#' @param diagram A `consort_diagram` from [as_consort_diagram()], or a
#'   `cf_flow`, which is drawn with `as_consort_diagram(diagram)`'s
#'   defaults. Build the diagram yourself to customise it.
#' @param path File to write. The extension (`.png`, `.tiff`/`.tif`,
#'   `.jpeg`/`.jpg`, `.pdf`, `.svg` or `.eps`, case-insensitive) picks the
#'   format.
#' @param width,height Plot size in `units`. `NULL` (default) derives it
#'   from the diagram layout; see Details.
#' @param units Units of `width` and `height`: `"in"`, `"cm"`, `"mm"` or
#'   `"px"`.
#' @param dpi Resolution for raster formats. Default `300`.
#' @param ... Further arguments passed to [ggplot2::ggsave()], e.g.
#'   `bg = "transparent"` (the default background is `"white"`) or
#'   `device =` to override the device choice.
#' @return `path`, invisibly.
#' @seealso [as_consort_diagram()]
#' @export
#'
#' @examples
#' dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ !is.na(age), label = "Age recorded") |>
#'   include(~ age >= 18,   label = "Adults only") |>
#'   exclude(~ withdrew,    label = "Withdrew consent")
#' flow <- apply_criteria(dat, crit)
#'
#' png_file <- tempfile(fileext = ".png")
#' save_consort_diagram(flow, png_file)
#'
#' pdf_file <- tempfile(fileext = ".pdf")
#' diagram <- as_consort_diagram(flow, title = "Participant flow")
#' save_consort_diagram(diagram, pdf_file, width = 6)
#' unlink(c(png_file, pdf_file))
save_consort_diagram <- function(diagram, path, width = NULL, height = NULL,
                                 units = c("in", "cm", "mm", "px"), dpi = 300, ...) {
  if (inherits(diagram, "cf_flow")) {
    diagram <- as_consort_diagram(diagram)
  }
  if (!inherits(diagram, "consort_diagram")) {
    rlang::abort("`diagram` must be a `consort_diagram` (from `as_consort_diagram()`) or a `cf_flow`.")
  }
  if (!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path)) {
    rlang::abort("`path` must be a single file name.")
  }
  units <- match.arg(units)
  ext <- tolower(tools::file_ext(path))
  if (!ext %in% .consort_export_exts) {
    rlang::abort(paste0(
      "Can't save a CONSORT diagram to `", path, "`: unsupported file extension",
      if (nzchar(ext)) paste0(" `.", ext, "`") else "", ".\n",
      "Use one of: ", paste0(".", .consort_export_exts, collapse = ", "), "."
    ))
  }
  for (arg in c("width", "height")) {
    val <- get(arg)
    if (!is.null(val) && (!is.numeric(val) || length(val) != 1L || !is.finite(val) || val <= 0)) {
      rlang::abort(paste0("`", arg, "` must be `NULL` or a single positive number."))
    }
  }

  if (is.null(width) || is.null(height)) {
    natural <- .consort_natural_size(diagram)
    to_units <- switch(units, `in` = 1, cm = 2.54, mm = 25.4, px = dpi)
    if (is.null(width) && is.null(height)) {
      width  <- natural[["width"]] * to_units
      height <- natural[["height"]] * to_units
    } else if (is.null(height)) {
      height <- width * natural[["height"]] / natural[["width"]]
    } else {
      width <- height * natural[["width"]] / natural[["height"]]
    }
  }

  args <- list(
    filename = path, plot = diagram, width = width, height = height,
    units = units, dpi = dpi, bg = "white", device = .consort_export_device(ext)
  )
  dots <- list(...)
  if (length(dots) > 0L && (is.null(names(dots)) || !all(nzchar(names(dots))))) {
    rlang::abort("Arguments in `...` must be named; they are passed to `ggplot2::ggsave()`.")
  }
  args[names(dots)] <- dots
  do.call(ggplot2::ggsave, args)
  invisible(path)
}
