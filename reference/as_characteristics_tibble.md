# Characteristics of the cohort at each step

Summarises chosen variables (demographics, baseline measures) for the
cohort at each step of a flow: a baseline-characteristics ("Table 1")
table with one column per step, each describing the rows surviving up to
and including that step. `as_characteristics_tibble()` is the data
layer;
[`as_characteristics_table()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_table.md)
renders it;
[`stack_cohorts()`](https://mattmoo.github.io/cohortflow/reference/stack_cohorts.md)
gives the per-step rows themselves for other summary-table packages.

## Usage

``` r
as_characteristics_tibble(
  flow,
  vars,
  steps = NULL,
  excluded = FALSE,
  level = NULL,
  numeric = "mean_sd",
  missing = c("ifany", "always", "never"),
  digits = 1L,
  drop_randomise = TRUE,
  assessed_label = "Assessed for eligibility",
  missing_label = "Missing",
  wide = FALSE
)
```

## Arguments

- flow:

  A `cf_flow` object produced by
  [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md).

- vars:

  Character vector of column names to summarise.

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

- wide:

  Logical. `FALSE` (default) returns the long form; `TRUE` pivots the
  columns to one per step for display.

## Value

With `wide = FALSE`, a tibble with one row per variable, summary row and
step, ordered by variable (in `vars` order), then summary row, then step
column:

- `variable`:

  Column name

- `level`:

  Factor level, `"Mean (SD)"`, `"Median [IQR]"`, `missing_label`, or
  `NA` for a logical variable's single row

- `step`:

  Step number (`0` = starting data)

- `label`:

  Step heading

- `n`:

  Rows (or units, with `level`) in that step's column

- `count`:

  Rows in the level, or missing; `NA` for numeric summaries

- `pct`:

  `count` as a percentage of the non-missing values (of `n` for the
  missing row); `NA` where the denominator is zero

- `stat`:

  Display text: `"12 (6.0%)"`, `"45.2 (14.8)"`, `"45.0 [35.0, 56.0]"`;
  `NA` when there is nothing to summarise

With `wide = TRUE`, `variable` and `level` followed by one character
column per step, named `"<heading> (n = <n>)"`, holding `stat`.

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

[`as_characteristics_table()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_table.md)
for a formatted table,
[`stack_cohorts()`](https://mattmoo.github.io/cohortflow/reference/stack_cohorts.md)
for the per-step rows,
[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
for the attrition counts themselves.

Other reporting:
[`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md),
[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md),
[`as_characteristics_table()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_table.md),
[`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md),
[`save_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/save_consort_diagram.md)

## Examples

``` r
dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
crit <- cf_criteria() |>
  include(~ age >= 18, label = "Adults only") |>
  include(~ eligible_screen, label = "Passed screening") |>
  exclude(~ withdrew, label = "Withdrew consent")
flow <- apply_criteria(dat, crit, id = "participant_id")

as_characteristics_tibble(flow, vars = c("age", "sex"))
#> # A tibble: 20 × 8
#>    variable level      step label                        n count   pct stat     
#>    <chr>    <chr>     <int> <chr>                    <int> <int> <dbl> <chr>    
#>  1 age      Mean (SD)     0 Assessed for eligibility   200    NA  NA   44.6 (14…
#>  2 age      Mean (SD)     1 Adults only                184    NA  NA   45.7 (13…
#>  3 age      Mean (SD)     2 Passed screening           169    NA  NA   45.2 (13…
#>  4 age      Mean (SD)     3 Withdrew consent           162    NA  NA   45.5 (13…
#>  5 age      Missing       0 Assessed for eligibility   200    10   5   10 (5.0%)
#>  6 age      Missing       1 Adults only                184     0   0   0 (0.0%) 
#>  7 age      Missing       2 Passed screening           169     0   0   0 (0.0%) 
#>  8 age      Missing       3 Withdrew consent           162     0   0   0 (0.0%) 
#>  9 sex      F             0 Assessed for eligibility   200    97  48.5 97 (48.5…
#> 10 sex      F             1 Adults only                184    86  46.7 86 (46.7…
#> 11 sex      F             2 Passed screening           169    80  47.3 80 (47.3…
#> 12 sex      F             3 Withdrew consent           162    76  46.9 76 (46.9…
#> 13 sex      M             0 Assessed for eligibility   200    98  49   98 (49.0…
#> 14 sex      M             1 Adults only                184    93  50.5 93 (50.5…
#> 15 sex      M             2 Passed screening           169    85  50.3 85 (50.3…
#> 16 sex      M             3 Withdrew consent           162    82  50.6 82 (50.6…
#> 17 sex      O             0 Assessed for eligibility   200     5   2.5 5 (2.5%) 
#> 18 sex      O             1 Adults only                184     5   2.7 5 (2.7%) 
#> 19 sex      O             2 Passed screening           169     4   2.4 4 (2.4%) 
#> 20 sex      O             3 Withdrew consent           162     4   2.5 4 (2.5%) 
as_characteristics_tibble(flow, vars = c("age", "sex"), wide = TRUE)
#> # A tibble: 5 × 6
#>   variable level     `Assessed for eligibility (n = 200)` Adults only (n = 184…¹
#>   <chr>    <chr>     <chr>                                <chr>                 
#> 1 age      Mean (SD) 44.6 (14.7)                          45.7 (13.6)           
#> 2 age      Missing   10 (5.0%)                            0 (0.0%)              
#> 3 sex      F         97 (48.5%)                           86 (46.7%)            
#> 4 sex      M         98 (49.0%)                           93 (50.5%)            
#> 5 sex      O         5 (2.5%)                             5 (2.7%)              
#> # ℹ abbreviated name: ¹​`Adults only (n = 184)`
#> # ℹ 2 more variables: `Passed screening (n = 169)` <chr>,
#> #   `Withdrew consent (n = 162)` <chr>

# Who was removed at each step?
as_characteristics_tibble(flow, vars = "age", excluded = TRUE, wide = TRUE)
#> # A tibble: 2 × 5
#>   variable level     `Adults only (n = 16)` `Passed screening (n = 15)`
#>   <chr>    <chr>     <chr>                  <chr>                      
#> 1 age      Mean (SD) 11.2 (4.0)             51.6 (13.7)                
#> 2 age      Missing   10 (62.5%)             0 (0.0%)                   
#> # ℹ 1 more variable: `Withdrew consent (n = 7)` <chr>

# Only the starting data and the final cohort, with both numeric summaries
as_characteristics_tibble(flow, vars = "age", steps = c(0, 3),
                          numeric = c("mean_sd", "median_iqr"), wide = TRUE)
#> # A tibble: 3 × 4
#>   variable level        Assessed for eligibility (n = 2…¹ Withdrew consent (n …²
#>   <chr>    <chr>        <chr>                             <chr>                 
#> 1 age      Mean (SD)    44.6 (14.7)                       45.5 (13.5)           
#> 2 age      Median [IQR] 43.5 [36.0, 53.8]                 44.0 [37.0, 53.8]     
#> 3 age      Missing      10 (5.0%)                         0 (0.0%)              
#> # ℹ abbreviated names: ¹​`Assessed for eligibility (n = 200)`,
#> #   ²​`Withdrew consent (n = 162)`
```
