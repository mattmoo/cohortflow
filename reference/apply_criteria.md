# Apply a criteria pipeline to a data frame

Evaluates each step in a `cf_criteria` pipeline cumulatively against a
data frame, recording which rows are removed at each step. Returns a
`cf_flow` object from which the surviving cohort
([`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md))
and excluded rows
([`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md))
can be extracted.

## Usage

``` r
apply_criteria(
  data,
  criteria,
  id = NULL,
  expected = NULL,
  by = NULL,
  hierarchy = NULL
)
```

## Arguments

- data:

  A data frame.

- criteria:

  A `cf_criteria` object.

- id:

  One or more column names (character vector) to use as the row
  identifier; supply more than one for a composite (multi-column) key.
  If `NULL` (default), the function looks for `.cf_row_id` in `data`; if
  not found, a sequential integer is added.

- expected:

  Optional data frame (typically built with
  [`cf_expected()`](https://mattmoo.github.io/cohortflow/reference/cf_expected.md))
  listing every observational unit that is expected to exist, e.g. one
  row per participant. When supplied, `data` is right-joined onto
  `expected` (by `by`) *before* any steps are evaluated, so units with
  no matching row in `data` are added as all-`NA` (except for the `by`
  column(s)) and are counted correctly as failing the first step that
  requires non-missing data. Requires `by`.

- by:

  Column name(s) shared by `data` and `expected` used to join them.
  Required, and only used, when `expected` is supplied.

- hierarchy:

  Optional `cf_hierarchy` describing how rows nest into coarser units
  (e.g. participants within clusters). When supplied, every hierarchy
  column is validated against `data`, and each step record additionally
  stores the number of distinct units at risk/passing/failing at every
  level (see
  [`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)'s
  `levels` argument).

## Value

A `cf_flow` object.

## Details

Before any step is evaluated,
[`check_criteria()`](https://mattmoo.github.io/cohortflow/reference/check_criteria.md)
verifies that every step refers only to columns present in `data` (after
any `expected` join).

## Row identity

`apply_criteria()` needs a stable row identifier to track exclusions. By
default it looks for a `.cf_row_id` column in `data`. If one is not
found and `id` is `NULL`, a sequential integer identifier is added
automatically (with a message). Supply `id` to use an existing column as
the identifier.

The identifier (whether supplied via `id` or a pre-existing `.cf_row_id`
column) must uniquely identify every row: it may contain neither
duplicates nor `NA` values, and `apply_criteria()` aborts if it does.
For designs with several rows per participant (e.g. crossover or
stepped-wedge data), use a row-level identifier such as `event_id`, not
the participant identifier.

## Step types

|  |  |  |
|----|----|----|
| Type | Predicate | Effect |
| `include` | Row-wise logical vector | Keep `TRUE` rows |
| `exclude` | Row-wise logical vector | Drop `TRUE` rows |
| `group_include` | Per-group scalar (summarise context) | Keep rows in groups where result is `TRUE` |
| `group_exclude` | Per-group scalar (summarise context) | Drop rows in groups where result is `TRUE` |
| `select_within` | Per-group logical vector | Keep `TRUE` rows within each group |
| `randomise` | None (`predicate = NULL`) | Records the randomisation unit and arm column for downstream reporting |

Rows whose `by` value is `NA` cannot be assigned to a group and are
always removed by grouped step types (`group_include`, `group_exclude`,
`select_within`).

## See also

Other pipeline:
[`cf_expected()`](https://mattmoo.github.io/cohortflow/reference/cf_expected.md),
[`cf_hierarchy()`](https://mattmoo.github.io/cohortflow/reference/cf_hierarchy.md),
[`continue_criteria()`](https://mattmoo.github.io/cohortflow/reference/continue_criteria.md)

## Examples

``` r
dat  <- mock_cluster_rct(n_participants = 200, seed = 1)
crit <- cf_criteria() |>
  include(~ eligible_screen, label = "Passed screening") |>
  include(~ !is.na(consent_date), label = "Consent recorded", category = "Consent") |>
  exclude(~ withdrew, label = "Withdrew consent", category = "Consent") |>
  group_include(by = "cluster_id", ~ n() >= 5,
                label = "Cluster size >= 5")

flow <- apply_criteria(dat, crit)
#> No `id` supplied and no `.cf_row_id` column found. Adding a sequential `.cf_row_id`.
flow
#> Cohort flow  (4 steps | 200 -> 145 rows | 55 excluded)
#> ------------------------------------------------------------
#>    1. [+] Passed screening
#>        n_in: 200  kept: 177  removed: 23
#>    2. [+] Consent recorded {Consent}
#>        n_in: 177  kept: 155  removed: 22
#>    3. [-] Withdrew consent {Consent}
#>        n_in: 155  kept: 145  removed: 10
#>    4. [+] Cluster size >= 5 by cluster_id
#>        n_in: 145  kept: 145  removed: 0
cohort(flow)
#> # A tibble: 145 × 12
#>    participant_id cluster_id site_id arm           age age_group sex   ethnicity
#>    <chr>          <chr>      <chr>   <chr>       <dbl> <chr>     <chr> <chr>    
#>  1 P0001          C09        S1      Interventi…    50 40-64     F     Other    
#>  2 P0003          C02        S2      Interventi…    40 40-64     M     European 
#>  3 P0004          C05        S2      Interventi…    37 18-39     M     Asian    
#>  4 P0005          C02        S2      Interventi…    35 18-39     F     Asian    
#>  5 P0006          C02        S2      Interventi…    44 40-64     F     Maori    
#>  6 P0007          C04        S2      Control        16 <18       F     European 
#>  7 P0008          C03        S2      Control        63 40-64     M     European 
#>  8 P0009          C03        S2      Control        20 18-39     F     European 
#>  9 P0011          C11        S1      Interventi…    28 18-39     M     European 
#> 10 P0012          C10        S1      Control        34 18-39     M     European 
#> # ℹ 135 more rows
#> # ℹ 4 more variables: eligible_screen <lgl>, consent_date <date>,
#> #   baseline_complete <lgl>, withdrew <lgl>
excluded(flow)
#> # A tibble: 55 × 17
#>    participant_id cluster_id site_id arm           age age_group sex   ethnicity
#>    <chr>          <chr>      <chr>   <chr>       <dbl> <chr>     <chr> <chr>    
#>  1 P0002          C03        S2      Control        22 18-39     M     Pacific  
#>  2 P0015          C02        S2      Interventi…    26 18-39     M     European 
#>  3 P0031          C05        S2      Interventi…    36 18-39     F     Maori    
#>  4 P0070          C04        S2      Control        40 40-64     M     European 
#>  5 P0075          C09        S1      Interventi…    45 40-64     F     Pacific  
#>  6 P0079          C09        S1      Interventi…    39 18-39     M     European 
#>  7 P0094          C03        S2      Control        21 18-39     F     European 
#>  8 P0098          C02        S2      Interventi…     5 <18       O     Asian    
#>  9 P0107          C02        S2      Interventi…    56 40-64     F     Other    
#> 10 P0108          C03        S2      Control        61 40-64     F     European 
#> # ℹ 45 more rows
#> # ℹ 9 more variables: eligible_screen <lgl>, consent_date <date>,
#> #   baseline_complete <lgl>, withdrew <lgl>, .cf_row_id <int>, cf_step <int>,
#> #   cf_label <chr>, cf_type <chr>, cf_category <chr>
```
