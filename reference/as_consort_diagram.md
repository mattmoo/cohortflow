# Build a CONSORT flow diagram from a cohort flow object

Produces a CONSORT-style flow diagram (as used in clinical trial and
cohort study reporting) summarising participant flow through a `cf_flow`
pipeline. The main vertical flow shows the number of participants
entering the study and surviving each step (or category, when
`show_categories = TRUE`), while exclusions at each step branch off to
the side as a box giving the count, percentage, and (for categorised
steps) the individual exclusion reasons.

## Usage

``` r
as_consort_diagram(
  flow,
  show_categories = TRUE,
  assessed_label = "Assessed for eligibility",
  final_label = "Final cohort",
  digits = 1L,
  main_fill = NA,
  excl_fill = NA,
  border_colour = "black",
  border_linewidth = 0.5,
  text_size = 9,
  text_colour = "#222222",
  font_family = "",
  arrow_size = 0.06,
  title = NULL,
  title_colour = text_colour,
  wrap_width = NULL,
  big_mark = ",",
  branch_by = NULL,
  stage_by = NULL,
  stage_label_by = NULL,
  count_by = NULL,
  branch_na_label = "Missing",
  remaining_label = "Remaining"
)
```

## Arguments

- flow:

  A `cf_flow` object produced by
  [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md).

- show_categories:

  Logical. When `TRUE` (default) steps with the same `category` are
  collapsed under a single parent row. When `FALSE` one row per step is
  produced.

- assessed_label:

  Character string for the header row. Default
  `"Assessed for eligibility"`.

- final_label:

  Character string for the trailing final-cohort row. Default
  `"Final cohort"`.

- digits:

  Integer. Number of decimal places for `pct_removed`. Default `1`.
  Formatted tables and diagrams keep trailing zeros (`"10.0%"`).

- main_fill:

  Fill colour for main-flow boxes. Default `NA` (no fill / transparent),
  keeping the diagram colourless unless a fill is explicitly supplied.

- excl_fill:

  Fill colour for exclusion (side) boxes. Default `NA` (no fill /
  transparent).

- border_colour:

  Border colour for all boxes and arrows. Default `"#000000"` (black).

