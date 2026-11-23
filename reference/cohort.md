# Extract the surviving cohort from a flow object

Returns the rows that passed all criteria (or, with a step selector, all
criteria up to a chosen step), with the internal `.cf_row_id` column
removed.

## Usage

``` r
cohort(
  flow,
  flag = FALSE,
  at = NULL,
  step_number = NULL,
  label = NULL,
  category = NULL
)
```

## Arguments

- flow:

  A `cf_flow` object produced by
  [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md).

- flag:

  Logical. When `FALSE` (default), returns only the surviving rows (the
  historical behaviour). When `TRUE`, returns **all** original rows, in
  their original order, with attribution columns added instead of
  filtering: `cf_included` (logical), `cf_excluded_step` (integer, `NA`
  if included), `cf_excluded_label` (character, `NA` if included), and
  `cf_excluded_category` (character, `NA` if uncategorised or included).
  Useful when downstream code needs every row present (e.g. plotting a
  full recording) while still knowing which rows count. Combined with a
  step selector, attribution only considers steps up to that step; rows
  removed later count as included.

- at:

  Optional automatic step selector (number, label or category); see the
  section "Intermediate steps".

- step_number:

  Optional whole step number (`0` = starting data).

- label:

  Optional exact step label.

- category:

  Optional category name (last step in that category).

## Value

A tibble.

## Intermediate steps

A selector picks a step and means "up to and including that step". With
none given, the last step is used. At most one may be given:

- `step_number`: a whole number `k` from `0` to the number of steps; `0`
  is the starting data.

- `label`: an exact step label. Errors if no step, or several steps,
  have it.

- `category`: a category name; selects the last step in that category.

- `at`: picks automatically. A number is a `step_number`; a string is a
  `label` if one matches, else a `category`. A string that is both a
  label and a category is an error: use `label` or `category`
  explicitly.

## See also

[`criteria_status()`](https://mattmoo.github.io/cohortflow/reference/criteria_status.md)
for each row's result on every criterion.

Other flow accessors:
[`criteria_status()`](https://mattmoo.github.io/cohortflow/reference/criteria_status.md),
[`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md),
[`stack_cohorts()`](https://mattmoo.github.io/cohortflow/reference/stack_cohorts.md)

## Examples

``` r
dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
crit <- cf_criteria() |>
  include(~ !is.na(age), label = "Age recorded") |>
  include(~ eligible_screen, label = "Passed screening") |>
  exclude(~ withdrew, label = "Withdrew consent")
flow <- apply_criteria(dat, crit)
#> No `id` supplied and no `.cf_row_id` column found. Adding a sequential `.cf_row_id`.
cohort(flow)                            # final survivors
#> # A tibble: 167 × 10
#>    participant_id arm            age age_group sex   ethnicity eligible_screen
#>    <chr>          <chr>        <dbl> <chr>     <chr> <chr>     <lgl>          
#>  1 P0002          Intervention    46 40-64     M     Pacific   TRUE           
#>  2 P0003          Control         31 18-39     M     European  TRUE           
#>  3 P0004          Control         47 40-64     F     European  TRUE           
#>  4 P0005          Intervention    35 18-39     F     Pacific   TRUE           
#>  5 P0006          Control         72 65+       F     Pacific   TRUE           
#>  6 P0007          Control         56 40-64     M     European  TRUE           
#>  7 P0008          Control         59 40-64     F     Maori     TRUE           
#>  8 P0010          Intervention    70 65+       F     European  TRUE           
#>  9 P0011          Control         35 18-39     M     Maori     TRUE           
#> 10 P0013          Control         66 65+       F     Asian     TRUE           
#> # ℹ 157 more rows
#> # ℹ 3 more variables: consent_date <date>, baseline_complete <lgl>,
#> #   withdrew <lgl>
cohort(flow, at = "Passed screening")   # screening cohort (auto-select)
#> # A tibble: 174 × 10
#>    participant_id arm            age age_group sex   ethnicity eligible_screen
#>    <chr>          <chr>        <dbl> <chr>     <chr> <chr>     <lgl>          
#>  1 P0002          Intervention    46 40-64     M     Pacific   TRUE           
#>  2 P0003          Control         31 18-39     M     European  TRUE           
#>  3 P0004          Control         47 40-64     F     European  TRUE           
#>  4 P0005          Intervention    35 18-39     F     Pacific   TRUE           
#>  5 P0006          Control         72 65+       F     Pacific   TRUE           
#>  6 P0007          Control         56 40-64     M     European  TRUE           
#>  7 P0008          Control         59 40-64     F     Maori     TRUE           
#>  8 P0010          Intervention    70 65+       F     European  TRUE           
#>  9 P0011          Control         35 18-39     M     Maori     TRUE           
#> 10 P0012          Control         38 18-39     F     Asian     TRUE           
#> # ℹ 164 more rows
#> # ℹ 3 more variables: consent_date <date>, baseline_complete <lgl>,
#> #   withdrew <lgl>
cohort(flow, label = "Passed screening") # same, explicit
#> # A tibble: 174 × 10
#>    participant_id arm            age age_group sex   ethnicity eligible_screen
#>    <chr>          <chr>        <dbl> <chr>     <chr> <chr>     <lgl>          
#>  1 P0002          Intervention    46 40-64     M     Pacific   TRUE           
#>  2 P0003          Control         31 18-39     M     European  TRUE           
#>  3 P0004          Control         47 40-64     F     European  TRUE           
#>  4 P0005          Intervention    35 18-39     F     Pacific   TRUE           
#>  5 P0006          Control         72 65+       F     Pacific   TRUE           
#>  6 P0007          Control         56 40-64     M     European  TRUE           
#>  7 P0008          Control         59 40-64     F     Maori     TRUE           
#>  8 P0010          Intervention    70 65+       F     European  TRUE           
#>  9 P0011          Control         35 18-39     M     Maori     TRUE           
#> 10 P0012          Control         38 18-39     F     Asian     TRUE           
#> # ℹ 164 more rows
#> # ℹ 3 more variables: consent_date <date>, baseline_complete <lgl>,
#> #   withdrew <lgl>
nrow(cohort(flow, step_number = 0))     # the starting data
#> [1] 200
excluded(flow, at = 2)                  # removed by steps 1-2
#> # A tibble: 26 × 15
#>    participant_id arm            age age_group sex   ethnicity eligible_screen
#>    <chr>          <chr>        <dbl> <chr>     <chr> <chr>     <lgl>          
#>  1 P0077          Intervention    NA NA        F     European  TRUE           
#>  2 P0078          Control         NA NA        M     European  TRUE           
#>  3 P0114          Intervention    NA NA        M     Asian     TRUE           
#>  4 P0115          Intervention    NA NA        F     Maori     TRUE           
#>  5 P0140          Control         NA NA        M     European  FALSE          
#>  6 P0159          Intervention    NA NA        F     Other     TRUE           
#>  7 P0194          Intervention    NA NA        M     European  TRUE           
#>  8 P0195          Intervention    NA NA        F     European  TRUE           
#>  9 P0197          Control         NA NA        F     Asian     TRUE           
#> 10 P0199          Control         NA NA        F     Pacific   TRUE           
#> # ℹ 16 more rows
#> # ℹ 8 more variables: consent_date <date>, baseline_complete <lgl>,
#> #   withdrew <lgl>, .cf_row_id <int>, cf_step <int>, cf_label <chr>,
#> #   cf_type <chr>, cf_category <chr>
```
