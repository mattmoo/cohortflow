# Build an attrition tibble from a cohort flow object

Produces a flat tibble describing the attrition at each step (or
category) of a cohort flow pipeline. This is the underlying data layer
used by
[`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md),
and is also useful for custom formatting.

## Usage

``` r
as_attrition_tibble(
  flow,
  show_categories = TRUE,
  assessed_label = "Assessed for eligibility",
  final_label = "Final cohort",
  digits = 1L,
  branch_by = NULL,
  count_by = NULL,
  group_x = NULL,
  group_y = NULL,
  group_na_label = "Missing",
  levels = character(0),
  branch_na_label = "Missing"
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

- group_x:

  Optional column name (string), present in `flow$data`, used to repeat
  the attrition table across the "column" direction (e.g. trial site).
  See the Grouping section.

- group_y:

  Optional column name (string), present in `flow$data`, used to repeat
  the attrition table across the "row" direction (e.g. time period). See
  the Grouping section.

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

- branch_na_label:

  Character string used to label the branch formed by `NA` values in
  `branch_by` (and, in
  [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md),
  the stage formed by `NA` values in `stage_by`). Default `"Missing"`.
  Ignored when the column has no `NA` values.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with columns:

- `row_type`:

  `"header"`, `"category"`, `"step"`, or `"final"`

- `label`:

  Display text for the row

- `indent_level`:

  `0` = header/final, `1` = category or top-level step, `2` = sub-step
  under a category

- `n`:

  Number of participants at this point (N entering for category/step
  rows; N surviving for the final row)

- `n_removed`:

  Number removed at this step (`NA` for header/final)

- `pct_removed`:

  Percentage removed relative to entering N (`NA` for header; for final
  row: percentage retained of original N)

When `branch_by` is supplied, one additional column per unique branch
value is appended (named after the branch value), populated only on the
final row with that branch's surviving count. When `group_x`/`group_y`
are supplied, `group_x` and `group_y` character columns are appended
(see the Grouping section) and the tibble contains one stacked block per
group combination rather than a single block. When the pipeline has a
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
step, a `post_randomisation` logical column is appended (`TRUE` for
header/final/step/category rows at or after that step, `FALSE` before
it); this column is omitted entirely when there is no
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
step, so existing pipelines see no schema change.

## Row structure

The tibble always starts with an "assessed" header row and ends with a
"final cohort" row. When `show_categories = TRUE` (the default), steps
that share a `category` are collapsed into a parent row (indent level 1)
with individual step sub-rows (indent level 2) nested beneath it.
Uncategorised steps appear at indent level 1 without sub-rows. When
`show_categories = FALSE`, one row per step is produced at indent level
1.

Steps are collapsed under a category only when they are *consecutive* in
the pipeline (reordering steps would change the cumulative counts). A
category whose steps are separated by other steps therefore produces
more than one category row, and a warning suggests reordering the
pipeline.

## Percentage columns

- `pct_removed`: percentage of entering N removed at this row's step (or
  category). For the final cohort row this is the percentage *retained*
  relative to the initial N (i.e. `n / n_start * 100`).

- Percentages are relative to `n_in` – the number entering that step or,
  for a category row, the number entering the first step in that
  category.

- When steps are grouped under a category (`show_categories = TRUE`),
  each step sub-row's `pct_removed` is also expressed relative to the
  category's total entering N (rather than its own, progressively
  smaller, entering N), so that all rows within a category share the
  same denominator and sum consistently with the category row's
  percentage.

## Grouping (`group_x` / `group_y`)

When `group_x` and/or `group_y` are supplied, the criteria pipeline
stored in `flow` is re-applied independently to each subset of the
*original* data defined by the unique values of the grouping column(s)
(e.g. trial site, time period). The returned tibble is a flat, "long"
stack of one full attrition block per group combination, with additional
`group_x` and `group_y` character columns identifying which subset each
row belongs to (`NA` for the ungrouped dimension). This long format is
the input to the grid layout produced by
[`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md);
use it directly if you want to build your own custom cross-tabulated
output. `branch_by`/`count_by` cannot currently be combined with
grouping.

Rows where the grouping column itself is `NA` (e.g. missing ethnicity)
are **not** silently dropped, and are never folded into every other
group's counts. Instead they form their own explicit group, labelled by
`group_na_label` (default `"Missing"`), so the grouped totals still sum
to the full dataset.

## See also

[`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md)
for formatted table output.

Other reporting:
[`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md),
[`as_characteristics_table()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_table.md),
[`as_characteristics_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_tibble.md),
[`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md),
[`save_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/save_consort_diagram.md)

## Examples

``` r
dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
crit <- cf_criteria() |>
  include(~ !is.na(age), label = "Age recorded", category = "Valid age") |>
  include(~ age >= 18, label = "Adults only", category = "Valid age") |>
  include(~ eligible_screen, label = "Passed screening",
          category = "Eligible at screening") |>
  include(~ !is.na(consent_date), label = "Consent recorded", category = "Consent") |>
  exclude(~ withdrew, label = "Withdrew consent", category = "Consent")
flow <- apply_criteria(dat, crit, id = "participant_id")
as_attrition_tibble(flow)
#> # A tibble: 10 × 6
#>    row_type label                    indent_level     n n_removed pct_removed
#>    <chr>    <chr>                           <int> <int>     <int>       <dbl>
#>  1 header   Assessed for eligibility            0   200        NA        NA  
#>  2 category Valid age                           1   200        16         8  
#>  3 step     Age recorded                        2   200        10         5  
#>  4 step     Adults only                         2   190         6         3  
#>  5 category Eligible at screening               1   184        NA        NA  
#>  6 step     Passed screening                    2   184        15         8.2
#>  7 category Consent                             1   169        33        19.5
#>  8 step     Consent recorded                    2   169        26        15.4
#>  9 step     Withdrew consent                    2   143         7         4.1
#> 10 final    Final cohort                        0   136        NA        68  
```
