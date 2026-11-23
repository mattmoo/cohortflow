# Save a CONSORT diagram for manuscript submission

Writes a CONSORT flow diagram to a PNG, TIFF, JPEG, PDF, SVG or EPS file
via
[`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html),
with defaults suited to journal submission: 300 dpi raster output, a
white background, and a page size derived from the diagram's layout so
that box text fits its boxes.

## Usage

``` r
save_consort_diagram(
  diagram,
  path,
  width = NULL,
  height = NULL,
  units = c("in", "cm", "mm", "px"),
  dpi = 300,
  ...
)
```

## Arguments

- diagram:

  A `consort_diagram` from
  [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md),
  or a `cf_flow`, which is drawn with `as_consort_diagram(diagram)`'s
  defaults. Build the diagram yourself to customise it.

- path:

  File to write. The extension (`.png`, `.tiff`/`.tif`, `.jpeg`/`.jpg`,
  `.pdf`, `.svg` or `.eps`, case-insensitive) picks the format.

- width, height:

  Plot size in `units`. `NULL` (default) derives it from the diagram
  layout; see Details.

- units:

  Units of `width` and `height`: `"in"`, `"cm"`, `"mm"` or `"px"`.

- dpi:

  Resolution for raster formats. Default `300`.

- ...:

  Further arguments passed to
  [`ggplot2::ggsave()`](https://ggplot2.tidyverse.org/reference/ggsave.html),
  e.g. `bg = "transparent"` (the default background is `"white"`) or
  `device =` to override the device choice.

## Value

`path`, invisibly.

## Details

The file format is chosen from the extension of `path`. PNG, TIFF and
JPEG use the `ragg` devices when that package is installed (sharper,
anti-aliased text), otherwise the base
[`grDevices::png()`](https://rdrr.io/r/grDevices/png.html) family. PDF
uses [`grDevices::cairo_pdf()`](https://rdrr.io/r/grDevices/cairo.html)
when R has cairo support, which embeds fonts (so a custom `font_family`
renders correctly), otherwise
[`grDevices::pdf()`](https://rdrr.io/r/grDevices/pdf.html). SVG uses
[`svglite::svglite()`](https://svglite.r-lib.org/reference/svglite.html)
when installed, otherwise
[`grDevices::svg()`](https://rdrr.io/r/grDevices/cairo.html).

When `width` and `height` are both `NULL`, the size is taken from the
diagram's layout so that `text_size`-point text fills its boxes, scaled
up proportionally for larger `text_size`. A longer pipeline therefore
produces a taller file. Supply only one of `width` / `height` to fix it
and keep the diagram's aspect ratio. Text is always drawn at `text_size`
points, so a size much smaller than the natural one will overflow the
boxes and a much larger one leaves them sparse. To fit a wide diagram
(e.g. a two-arm trial) on the page, build it with a smaller `text_size`
in
[`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md);
the natural size shrinks in proportion.

## See also

[`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md)

Other reporting:
[`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md),
[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md),
[`as_characteristics_table()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_table.md),
[`as_characteristics_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_tibble.md),
[`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md)

## Examples

``` r
dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
crit <- cf_criteria() |>
  include(~ !is.na(age), label = "Age recorded") |>
  include(~ age >= 18,   label = "Adults only") |>
  exclude(~ withdrew,    label = "Withdrew consent")
flow <- apply_criteria(dat, crit)
#> No `id` supplied and no `.cf_row_id` column found. Adding a sequential `.cf_row_id`.

png_file <- tempfile(fileext = ".png")
save_consort_diagram(flow, png_file)

pdf_file <- tempfile(fileext = ".pdf")
diagram <- as_consort_diagram(flow, title = "Participant flow")
save_consort_diagram(diagram, pdf_file, width = 6)
unlink(c(png_file, pdf_file))
```
