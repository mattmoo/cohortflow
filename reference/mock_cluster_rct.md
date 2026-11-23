# Generate synthetic data for a cluster-randomised controlled trial

Produces one row per participant, nested within clusters (e.g. GP
practices, schools) that are themselves nested within sites. Each
cluster – not each participant – is randomised to an arm, so all
participants within a cluster share the same `arm`.

## Usage

``` r
mock_cluster_rct(
  n_clusters = 12L,
  n_participants = 480L,
  n_sites = 3L,
  arm_labels = c("Control", "Intervention"),
  seed = 123L
)
```

## Arguments

- n_clusters:

  Integer. Number of clusters.

- n_participants:

  Integer. Total number of participants, distributed unevenly across
  clusters.

- n_sites:

  Integer. Number of sites (clusters nested in sites; must be \<=
  `n_clusters`).

- arm_labels:

  Character vector. Labels for the trial arms; clusters are allocated to
  these labels with balanced randomisation.

- seed:

  Integer. Random seed for reproducibility.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with one row per participant, including `participant_id`, `cluster_id`,
`site_id`, `arm` (cluster-level), demographic columns, and consent-flow
columns.

## See also

Other mock data:
[`mock_crossover()`](https://mattmoo.github.io/cohortflow/reference/mock_crossover.md),
[`mock_parallel_rct()`](https://mattmoo.github.io/cohortflow/reference/mock_parallel_rct.md),
[`mock_stepped_wedge()`](https://mattmoo.github.io/cohortflow/reference/mock_stepped_wedge.md)

## Examples

``` r
mock_cluster_rct()
#> # A tibble: 480 × 12
#>    participant_id cluster_id site_id arm           age age_group sex   ethnicity
#>    <chr>          <chr>      <chr>   <chr>       <dbl> <chr>     <chr> <chr>    
#>  1 P0001          C08        S1      Interventi…    55 40-64     M     European 
#>  2 P0002          C10        S2      Interventi…    24 18-39     F     European 
#>  3 P0003          C08        S1      Interventi…    58 40-64     M     Asian    
#>  4 P0004          C08        S1      Interventi…    38 18-39     M     European 
#>  5 P0005          C08        S1      Interventi…    48 40-64     M     European 
#>  6 P0006          C10        S2      Interventi…    46 40-64     F     Maori    
#>  7 P0007          C11        S3      Control        51 40-64     F     Other    
#>  8 P0008          C10        S2      Interventi…    45 40-64     F     European 
#>  9 P0009          C11        S3      Control        20 18-39     F     Asian    
#> 10 P0010          C01        S3      Control        56 40-64     F     European 
#> # ℹ 470 more rows
#> # ℹ 4 more variables: eligible_screen <lgl>, consent_date <date>,
#> #   baseline_complete <lgl>, withdrew <lgl>
mock_cluster_rct(n_clusters = 20, n_participants = 800, seed = 5)
#> # A tibble: 800 × 12
#>    participant_id cluster_id site_id arm           age age_group sex   ethnicity
#>    <chr>          <chr>      <chr>   <chr>       <dbl> <chr>     <chr> <chr>    
#>  1 P0001          C12        S2      Interventi…    41 40-64     M     Maori    
#>  2 P0002          C17        S2      Interventi…    51 40-64     M     European 
#>  3 P0003          C17        S2      Interventi…    17 <18       F     European 
#>  4 P0004          C14        S3      Interventi…    48 40-64     F     European 
#>  5 P0005          C10        S1      Control        55 40-64     M     European 
#>  6 P0006          C08        S2      Control        59 40-64     F     European 
#>  7 P0007          C09        S3      Control        65 65+       F     Maori    
#>  8 P0008          C10        S1      Control        70 65+       M     Maori    
#>  9 P0009          C05        S2      Control        35 18-39     F     European 
#> 10 P0010          C03        S2      Control        52 40-64     F     European 
#> # ℹ 790 more rows
#> # ℹ 4 more variables: eligible_screen <lgl>, consent_date <date>,
#> #   baseline_complete <lgl>, withdrew <lgl>
```
