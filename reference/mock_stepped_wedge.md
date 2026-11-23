# Generate synthetic data for a stepped-wedge cluster-randomised trial

Produces one row per participant per period, with clusters nested within
sites. Each cluster is assigned a crossover `sequence` – the period in
which it switches from control to intervention – and every cluster
eventually receives the intervention (the defining feature of a stepped
wedge). The `arm` for a given participant-period row is derived from
whether the current `period` has reached the cluster's `sequence`
(`period >= sequence`), so treatment assignment is genuinely driven by
the roll-out schedule rather than an unused column.

## Usage

``` r
mock_stepped_wedge(
  n_clusters = 12L,
  n_participants = 480L,
  n_periods = 4L,
  n_sites = 3L,
  arm_labels = c("Control", "Intervention"),
  seed = 123L
)
```

## Arguments

- n_clusters:

  Integer. Number of clusters.

- n_participants:

  Integer. Total number of participants (each contributes one row per
  period), distributed unevenly across clusters.

- n_periods:

  Integer. Number of periods, including the initial all-control period.
  Must be \>= 2 (clusters need at least one period before crossover and
  one after).

- n_sites:

  Integer. Number of sites (clusters nested in sites; must be \<=
  `n_clusters`).

- arm_labels:

  Character vector of length 2: `c(control_label, intervention_label)`.

- seed:

  Integer. Random seed for reproducibility.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with one row per participant per period, including `participant_id`,
`event_id`, `cluster_id`, `site_id`, `period`, `sequence`, `arm`
(derived from `period >= sequence`), demographic columns, and
consent-flow columns.

## See also

Other mock data:
[`mock_cluster_rct()`](https://mattmoo.github.io/cohortflow/reference/mock_cluster_rct.md),
[`mock_crossover()`](https://mattmoo.github.io/cohortflow/reference/mock_crossover.md),
[`mock_parallel_rct()`](https://mattmoo.github.io/cohortflow/reference/mock_parallel_rct.md)

## Examples

``` r
mock_stepped_wedge()
#> # A tibble: 1,920 × 15
#>    participant_id event_id cluster_id site_id period sequence arm            age
#>    <chr>          <chr>    <chr>      <chr>    <int>    <int> <chr>        <dbl>
#>  1 P0001          E00001   C07        S2           1        2 Control         37
#>  2 P0001          E00002   C07        S2           2        2 Intervention    37
#>  3 P0001          E00003   C07        S2           3        2 Intervention    37
#>  4 P0001          E00004   C07        S2           4        2 Intervention    37
#>  5 P0002          E00005   C02        S3           1        3 Control         52
#>  6 P0002          E00006   C02        S3           2        3 Control         52
#>  7 P0002          E00007   C02        S3           3        3 Intervention    52
#>  8 P0002          E00008   C02        S3           4        3 Intervention    52
#>  9 P0003          E00009   C03        S3           1        4 Control         59
#> 10 P0003          E00010   C03        S3           2        4 Control         59
#> # ℹ 1,910 more rows
#> # ℹ 7 more variables: age_group <chr>, sex <chr>, ethnicity <chr>,
#> #   eligible_screen <lgl>, consent_date <date>, baseline_complete <lgl>,
#> #   withdrew <lgl>
mock_stepped_wedge(n_clusters = 8, n_participants = 400, n_periods = 5, seed = 9)
#> # A tibble: 2,000 × 15
#>    participant_id event_id cluster_id site_id period sequence arm            age
#>    <chr>          <chr>    <chr>      <chr>    <int>    <int> <chr>        <dbl>
#>  1 P0001          E00001   C05        S3           1        2 Control         68
#>  2 P0001          E00002   C05        S3           2        2 Intervention    68
#>  3 P0001          E00003   C05        S3           3        2 Intervention    68
#>  4 P0001          E00004   C05        S3           4        2 Intervention    68
#>  5 P0001          E00005   C05        S3           5        2 Intervention    68
#>  6 P0002          E00006   C05        S3           1        2 Control         41
#>  7 P0002          E00007   C05        S3           2        2 Intervention    41
#>  8 P0002          E00008   C05        S3           3        2 Intervention    41
#>  9 P0002          E00009   C05        S3           4        2 Intervention    41
#> 10 P0002          E00010   C05        S3           5        2 Intervention    41
#> # ℹ 1,990 more rows
#> # ℹ 7 more variables: age_group <chr>, sex <chr>, ethnicity <chr>,
#> #   eligible_screen <lgl>, consent_date <date>, baseline_complete <lgl>,
#> #   withdrew <lgl>
```