- border_linewidth:

  Line width for all box borders and arrows, passed on to
  [`ggplot2::geom_rect()`](https://ggplot2.tidyverse.org/reference/geom_tile.html)
  /
  [`ggplot2::geom_segment()`](https://ggplot2.tidyverse.org/reference/geom_segment.html).
  Default `0.5` (the `ggplot2` default line width).

- text_size:

  Font size (points) for box text. Default `9`.

- text_colour:

  Colour for all box text (and the title, unless `title_colour` is
  supplied). Default `"#222222"`.

- font_family:

  Font family for all box text and the title. Default `""` (the device's
  default font family).

- arrow_size:

  Length (in inches) of arrowheads on connector lines, passed to
  [`grid::arrow()`](https://rdrr.io/r/grid/arrow.html). Default `0.06`
  (smaller than the historical default of `0.1`, which looked oversized
  relative to typical box sizes).

- title:

  Optional plot title drawn above the diagram. Default `NULL` (no
  title).

- title_colour:

  Colour for the title text. Default `text_colour`.

- wrap_width:

  Optional integer. Maximum character width for wrapping text in boxes.
  When `NULL` (default), text is not wrapped. When a positive integer,
  each line in a box label is wrapped to at most that many characters
  using word-boundary wrapping.

- big_mark:

  Character string used as the thousands-separator when formatting
  counts in box labels (e.g. `"1,234"` with the default `","`). Pass
  `""` to disable grouping (e.g. `"1234"`).

- branch_by:

  Optional column name (string) for allocation branching. When `NULL`
  (default), the diagram is linear unless the pipeline has a
  [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
  step, in which case its `arms` column is used automatically. When the
  pipeline has a
  [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
  step, the diagram is drawn as one shared trunk up to and including the
  randomisation box, which then splits (via a right-angle "elbow"
  connector) into one independent column of main boxes per arm for every
  step at or after randomisation – so post-allocation exclusions are
  shown as per-arm sub-cascades rather than shared-trunk boxes. When
  there is no
  [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
  step, the surviving cohort is instead split by this column and a
  single box per branch is drawn below the final common-flow box (the
  historical behaviour), connected the same way. Use
  `final_label = "Randomised"` when appropriate.

- stage_by:

  Optional column name (string) for ordered stages within each branch
  (e.g. crossover `period`). When `NULL` (default), no stage-specific
  nodes are drawn.

- stage_label_by:

  Optional column name (string) providing labels for each stage (e.g.
  crossover `arm`). Ignored when `stage_by` is `NULL`.

- count_by:

  Optional hierarchy level to count instead of rows: a level name from
  the flow's
  [`cf_hierarchy()`](https://mattmoo.github.io/cohortflow/reference/cf_hierarchy.md),
  or the column of a single-column level (e.g. `"participant_id"`).
  Every box, trunk, arms and stages, then counts distinct units, so a
  crossover trial reports participants rather than participant-periods
  throughout. Requires `apply_criteria(hierarchy = )`; see
  [`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md).

- branch_na_label:

  Character string used to label the branch formed by `NA` values in
  `branch_by` (and, in `as_consort_diagram()`, the stage formed by `NA`
  values in `stage_by`). Default `"Missing"`. Ignored when the column
  has no `NA` values.

- remaining_label:

  Text for the main box below an uncategorised
  [`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md)
  or
  [`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md)
  step. That step's label describes the rows it removed, so it appears
  in the exclusion box beside the number removed, and the main box shows
  this text beside the number remaining. Default `"Remaining"`.

## Value

A `consort_diagram` object (a `ggplot2` `ggplot`), drawable via
[`print()`](https://rdrr.io/r/base/print.html). The underlying box/arrow
layout data frames are available via `attr(x, "consort_layout")` for
introspection or custom rendering.

## Details

This uses the same underlying data layer as
[`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md)
–
[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
– so the row structure (header, category, step, final) is identical
across all three output types.

The returned object is a
[`ggplot2::ggplot()`](https://ggplot2.tidyverse.org/reference/ggplot.html)
plot (with an additional `consort_diagram` class), so it can be drawn
with [`print()`](https://rdrr.io/r/base/print.html), combined with `+`
and further `ggplot2` layers/themes, or written to a PNG, TIFF, PDF, SVG
or EPS file sized to fit its layout with
[`save_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/save_consort_diagram.md).

## Box text

Each main box shows the number remaining after its step, and each
exclusion box the number removed, each beside text describing those
rows:

- An uncategorised
  [`include()`](https://mattmoo.github.io/cohortflow/reference/include.md)-type
  step keeps its label on the main box ("Aged 18 or over (n=194)"). Its
  exclusion box shows the step's `reason` if set ("Under 18 (n=6)"),
  else "Excluded (n=6)".

- An uncategorised
  [`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md)-type
  step's label goes in the exclusion box ("Withdrew consent (n=4)") and
  the main box reads `remaining_label` ("Remaining (n=118)").

- A category's main box shows the category name. Its exclusion box lists
  each step by `reason`, falling back to the label; an inclusion step
  without a `reason` reads backwards there, so this case warns (at most
  every 8 hours; `options(cohortflow.warn_missing_reason = FALSE)` turns
  the warning off).

## See also

[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
for the underlying plain-tibble data layer,
[`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md)
for formatted table output,
[`save_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/save_consort_diagram.md)
to export for manuscript submission.

Other reporting:
[`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md),
[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md),
[`as_characteristics_table()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_table.md),
[`as_characteristics_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_tibble.md),
[`as_narrative()`](https://mattmoo.github.io/cohortflow/reference/as_narrative.md),
[`save_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/save_consort_diagram.md)

## Examples

``` r
dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
crit <- cf_criteria() |>
  include(~ !is.na(age), label = "Age recorded", category = "Valid age",
          reason = "Age missing") |>
  include(~ age >= 18, label = "Adults only", category = "Valid age",
          reason = "Under 18") |>
  include(~ !is.na(consent_date), label = "Consent recorded", reason = "No consent") |>
  exclude(~ withdrew, label = "Withdrew consent")
flow <- apply_criteria(dat, crit, id = "participant_id")
as_consort_diagram(flow)
```
