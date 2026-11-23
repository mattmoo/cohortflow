# Generate synthetic cohort data for testing and examples (deprecated)

**Deprecated.** `mock_cohortflow()` is deprecated in favour of
design-specific generators that produce realistic data for common study
designs:
[`mock_parallel_rct()`](https://mattmoo.github.io/cohortflow/reference/mock_parallel_rct.md),
[`mock_crossover()`](https://mattmoo.github.io/cohortflow/reference/mock_crossover.md),
[`mock_cluster_rct()`](https://mattmoo.github.io/cohortflow/reference/mock_cluster_rct.md),
and
[`mock_stepped_wedge()`](https://mattmoo.github.io/cohortflow/reference/mock_stepped_wedge.md).
Those functions include an explicit `arm` column and design-appropriate
structure (e.g. cluster-level randomisation, within-participant
crossover sequences, stepped-wedge roll-out), which `mock_cohortflow()`
never modelled.

Produces a tibble that mimics a clustered cohort study with optional
stepped-wedge period structure. The returned data is deliberately
imperfect: some participants have missing values, withdrew consent, or
failed screening, so that inclusion/exclusion criteria have something to
remove.

## Usage

``` r
mock_cohortflow(
  n_participants = 500L,
  n_clusters = 10L,
  n_sites = 3L,
  n_periods = 4L,
  seed = 123L
)
```

## Arguments

- n_participants:

  Integer. Total number of participant rows.

- n_clusters:

  Integer. Number of clusters (e.g., GP practices, schools).

- n_sites:

  Integer. Number of sites (clusters are nested in sites; must be \<=
  `n_clusters`).

- n_periods:

  Integer. Number of time periods (e.g., waves in a stepped-wedge
  design). Set to `1` for a simple cross-sectional cohort.

- seed:

  Integer. Random seed for reproducibility.

## Value

A
[`tibble::tibble()`](https://tibble.tidyverse.org/reference/tibble.html)
with columns:

- `participant_id`:

  Character. Unique participant identifier.

- `event_id`:

  Character. Unique event (row) identifier – useful when the dataset has
  multiple rows per participant (e.g., one per operation).

- `cluster_id`:

  Character. Cluster identifier.

- `site_id`:

  Character. Site identifier (clusters nested in sites).

- `period`:

  Integer. Study period (1 = first period).

- `sequence`:

  Integer. Stepped-wedge sequence the cluster is assigned to (NA if
  `n_periods == 1`).

- `age`:

  Numeric. Age in years (some NAs to simulate missing data).

- `age_group`:

  Character. Age group (`"<18"`, `"18-39"`, `"40-64"`, `"65+"`).

- `sex`:

  Character. `"M"` / `"F"` / `"O"` (other).

- `ethnicity`:

  Character. One of five broad ethnic groups.

- `consent_date`:

  Date. Date of consent (NA = did not consent).

- `baseline_complete`:

  Logical. Whether the baseline assessment is complete.

- `withdrew`:

  Logical. Whether the participant withdrew after consent.

- `eligible_screen`:

  Logical. Whether the participant passed initial eligibility screening
  (e.g., diagnosis confirmed).

## Examples

``` r
mock_cohortflow()
#> Warning: `mock_cohortflow()` is deprecated and will be removed in a future version.
#> ℹ Use the generator for your design; each adds an `arm` column and the design's structure, which `mock_cohortflow()` never modelled:
#> • mock_parallel_rct(): individually randomised parallel-group trial.
#> • mock_cluster_rct(): clusters randomised (the closest match for `n_periods = 1`).
#> • mock_stepped_wedge(): clusters crossing over in periods (for `n_periods > 1`).
#> • mock_crossover(): each participant receives every arm, one row per period.
#> This warning is displayed once per session.
#> # A tibble: 500 × 14
#>    participant_id event_id cluster_id site_id period sequence   age age_group
#>    <chr>          <chr>    <chr>      <chr>    <int>    <int> <dbl> <chr>    
#>  1 P0001          E0001    C01        S3           4        1    46 40-64    
#>  2 P0002          E0002    C01        S3           4        1    23 18-39    
#>  3 P0003          E0003    C01        S3           3        1    12 <18      
#>  4 P0004          E0004    C01        S3           3        1    82 65+      
#>  5 P0005          E0005    C01        S3           4        1    59 40-64    
#>  6 P0006          E0006    C01        S3           4        1    46 40-64    
#>  7 P0007          E0007    C07        S2           3        3    36 18-39    
#>  8 P0008          E0008    C01        S3           2        1    35 18-39    
#>  9 P0009          E0009    C01        S3           3        1    54 40-64    
#> 10 P0010          E0010    C04        S2           4        4    31 18-39    
#> # ℹ 490 more rows
#> # ℹ 6 more variables: sex <chr>, ethnicity <chr>, eligible_screen <lgl>,
#> #   consent_date <date>, baseline_complete <lgl>, withdrew <lgl>

# Larger study with three periods
mock_cohortflow(n_participants = 2000, n_clusters = 20, n_periods = 3, seed = 42)
#> # A tibble: 2,000 × 14
#>    participant_id event_id cluster_id site_id period sequence   age age_group
#>    <chr>          <chr>    <chr>      <chr>    <int>    <int> <dbl> <chr>    
#>  1 P0001          E0001    C07        S2           2        1    27 18-39    
#>  2 P0002          E0002    C07        S2           3        1    61 40-64    
#>  3 P0003          E0003    C11        S1           3        2    82 65+      
#>  4 P0004          E0004    C02        S1           2        2    42 40-64    
#>  5 P0005          E0005    C03        S1           3        3    NA NA       
#>  6 P0006          E0006    C11        S1           2        2    54 40-64    
#>  7 P0007          E0007    C15        S2           1        3    29 18-39    
#>  8 P0008          E0008    C15        S2           3        3    33 18-39    
#>  9 P0009          E0009    C08        S1           3        2    62 40-64    
#> 10 P0010          E0010    C08        S1           3        2    NA NA       
#> # ℹ 1,990 more rows
#> # ℹ 6 more variables: sex <chr>, ethnicity <chr>, eligible_screen <lgl>,
#> #   consent_date <date>, baseline_complete <lgl>, withdrew <lgl>
```
