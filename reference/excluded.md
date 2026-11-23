# Extract excluded rows from a flow object

Returns a flat tibble of all rows removed at any step (or, with `at`, up
to and including a chosen step), with additional columns `cf_step`
(integer), `cf_label` (character), `cf_type` (character), and
`cf_category` (character, `NA` if the criterion had no category). Rows
are in step order. Set `only = TRUE` to get just the rows removed at the
selected step itself.

## Usage

``` r
excluded(
  flow,
  at = NULL,
  step_number = NULL,
  label = NULL,
  category = NULL,
  only = FALSE
)
```

## Arguments

- flow:

  A `cf_flow` object produced by
  [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md).

- at:

  Optional automatic step selector (number, label or category); see the
  section "Intermediate steps".

- step_number:

  Optional whole step number (`0` = starting data).

- label:

  Optional exact step label.

- category:

  Optional category name (last step in that category).

- only:

  Logical. When `FALSE` (default), returns rows removed by every step up
  to and including the selected step. When `TRUE`, returns only the rows
  removed at the selected step (for a `category` selector, the last step
  in that category). Step `0` removes nothing, so
  `step_number = 0, only = TRUE` returns no rows. With no selector,
  `TRUE` gives the rows removed at the last step.

## Value

A tibble with original columns plus `cf_step`, `cf_label`, `cf_type`,
`cf_category`.

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

Other flow accessors:
[`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md),
[`criteria_status()`](https://mattmoo.github.io/cohortflow/reference/criteria_status.md),
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
excluded(flow)                                   # removed at any step
#> # A tibble: 33 × 15
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
#> # ℹ 23 more rows
#> # ℹ 8 more variables: consent_date <date>, baseline_complete <lgl>,
#> #   withdrew <lgl>, .cf_row_id <int>, cf_step <int>, cf_label <chr>,
#> #   cf_type <chr>, cf_category <chr>
excluded(flow, at = 2)                           # removed by steps 1-2
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
excluded(flow, at = 2, only = TRUE)              # removed at step 2 only
#> # A tibble: 16 × 15
#>    participant_id arm            age age_group sex   ethnicity eligible_screen
#>    <chr>          <chr>        <dbl> <chr>     <chr> <chr>     <lgl>          
#>  1 P0001          Control         36 18-39     M     European  FALSE          
#>  2 P0009          Intervention    51 40-64     M     European  FALSE          
#>  3 P0039          Intervention    35 18-39     M     Pacific   FALSE          
#>  4 P0048          Intervention    45 40-64     M     European  FALSE          
#>  5 P0060          Control         73 65+       M     Other     FALSE          
#>  6 P0066          Intervention    78 65+       F     European  FALSE          
#>  7 P0072          Intervention    47 40-64     M     Pacific   FALSE          
#>  8 P0085          Control         53 40-64     M     European  FALSE          
#>  9 P0101          Intervention    51 40-64     F     Maori     FALSE          
#> 10 P0145          Control         62 40-64     F     Pacific   FALSE          
#> 11 P0149          Control         43 40-64     M     European  FALSE          
#> 12 P0164          Intervention    58 40-64     F     European  FALSE          
#> 13 P0168          Control         27 18-39     O     Asian     FALSE          
#> 14 P0177          Intervention    11 <18       F     Other     FALSE          
#> 15 P0178          Intervention    56 40-64     F     European  FALSE          
#> 16 P0188          Control         59 40-64     F     European  FALSE          
#> # ℹ 8 more variables: consent_date <date>, baseline_complete <lgl>,
#> #   withdrew <lgl>, .cf_row_id <int>, cf_step <int>, cf_label <chr>,
#> #   cf_type <chr>, cf_category <chr>
excluded(flow, label = "Withdrew consent", only = TRUE)
#> # A tibble: 7 × 15
#>   participant_id arm            age age_group sex   ethnicity eligible_screen
#>   <chr>          <chr>        <dbl> <chr>     <chr> <chr>     <lgl>          
#> 1 P0012          Control         38 18-39     F     Asian     TRUE           
#> 2 P0049          Control         26 18-39     F     European  TRUE           
#> 3 P0063          Intervention    61 40-64     M     European  TRUE           
#> 4 P0125          Intervention    28 18-39     F     Pacific   TRUE           
#> 5 P0129          Intervention    48 40-64     F     European  TRUE           
#> 6 P0138          Intervention    27 18-39     M     Asian     TRUE           
#> 7 P0184          Control         34 18-39     M     Asian     TRUE           
#> # ℹ 8 more variables: consent_date <date>, baseline_complete <lgl>,
#> #   withdrew <lgl>, .cf_row_id <int>, cf_step <int>, cf_label <chr>,
#> #   cf_type <chr>, cf_category <chr>
```
