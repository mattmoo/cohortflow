# Add a group-level inclusion criterion

The predicate is evaluated in a
[`dplyr::summarise()`](https://dplyr.tidyverse.org/reference/summarise.html)
context per group (when a formula) or receives a grouped data frame
(when a function). Groups where the predicate returns `TRUE` are kept;
all rows in failing groups are removed.

## Usage

``` r
group_include(criteria, by, predicate, label, category = NULL, reason = NULL)
```

## Arguments

- criteria:

  A `cf_criteria` object (or `NULL` to start a new one).

- by:

  One or more column names (character vector) to group by; supply more
  than one for composite (multi-column) grouping.

- predicate:

  A one-sided formula using summary functions (`n()`,
  [`mean()`](https://rdrr.io/r/base/mean.html), `n_distinct()`, etc.) or
  a function that receives a grouped data frame and returns a tibble
  with columns `<by>` and `.pass`.

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
[`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md),
[`include()`](https://mattmoo.github.io/cohortflow/reference/include.md),
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md),
[`select_within()`](https://mattmoo.github.io/cohortflow/reference/select_within.md)

## Examples

``` r
cf_criteria() |>
  group_include(by = "cluster_id", ~ n() >= 5, label = "Cluster size >= 5")
#> Cohort criteria pipeline  (1 step)
#>    1. [+][~] (group_include) [by: cluster_id] Cluster size >= 5
#>           n() >= 5
```
