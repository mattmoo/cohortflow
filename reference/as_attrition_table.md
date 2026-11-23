# Format an attrition table from a cohort flow object

Produces a formatted attrition table from a `cf_flow` object. Three
output backends are supported: `"flextable"` (best for Word), `"gt"`
(best for HTML and LaTeX), and `"huxtable"`. The underlying data is
built by
[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md),
which you can call directly for custom formatting.

## Usage

``` r
as_attrition_table(
  flow,
  backend = c("flextable", "gt", "huxtable"),
  show_categories = TRUE,
  assessed_label = "Assessed for eligibility",
  final_label = "Final cohort",
  digits = 1L,
  criterion_col_label = "Criterion",
  n_col_label = "N",
  removed_col_label = "Removed",
  pct_col_label = "% removed",
  consequential_col_label = "Consequential",
  branch_by = NULL,
  count_by = NULL,
  branch_na_label = "Missing",
  group_x = NULL,
  group_y = NULL,
  group_x_label = NULL,
  group_y_label = NULL,
  group_na_label = "Missing",
  levels = character(0),
  level_labels = NULL,
  show_consequential = NULL,
  shade = NULL,
  shade_fn = NULL,
  shade_palette = c("#FFFFFF", "#F8696B")
)
```

## Arguments

- flow:

  A `cf_flow` object produced by
  [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md).

- backend:

  Character string: `"flextable"` (default), `"gt"`, or `"huxtable"`.

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

- criterion_col_label:

  Column header for the criterion/label column. Default `"Criterion"`.

- n_col_label:

  Column header for the N column. Default `"N"`.

- removed_col_label:

  Column header for the removed column. Default `"Removed"`.

- pct_col_label:

  Column header for the percentage column. Default `"% removed"`.

- consequential_col_label:

  Column header for the optional "consequential" column shown per level
  when `levels` is supplied and `show_consequential` resolves to `TRUE`.
  Default `"Consequential"`.

