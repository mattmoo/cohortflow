# Select rows within groups

The predicate is evaluated separately within each group defined by `by`
and must return a logical vector the same length as the group. Rows
where the predicate is `FALSE` are dropped and recorded in the excluded
rows store. This is the natural way to select one (or more) records per
unit, e.g. the index operation per patient.

## Usage

``` r
select_within(criteria, by, predicate, label, category = NULL, reason = NULL)
```

## Arguments

- criteria:

  A `cf_criteria` object (or `NULL` to start a new one).

- by:

  One or more column names (character vector) defining the grouping
  (e.g. `"participant_id"`); supply more than one for composite
  (multi-column) grouping.

- predicate:

  A one-sided formula evaluated within each group, or a function that
  receives a group's rows as a data frame and returns a logical vector.

- label:

  A short human-readable description of this step.

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
[`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md),
[`include()`](https://mattmoo.github.io/cohortflow/reference/include.md),
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)

## Examples

``` r
cf_criteria() |>
  select_within(by = "participant_id",
                ~ consent_date == min(consent_date, na.rm = TRUE),
                label = "Index operation per patient")
#> Cohort criteria pipeline  (1 step)
#>    1. [>][~] (select_within) [by: participant_id] Index operation per patient
#>           consent_date == min(consent_date, na.rm = TRUE)
```
