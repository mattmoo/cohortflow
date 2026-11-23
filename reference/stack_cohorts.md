# Stack the cohort at each step into one data frame

Returns the rows of the cohort surviving each step (or, with
`excluded = TRUE`, the rows removed at each step), stacked with a `step`
factor and a `step_number` column in front of the original columns. A
row that survives several steps appears once per step. This is the input
shape summary-table packages expect, e.g.
`gtsummary::tbl_summary(stack_cohorts(flow), by = step, include = c(age, sex))`;
[`as_characteristics_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_tibble.md)
is the dependency-light equivalent.

## Usage

``` r
stack_cohorts(
  flow,
  steps = NULL,
  excluded = FALSE,
  level = NULL,
  drop_randomise = TRUE,
  assessed_label = "Assessed for eligibility"
)
```

## Arguments

- flow:

  A `cf_flow` object produced by
  [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md).

- steps:

  Optional step selectors (a vector or list); see the section "Steps".
  `NULL` (default) means every step.

- excluded:

  Logical. `FALSE` (default) describes the cohort surviving each step;
  `TRUE` describes the rows removed at each step.

- level:

  Optional hierarchy level name at which to count units; see the section
  "Hierarchy levels". Requires a flow built with a hierarchy.

- drop_randomise:

  Logical. Omit
  [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
  steps when `steps` is `NULL` (default `TRUE`).

- assessed_label:

  Heading for step `0`, the starting data. Default
  `"Assessed for eligibility"`.

## Value

A tibble: `step_number` (integer), `step` (factor whose levels are the
step headings in column order), then the data columns. With `level`,
only the level's key column(s) and the columns constant within every
unit of that level are kept.

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

## Hierarchy levels

When the flow was built with `apply_criteria(hierarchy = )`, rows are
summarised unless `level` names one of the hierarchy's levels, in which
case each unit at that level (each distinct, complete key) contributes
once and `n` counts units. A row with an `NA` in the level's key is not
a unit. Every variable must then be constant within each unit across the
starting data; a variable that varies within a unit is an error, since
there is no single value to summarise.

## See also

[`as_characteristics_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_tibble.md),
[`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md),
[`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md).

Other flow accessors:
[`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md),
[`criteria_status()`](https://mattmoo.github.io/cohortflow/reference/criteria_status.md),
[`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md)

## Examples

``` r
dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
crit <- cf_criteria() |>
  include(~ age >= 18, label = "Adults only") |>
  include(~ eligible_screen, label = "Passed screening") |>
  exclude(~ withdrew, label = "Withdrew consent")
flow <- apply_criteria(dat, crit, id = "participant_id")
stacked <- stack_cohorts(flow)
table(stacked$step)
#> 
#> Assessed for eligibility              Adults only         Passed screening 
#>                      200                      184                      169 
#>         Withdrew consent 
#>                      162 
```