- branch_by:

  Optional column name (string) for allocation branching. When `NULL`
  (default), the table has a single `n` column unless the pipeline has a
  [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
  step, in which case its `arms` column is used automatically. When
  supplied (or defaulted), the surviving cohort is split by this column
  and the final row's total is broken out into one additional column per
  branch value (named after the branch value, e.g. `Control`,
  `Intervention`), each populated only on the final row. Use
  `final_label = "Randomised"` when appropriate. Cannot be combined with
  `group_x`/`group_y`. Rows whose branch value is `NA` form their own
  branch, labelled `branch_na_label`.

- count_by:

  Optional hierarchy level to count instead of rows: a level name from
  the flow's
  [`cf_hierarchy()`](https://mattmoo.github.io/cohortflow/reference/cf_hierarchy.md),
  or the column of a single-column level (e.g. `"participant_id"`).
  Every count (`n`, `n_removed`, `pct_removed` and the branch columns)
  is then the number of distinct units, and a unit counts as removed at
  the step where it loses its last row. Essential for crossover and
  other designs with several rows per participant. Requires
  `apply_criteria(hierarchy = )`; without a hierarchy, or with a column
  that is not a level, it errors and says how to fix the call. (Before
  cohortflow 0.0.0.9016 `count_by` took any column and changed only the
  branch columns, leaving `n` counting rows.)

- branch_na_label:

  Character string used to label the branch formed by `NA` values in
  `branch_by` (and, in
  [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md),
  the stage formed by `NA` values in `stage_by`). Default `"Missing"`.
  Ignored when the column has no `NA` values.

- group_x:

  Optional column name (string), present in `flow$data`, used to repeat
  the attrition table across the "column" direction (e.g. trial site).
  See the Grouping section.

- group_y:

  Optional column name (string), present in `flow$data`, used to repeat
  the attrition table across the "row" direction (e.g. time period). See
  the Grouping section.

- group_x_label:

  Optional prefix label for `group_x` column headings (e.g. `"Site"` to
  show `"Site: A"`). Default `NULL` (show the group value alone).

- group_y_label:

  Optional prefix label for `group_y` row headings (e.g. `"Period"` to
  show `"Period: 1"`). Default `NULL` (show the group value alone).

- group_na_label:

  Character string used to label the group formed by `NA` values in
  `group_x`/`group_y` (see the Grouping section). Default `"Missing"`.
  Ignored when the corresponding grouping column has no `NA` values.

- levels:

  Optional; requires `flow` to have been built with
  `apply_criteria(hierarchy = ...)`. When the default `character(0)`,
  this argument is ignored and the row-count behaviour above is
  unchanged. When `NULL`, one stacked block per hierarchy level is
  returned (finest to coarsest), each with a `level` column and an
  additional `n_consequential` column (see
  [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md)'s
  `hierarchy` argument for the counting rule). When a character vector
  of level name(s), only those levels are returned, in the order given.
  Cannot be combined with `group_x`/`group_y`, `branch_by`, or
  `count_by`. A row with an `NA` in any of a level's columns is not a
  unit at that level, but still counts at every level whose own key is
  complete: an expected participant with no cluster is one participant
  at risk and zero clusters.

- level_labels:

  Optional display names for the column blocks produced by `levels`.
  Either a vector positionally aligned with `levels`, or a vector named
  by level (e.g. `c(trial = "Trials", participant = "Participants")`).
  Default `NULL`, which uses the level names as-is – level names are
  user-chosen and are not auto-pluralised or title-cased, since guessing
  would be as likely to surprise as to help; supply `level_labels` to
  get "Trials" from a level named `trial`. Ignored unless `levels` is
  supplied.

- show_consequential:

  Logical, or `NULL` (default). Controls whether an extra
  "consequential" column is shown per level, reporting units lost only
  because a
  [`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md)/[`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md)
  group they belonged to was removed (see `levels` on
  [`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)).
  When `NULL`, the column is included only if the underlying data has
  any non-zero value for it, so pipelines without group-level criteria
  render unchanged. Ignored unless `levels` is supplied.

- shade:

  Optional character string: `"pct_removed"` or `"n_removed"`. When
  supplied, shades the N/Removed/% cells of step and category rows with
  an automatic colour gradient based on that column's value. Default
  `NULL` (no shading).

- shade_fn:

  Optional function for custom cell shading; see the Shading section.
  Default `NULL`.

- shade_palette:

  Character vector of \>= 2 colours defining the gradient used by
  `shade`. Default `c("#FFFFFF", "#F8696B")` (white to red).

## Value

A `flextable`, `gt_tbl`, or `huxtable` object, ready to print or include
in a document. When `branch_by` is supplied, one additional column per
branch value is added after the percentage column, headed with the
branch value itself and populated only on the final row. When
`group_x`/`group_y` are supplied, the table is a repeated grid as
described in the Grouping section. When `levels` is supplied, the table
has one N/Removed/% column block per level, as described in the
Hierarchy levels section.

## Output formats

- **`"flextable"`** – uses the flextable and officer packages. Renders
  natively to Word (`.docx`) via
  [`officer::read_docx()`](https://davidgohel.github.io/officer/reference/read_docx.html),
  to PDF via
  [`flextable::save_as_image()`](https://davidgohel.github.io/flextable/reference/save_as_image.html),
  and to HTML. Best choice when Word is the primary target.

- **`"gt"`** – uses the gt package. Renders to HTML
  (`gt::gtsave(..., "table.html")`), LaTeX
  ([`gt::as_latex()`](https://gt.rstudio.com/reference/as_latex.html)),
  and Word (via `gt::gtsave(..., "table.docx")` requires the webshot2
  package). Best choice when LaTeX or HTML is the primary target.

- **`"huxtable"`** – uses the huxtable package. Supports Word, LaTeX,
  and HTML output.

## Grouping (`group_x` / `group_y`)

Supplying `group_x` and/or `group_y` repeats the whole attrition table
across a grid: `group_x` values become repeated column blocks (N /
Removed / % removed, headed by a spanning column group), and `group_y`
values become repeated row blocks (each preceded by a bold group-heading
row), so the criterion rows appear once but attrition counts are shown
per group combination. This is useful, for example, for showing a
stepped-wedge trial's attrition by site (`group_x`) and period
(`group_y`). `branch_by` cannot be combined with grouping.

## Shading

Cells can be shaded to highlight high-attrition rows/cells:

- `shade = "pct_removed"` or `"n_removed"` applies an automatic colour
  gradient (`shade_palette`, default white to red) scaled across the
  values present in step/category rows.

- `shade_fn` gives full control: supply a function that takes the
  attrition tibble (as returned by
  [`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md),
  including `group_x`/`group_y` columns when grouped) and returns a
  character vector of colours (or `NA`) the same length as the tibble,
  one colour per row. `shade_fn` takes precedence over `shade` if both
  are supplied.

## Hierarchy levels (`levels`)

Supplying `levels` repeats the N / Removed / % removed columns once per
hierarchy level, so a single criterion row reports its effect at every
level side by side – the reporting form required by the CONSORT cluster
extension (Campbell, Elbourne & Altman, BMJ 2004;328:702-8) and the
within-person extension, where losses at each stage are counted at both
the unit of analysis and the unit of recruitment. For example, with a
cluster-randomised trial where participants nest inside clusters:

    h <- cf_hierarchy(participant = "participant_id", cluster = "cluster_id")
    flow <- apply_criteria(dat, crit, hierarchy = h)
    as_attrition_table(
      flow,
      levels       = c("participant", "cluster"),
      level_labels = c(participant = "Participants", cluster = "Clusters")
    )

produces one row per criterion with a column block for participants and
a column block for clusters, e.g. *"Cluster too small – 42 participants
removed, 3 clusters removed"*. Shading (`shade`/`shade_fn`) is computed
*per level* – each level's colour gradient is scaled across that level's
own values, not across all levels combined. `levels` cannot be combined
with `group_x`/`group_y`/`branch_by`/`count_by`. Rows with an `NA` in a
level's column(s) are not counted as units at that level (they still
count at any level whose own key is complete).

## See also

[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
for the underlying plain-tibble data layer.

Other reporting:
[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md),
[`as_characteristics_table()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_table.md),
[`as_characteristics_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_tibble.md),
[`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md),
[`save_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/save_consort_diagram.md)

## Examples

``` r
# \donttest{
dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
crit <- cf_criteria() |>
  include(~ !is.na(age),     label = "Age recorded",    category = "Valid age") |>
  include(~ age >= 18,       label = "Adults only",      category = "Valid age") |>
  include(~ eligible_screen, label = "Passed screening") |>
  include(~ !is.na(consent_date), label = "Consent recorded", category = "Consent") |>
  exclude(~ withdrew,        label = "Withdrew consent", category = "Consent")
flow <- apply_criteria(dat, crit)
#> No `id` supplied and no `.cf_row_id` column found. Adding a sequential `.cf_row_id`.

if (requireNamespace("flextable", quietly = TRUE) &&
    requireNamespace("officer", quietly = TRUE)) {
  as_attrition_table(flow)                         # flextable (Word-ready)
  as_attrition_table(flow, shade = "pct_removed")  # shade by % removed
}


.cl-d8bad469{}.cl-40145a8d{font-family:'Times New Roman';font-size:12pt;font-weight:bold;font-style:normal;text-decoration:none;color:rgba(0, 0, 0, 1.00);background-color:transparent;}.cl-fd7caf76{font-family:'Times New Roman';font-size:12pt;font-weight:normal;font-style:normal;text-decoration:none;color:rgba(0, 0, 0, 1.00);background-color:transparent;}.cl-0f1762d3{margin:0;text-align:left;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(0, 0, 0, 1.00);padding-bottom:5pt;padding-top:5pt;padding-left:5pt;padding-right:5pt;line-height: 1.15;background-color:transparent;}.cl-23f6e2f7{margin:0;text-align:right;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(0, 0, 0, 1.00);padding-bottom:5pt;padding-top:5pt;padding-left:5pt;padding-right:5pt;line-height: 1.15;background-color:transparent;}.cl-4a14f764{margin:0;text-align:left;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(0, 0, 0, 1.00);padding-bottom:5pt;padding-top:5pt;padding-left:24pt;padding-right:5pt;line-height: 1.15;background-color:transparent;}.cl-a318f3de{margin:0;text-align:left;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(0, 0, 0, 1.00);padding-bottom:5pt;padding-top:5pt;padding-left:12pt;padding-right:5pt;line-height: 1.15;background-color:transparent;}.cl-e62b5e50{width:3.5in;background-color:transparent;vertical-align: middle;border-bottom: 1pt solid rgba(0, 0, 0, 1.00);border-top: 1pt solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-280fe7f7{width:0.6in;background-color:transparent;vertical-align: middle;border-bottom: 1pt solid rgba(0, 0, 0, 1.00);border-top: 1pt solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-790ad87a{width:0.9in;background-color:transparent;vertical-align: middle;border-bottom: 1pt solid rgba(0, 0, 0, 1.00);border-top: 1pt solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-ec315a39{width:1in;background-color:transparent;vertical-align: middle;border-bottom: 1pt solid rgba(0, 0, 0, 1.00);border-top: 1pt solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-c9510621{width:3.5in;background-color:transparent;vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-cce807d2{width:0.6in;background-color:transparent;vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-0799607d{width:0.9in;background-color:transparent;vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-2bc3519b{width:1in;background-color:transparent;vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-c8776c89{width:0.6in;background-color:rgba(252, 209, 210, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-6b6d99de{width:0.9in;background-color:rgba(252, 209, 210, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-b6f672e9{width:1in;background-color:rgba(252, 209, 210, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-c93c4b51{width:0.6in;background-color:rgba(254, 236, 237, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-ed7cc0f2{width:0.9in;background-color:rgba(254, 236, 237, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-7a2be08f{width:1in;background-color:rgba(254, 236, 237, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-b5799398{width:0.6in;background-color:rgba(255, 255, 255, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-3bda691f{width:0.9in;background-color:rgba(255, 255, 255, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-b0351510{width:1in;background-color:rgba(255, 255, 255, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-d1c2ba98{width:0.6in;background-color:rgba(252, 207, 208, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-afd63ac8{width:0.9in;background-color:rgba(252, 207, 208, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-73a47e78{width:1in;background-color:rgba(252, 207, 208, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-3e8bbc0d{width:0.6in;background-color:rgba(248, 105, 107, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-0be8e904{width:0.9in;background-color:rgba(248, 105, 107, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-aa9c1be9{width:1in;background-color:rgba(248, 105, 107, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-eb388ef9{width:0.6in;background-color:rgba(249, 142, 143, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-c558baeb{width:0.9in;background-color:rgba(249, 142, 143, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-139e86e6{width:1in;background-color:rgba(249, 142, 143, 1.00);vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-77fe726a{width:3.5in;background-color:transparent;vertical-align: middle;border-bottom: 1pt solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-639f48b8{width:0.6in;background-color:rgba(254, 245, 245, 1.00);vertical-align: middle;border-bottom: 1pt solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-df032fb2{width:0.9in;background-color:rgba(254, 245, 245, 1.00);vertical-align: middle;border-bottom: 1pt solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-d4d154e2{width:1in;background-color:rgba(254, 245, 245, 1.00);vertical-align: middle;border-bottom: 1pt solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}


Criterion
```
