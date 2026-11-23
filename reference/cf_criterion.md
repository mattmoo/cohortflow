# Create a single cohort criterion

A `cf_criterion` represents one inclusion or exclusion step in a cohort
eligibility pipeline. Five step types are supported (see `type`). The
predicate is always a one-sided **formula** or a **function**; the
interpretation depends on the step type.

## Usage

``` r
cf_criterion(
  predicate,
  label,
  type = c("include", "exclude", "group_include", "group_exclude", "select_within",
    "randomise"),
  by = NULL,
  category = NULL,
  arms = NULL,
  reason = NULL
)
```

## Arguments

- predicate:

  A one-sided formula or a function.

  - For `include` / `exclude`: evaluated row-wise; must return a logical
    vector of length `nrow(data)`.

  - For `group_include` / `group_exclude`: evaluated in a
    [`dplyr::summarise()`](https://dplyr.tidyverse.org/reference/summarise.html)
    context per group (defined by `by`); must return a scalar logical.
    The result is broadcast back to all rows in each group.

  - For `select_within`: evaluated per group; must return a logical
    vector identifying which rows within the group to keep.

  - For `randomise`: must be `NULL` (a randomise step never removes
    rows).

  Formula predicates are evaluated with a data mask, so the rlang
  pronouns work in every step type: `.data$age` always refers to the
  column and `.env$age` to a variable in the formula's environment,
  which avoids ambiguity when a column and a local variable share a
  name.

- label:

  A short human-readable description of this criterion.

- type:

  One of `"include"`, `"exclude"`, `"group_include"`, `"group_exclude"`,
  `"select_within"`, or `"randomise"`.

- by:

  For grouped step types (`group_include`, `group_exclude`,
  `select_within`): one or more character strings naming the grouping
  column(s); supply more than one for composite (multi-column) grouping.
  For `randomise`: one or more character strings naming the
  randomisation unit column(s) (e.g. `"cluster_id"`). Must be `NULL` for
  the row-wise types (`include`, `exclude`). Rows with an `NA` in any
  `by` column cannot be assigned to a group and are always removed by
  grouped step types.

- category:

  An optional character string grouping this criterion with others for
  display purposes (e.g. `"Valid age"` to group age-related steps into
  one box in a CONSORT diagram). `NULL` (default) leaves the step
  uncategorised (`NA` in output).

- arms:

  For `type = "randomise"` only: a single character string naming the
  column in the data that holds each unit's allocated arm (e.g.
  `"arm"`). Used by
  [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md)/[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
  to default `branch_by` when not explicitly supplied. Must be `NULL`
  for all other types.

- reason:

  An optional short description of the rows this step *removes*, used
  wherever removals are listed: the exclusion boxes of
  [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md).
  `NULL` (default) falls back to `label` for the exclusion types
  (`exclude`, `group_exclude`), whose label already describes the
  removed rows. For `include`, `group_include` and `select_within` the
  label describes the rows *kept*, so set `reason` (e.g.
  `label = "Aged 18 or over", reason = "Under 18"`). Must be `NULL` for
  `randomise`. See the Labels section of
  [`include()`](https://mattmoo.github.io/cohortflow/reference/include.md).

## Value

A `cf_criterion` object (an S3 list).

## See also

Other criteria builders:
[`cf_criteria()`](https://mattmoo.github.io/cohortflow/reference/cf_criteria.md),
[`check_criteria()`](https://mattmoo.github.io/cohortflow/reference/check_criteria.md),
[`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md),
[`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md),
[`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md),
[`include()`](https://mattmoo.github.io/cohortflow/reference/include.md),
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md),
[`select_within()`](https://mattmoo.github.io/cohortflow/reference/select_within.md)

## Examples

``` r
# Row-wise inclusion
cf_criterion(~ age >= 18, label = "Adults only", type = "include")
#> [+][~] Adults only
#>     age >= 18

# Grouped under a category, with the text shown for the rows it removes
cf_criterion(~ !is.na(age), label = "Age recorded",
             type = "include", category = "Valid age", reason = "Age missing")
#> [+][~] Age recorded
#>     !is.na(age)
#>     removes: Age missing

# Group-level inclusion (clusters with >= 5 participants)
cf_criterion(
  ~ n() >= 5,
  label = "Sufficient cluster size",
  type  = "group_include",
  by    = "cluster_id"
)
#> [+][~] Sufficient cluster size [by: cluster_id]
#>     n() >= 5

# Select first operation per patient
cf_criterion(
  ~ consent_date == min(consent_date, na.rm = TRUE),
  label = "Index operation",
  type  = "select_within",
  by    = "participant_id"
)
#> [>][~] Index operation [by: participant_id]
#>     consent_date == min(consent_date, na.rm = TRUE)

# Randomisation marker (no predicate; excludes nothing)
cf_criterion(
  predicate = NULL,
  label = "Randomised",
  type  = "randomise",
  by    = "cluster_id",
  arms  = "arm"
)
#> [R][-] Randomised [by: cluster_id] [arms: arm]
#>     <none>
```
