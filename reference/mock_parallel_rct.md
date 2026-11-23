# Generate synthetic data for a parallel-group randomised controlled trial

Produces one row per participant, individually randomised to one of
`length(arm_labels)` arms with equal allocation. No clustering or
repeated measures – the simplest of the four designs.

## Usage

``` r
mock_parallel_rct(
  n_participants = 300L,
  arm_labels = c("Control", "Intervention"),
  seed = 123L
)
```

## Arguments

- n_participants:

  Integer. Total number of participants.

- arm_labels:

  Character vector. Labels for the trial arms (allocation is balanced
  across these labels).

- seed:

  Integer. Random seed for reproducibility.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with one row per participant, including `participant_id`, `arm`,
demographic columns (`age`, `age_group`, `sex`, `ethnicity`), and
consent-flow columns (`eligible_screen`, `consent_date`,
`baseline_complete`, `withdrew`).

## See also

Other mock data:
[`mock_cluster_rct()`](https://mattmoo.github.io/cohortflow/reference/mock_cluster_rct.md),
[`mock_crossover()`](https://mattmoo.github.io/cohortflow/reference/mock_crossover.md),
[`mock_stepped_wedge()`](https://mattmoo.github.io/cohortflow/reference/mock_stepped_wedge.md)

## Examples

``` r
mock_parallel_rct()
#> # A tibble: 300 × 10
#>    participant_id arm            age age_group sex   ethnicity eligible_screen
#>    <chr>          <chr>        <dbl> <chr>     <chr> <chr>     <lgl>          
#>  1 P0001          Control         57 40-64     M     European  FALSE          
#>  2 P0002          Control         57 40-64     F     European  FALSE          
#>  3 P0003          Control         50 40-64     M     European  TRUE           
#>  4 P0004          Intervention    30 18-39     F     Asian     TRUE           
#>  5 P0005          Control         43 40-64     M     European  TRUE           
#>  6 P0006          Intervention    41 40-64     M     European  TRUE           
#>  7 P0007          Intervention    53 40-64     F     European  TRUE           
#>  8 P0008          Intervention    39 18-39     M     European  TRUE           
#>  9 P0009          Control         60 40-64     M     European  TRUE           
#> 10 P0010          Control         39 18-39     M     European  TRUE           
#> # ℹ 290 more rows
#> # ℹ 3 more variables: consent_date <date>, baseline_complete <lgl>,
#> #   withdrew <lgl>
mock_parallel_rct(n_participants = 300, arm_labels = c("Placebo", "Drug"), seed = 7)
#> # A tibble: 300 × 10
#>    participant_id arm       age age_group sex   ethnicity eligible_screen
#>    <chr>          <chr>   <dbl> <chr>     <chr> <chr>     <lgl>          
#>  1 P0001          Drug       40 40-64     M     Maori     FALSE          
#>  2 P0002          Placebo    61 40-64     M     European  TRUE           
#>  3 P0003          Placebo    NA NA        M     Maori     TRUE           
#>  4 P0004          Drug       42 40-64     M     Maori     TRUE           
#>  5 P0005          Placebo    NA NA        F     European  TRUE           
#>  6 P0006          Drug       33 18-39     F     Asian     FALSE          
#>  7 P0007          Placebo    21 18-39     F     Other     TRUE           
#>  8 P0008          Drug       63 40-64     F     European  TRUE           
#>  9 P0009          Drug       63 40-64     M     European  TRUE           
#> 10 P0010          Drug       45 40-64     F     Asian     TRUE           
#> # ℹ 290 more rows
#> # ℹ 3 more variables: consent_date <date>, baseline_complete <lgl>,
#> #   withdrew <lgl>
```
