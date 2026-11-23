# Mark the randomisation/allocation point in a criteria pipeline

`randomise()` records where allocation happens in the pipeline without
excluding any rows (`n_fail` is always `0`).
[`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md)
and
[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
use its `by`/`arms` to default `branch_by` when not explicitly supplied,
and steps at or after it are flagged `post_randomisation` in
[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)'s
output.

## Usage

``` r
randomise(criteria, by, arms, label = "Randomised", category = NULL)
```

## Arguments

- criteria:

  A `cf_criteria` object (or `NULL` to start a new one).

- by:

  One or more column names (character vector) naming the randomisation
  unit (e.g. `"cluster_id"` for cluster randomisation, or the
  participant id for individual randomisation).

- arms:

  A single column name (string) holding each unit's allocated arm (e.g.
  `"arm"`).

- label:

  A short human-readable description of this step. Default
  `"Randomised"` (unlike other builders, a label is not required).

- category:

  An optional string grouping this step with others for display. `NULL`
  leaves it uncategorised.

## Value

The updated `cf_criteria` object.

## See also

Other criteria builders:
[`cf_criteria()`](https://mattmoo.github.io/cohortflow/reference/cf_criteria.md),
[`cf_criterion()`](https://mattmoo.github.io/cohortflow/reference/cf_criterion.md),
[`check_criteria()`](https://mattmoo.github.io/cohortflow/reference/check_criteria.md),
[`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md),
[`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md),
[`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md),
[`include()`](https://mattmoo.github.io/cohortflow/reference/include.md),
[`select_within()`](https://mattmoo.github.io/cohortflow/reference/select_within.md)

## Examples

``` r
cf_criteria() |>
  include(~ eligible, label = "Eligible clusters") |>
  randomise(by = "cluster_id", arms = "arm") |>
  exclude(~ withdrew, label = "Withdrew after allocation")
#> Cohort criteria pipeline  (3 steps)
#>    1. [+][~] (include) Eligible clusters
#>           eligible
#>    2. [R][-] (randomise) [by: cluster_id] [arms: arm] Randomised
#>           <none>
#>    3. [-][~] (exclude) Withdrew after allocation
#>           withdrew
```
