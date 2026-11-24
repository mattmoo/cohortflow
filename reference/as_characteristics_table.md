# Render a step-wise characteristics table

Formats
[`as_characteristics_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_tibble.md)
as a publication-ready table in the same APA style and through the same
backends as
[`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md):
a bold heading row per variable, indented summary rows, one column per
step headed by the step label and its `n`.

## Usage

``` r
as_characteristics_table(
  flow,
  vars,
  backend = c("flextable", "gt", "huxtable"),
  steps = NULL,
  excluded = FALSE,
  level = NULL,
  numeric = "mean_sd",
  missing = c("ifany", "always", "never"),
  digits = 1L,
  drop_randomise = TRUE,
  assessed_label = "Assessed for eligibility",
  missing_label = "Missing",
  variable_col_label = "Characteristic",
  var_labels = NULL
)
```

## Arguments

- flow:

  A `cf_flow` object produced by
  [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md).

- vars:

  Character vector of column names to summarise.

- backend:

  Character string: `"flextable"` (default), `"gt"`, or `"huxtable"`.

- steps:

  Optional step selectors (a vector or list); see the section "Steps".
  `NULL` (default) means every step.

- excluded:

  Logical. `FALSE` (default) describes the cohort surviving each step;
  `TRUE` describes the rows removed at each step.

- level:

  Optional hierarchy level name at which to count units; see the section
  "Hierarchy levels". Requires a flow built with a hierarchy.

- numeric:

  How to summarise numeric variables: `"mean_sd"` (default),
  `"median_iqr"`, or both.

- missing:

  When to include the row counting `NA` values per variable: `"ifany"`
  (default) if any column has one, `"always"`, or `"never"`.

- digits:

  Decimal places for means, SDs, medians, quartiles and percentages.
  Default `1`.

- drop_randomise:

  Logical. Omit
  [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
  steps when `steps` is `NULL` (default `TRUE`).

- assessed_label:

  Heading for step `0`, the starting data. Default
  `"Assessed for eligibility"`.

- missing_label:

  Label of the row counting `NA` values. Default `"Missing"`.

- variable_col_label:

  Column header for the variable column. Default `"Characteristic"`.

- var_labels:

  Optional display names for the variables: a character vector named by
  column (e.g. `c(age = "Age, years")`), or an unnamed vector aligned
  with `vars`. Unlisted variables show their column name.

## Value

A `flextable`, `gt_tbl`, or `huxtable` object.

## Steps

By default there is one column per step from `0` (the starting data) to
the last step, omitting
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
steps (see `drop_randomise`). Column `k` holds
`cohort(flow, step_number = k)`: the rows that passed steps `1` to `k`.
`steps` restricts or reorders the columns. Each element is resolved like
`at` in
[`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md):
a number is a step number (`0` = starting data); a string is a step
label if one matches, else a category, meaning its last step. Steps
named in `steps` are never dropped, even
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
steps.

With `excluded = TRUE`, column `k` instead holds the rows removed *at*
step `k` (those of
[`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md)
with `cf_step == k`): the usual supplementary table of excluded
participants' characteristics. Step `0` removes nothing and cannot be
selected.

A column's heading is the step label, or `assessed_label` for step `0`.
Repeated headings are made unique with `" #<n>"`.

## Summaries

How a variable is summarised depends on its type:

- **numeric**: a `"Mean (SD)"` row and/or a `"Median [IQR]"` row (shown
  as median \[Q1, Q3\]), chosen with `numeric`.

- **factor**: one row per level of the factor, in level order, whether
  or not the level occurs; `n (%)` of the non-missing values.

- **character**: as a factor whose levels are the distinct values in the
  starting data, sorted.

- **logical**: a single row (`level` is `NA`) counting `TRUE`; `n (%)`
  of the non-missing values.

Each variable also gets a `missing_label` row counting `NA` values, as a
percentage of the column's `n`; `missing` controls when it appears.
Dates and other types are not summarised: convert them first.

## Hierarchy levels

When the flow was built with `apply_criteria(hierarchy = )`, rows are
summarised unless `level` names one of the hierarchy's levels, in which
case each unit at that level (each distinct, complete key) contributes
once and `n` counts units. A row with an `NA` in the level's key is not
a unit. Every variable must then be constant within each unit across the
starting data; a variable that varies within a unit is an error, since
there is no single value to summarise.

## See also

[`as_characteristics_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_tibble.md)
for the underlying data layer.

Other reporting:
[`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md),
[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md),
[`as_characteristics_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_tibble.md),
[`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md),
[`as_narrative()`](https://mattmoo.github.io/cohortflow/reference/as_narrative.md),
[`save_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/save_consort_diagram.md)

## Examples

``` r
# \donttest{
dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
crit <- cf_criteria() |>
  include(~ age >= 18, label = "Adults only") |>
  include(~ eligible_screen, label = "Passed screening") |>
  exclude(~ withdrew, label = "Withdrew consent")
flow <- apply_criteria(dat, crit, id = "participant_id")

if (requireNamespace("flextable", quietly = TRUE) &&
    requireNamespace("officer", quietly = TRUE)) {
  as_characteristics_table(flow, vars = c("age", "sex", "withdrew"),
                           var_labels = c(age = "Age, years", sex = "Sex"))
}


.cl-d8bad469{}.cl-40145a8d{font-family:'Times New Roman';font-size:12pt;font-weight:bold;font-style:normal;text-decoration:none;color:rgba(0, 0, 0, 1.00);background-color:transparent;}.cl-fd7caf76{font-family:'Times New Roman';font-size:12pt;font-weight:normal;font-style:normal;text-decoration:none;color:rgba(0, 0, 0, 1.00);background-color:transparent;}.cl-0f1762d3{margin:0;text-align:left;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(0, 0, 0, 1.00);padding-bottom:5pt;padding-top:5pt;padding-left:5pt;padding-right:5pt;line-height: 1.15;background-color:transparent;}.cl-23f6e2f7{margin:0;text-align:right;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(0, 0, 0, 1.00);padding-bottom:5pt;padding-top:5pt;padding-left:5pt;padding-right:5pt;line-height: 1.15;background-color:transparent;}.cl-a318f3de{margin:0;text-align:left;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(0, 0, 0, 1.00);padding-bottom:5pt;padding-top:5pt;padding-left:12pt;padding-right:5pt;line-height: 1.15;background-color:transparent;}.cl-07b5d605{width:2.5in;background-color:transparent;vertical-align: middle;border-bottom: 1pt solid rgba(0, 0, 0, 1.00);border-top: 1pt solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-a638c1aa{width:1.3in;background-color:transparent;vertical-align: middle;border-bottom: 1pt solid rgba(0, 0, 0, 1.00);border-top: 1pt solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-b35386be{width:2.5in;background-color:transparent;vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-6e160614{width:1.3in;background-color:transparent;vertical-align: middle;border-bottom: 0 solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-4347d024{width:2.5in;background-color:transparent;vertical-align: middle;border-bottom: 1pt solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(0, 0, 0, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}.cl-ffacf34c{width:1.3in;background-color:transparent;vertical-align: middle;border-bottom: 1pt solid rgba(0, 0, 0, 1.00);border-top: 0 solid rgba(0, 0, 0, 1.00);border-left: 0 solid rgba(255, 255, 255, 1.00);border-right: 0 solid rgba(255, 255, 255, 1.00);margin-bottom:0;margin-top:0;margin-left:0;margin-right:0;}


Characteristic
```
