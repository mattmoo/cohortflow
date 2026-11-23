# Add a group-level exclusion criterion

The predicate is evaluated per group; groups where the predicate returns
`TRUE` are removed (all their rows dropped).

## Usage

``` r
group_exclude(criteria, by, predicate, label, category = NULL, reason = NULL)
```

## Arguments

- criteria:

  A `cf_criteria` object (or `NULL` to start a new one).

- by:

  One or more column names (character vector) to group by; supply more
  than one for composite (multi-column) grouping.

- predicate:

  A one-sided formula using summary functions, or a function.

- label:

  A short human-readable description of this criterion.

- category:

  An optional string grouping this step with others for display. `NULL`
  leaves it uncategorised.

- reason:

  An optional short description of the rows this step removes, shown in
  diagram exclusion boxes. `NULL` (default) uses `label` for exclusion
  steps; for inclusion steps it should be set. See the Labels section.

## Value

The updated `cf_criteria` object.

## See also

Other criteria builders:
[`cf_criteria()`](https://mattmoo.github.io/cohortflow/reference/cf_criteria.md),
[`cf_criterion()`](https://mattmoo.github.io/cohortflow/reference/cf_criterion.md),
[`check_criteria()`](https://mattmoo.github.io/cohortflow/reference/check_criteria.md),
[`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md),
[`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md),
[`include()`](https://mattmoo.github.io/cohortflow/reference/include.md),
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md),
[`select_within()`](https://mattmoo.github.io/cohortflow/reference/select_within.md)

## Examples

``` r
cf_criteria() |>
  group_exclude(by = "cluster_id", ~ mean(is.na(age)) > 0.5,
                label = "Excessive missing age in cluster")
#> Cohort criteria pipeline  (1 step)
#>    1. [-][~] (group_exclude) [by: cluster_id] Excessive missing age in cluster
#>           mean(is.na(age)) > 0.5
```
