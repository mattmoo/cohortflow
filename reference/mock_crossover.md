# Generate synthetic data for a crossover trial

Produces one row per participant per period. Each participant is
assigned a randomisation `sequence` (e.g. `"AB"` or `"BA"` for a
two-period, two-treatment design), and the `arm` in each period is
derived from that sequence – so participants genuinely switch treatments
across periods rather than `arm` being an unused label.

## Usage

``` r
mock_crossover(n_participants = 120L, arm_labels = c("A", "B"), seed = 123L)
```

## Arguments

- n_participants:

  Integer. Number of participants.

- arm_labels:

  Character vector. Labels for the treatments being crossed over.
  Determines both the number of periods (`length(arm_labels)`) and the
  number of possible sequences (all permutations of `arm_labels`).

- seed:

  Integer. Random seed for reproducibility.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with one row per participant per period, including `participant_id`,
`event_id`, `period`, `sequence`, `arm`, demographic columns, and
consent-flow columns. Consent-flow columns (`eligible_screen`,
`consent_date`, `baseline_complete`, `withdrew`) are constant within a
participant across periods, since they describe trial-level (not
period-level) status; `withdrew` reflects withdrawal at any point during
the trial.

## See also

Other mock data:
[`mock_cluster_rct()`](https://mattmoo.github.io/cohortflow/reference/mock_cluster_rct.md),
[`mock_parallel_rct()`](https://mattmoo.github.io/cohortflow/reference/mock_parallel_rct.md),
[`mock_stepped_wedge()`](https://mattmoo.github.io/cohortflow/reference/mock_stepped_wedge.md)

## Examples

``` r
mock_crossover()
#> # A tibble: 240 × 13
#>    participant_id event_id period sequence arm     age age_group sex   ethnicity
#>    <chr>          <chr>     <int> <chr>    <chr> <dbl> <chr>     <chr> <chr>    
#>  1 P0001          E00001        1 AB       A        51 40-64     F     European 
#>  2 P0001          E00002        2 AB       B        51 40-64     F     European 
#>  3 P0002          E00003        1 AB       A        NA NA        F     Maori    
#>  4 P0002          E00004        2 AB       B        NA NA        F     Maori    
#>  5 P0003          E00005        1 AB       A        40 40-64     F     European 
#>  6 P0003          E00006        2 AB       B        40 40-64     F     European 
#>  7 P0004          E00007        1 BA       B        30 18-39     M     Asian    
#>  8 P0004          E00008        2 BA       A        30 18-39     M     Asian    
#>  9 P0005          E00009        1 AB       A        29 18-39     F     Other    
#> 10 P0005          E00010        2 AB       B        29 18-39     F     Other    
#> # ℹ 230 more rows
#> # ℹ 4 more variables: eligible_screen <lgl>, consent_date <date>,
#> #   baseline_complete <lgl>, withdrew <lgl>
mock_crossover(n_participants = 60, arm_labels = c("Drug", "Placebo"), seed = 3)
#> # A tibble: 120 × 13
#>    participant_id event_id period sequence arm     age age_group sex   ethnicity
#>    <chr>          <chr>     <int> <chr>    <chr> <dbl> <chr>     <chr> <chr>    
#>  1 P0001          E00001        1 DrugPla… Drug     59 40-64     F     Maori    
#>  2 P0001          E00002        2 DrugPla… Plac…    59 40-64     F     Maori    
#>  3 P0002          E00003        1 Placebo… Plac…    58 40-64     F     European 
#>  4 P0002          E00004        2 Placebo… Drug     58 40-64     F     European 
#>  5 P0003          E00005        1 Placebo… Plac…    56 40-64     M     European 
#>  6 P0003          E00006        2 Placebo… Drug     56 40-64     M     European 
#>  7 P0004          E00007        1 DrugPla… Drug     56 40-64     F     Other    
#>  8 P0004          E00008        2 DrugPla… Plac…    56 40-64     F     Other    
#>  9 P0005          E00009        1 Placebo… Plac…    40 40-64     F     Asian    
#> 10 P0005          E00010        2 Placebo… Drug     40 40-64     F     Asian    
#> # ℹ 110 more rows
#> # ℹ 4 more variables: eligible_screen <lgl>, consent_date <date>,
#> #   baseline_complete <lgl>, withdrew <lgl>
```
