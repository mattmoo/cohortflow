# Create an eligibility criteria pipeline

`cf_criteria()` initialises an empty criteria pipeline. Use the pipe
operators
[`include()`](https://mattmoo.github.io/cohortflow/reference/include.md),
[`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md),
[`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md),
[`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md),
and
[`select_within()`](https://mattmoo.github.io/cohortflow/reference/select_within.md)
to add steps.

## Usage

``` r
cf_criteria(...)
```

## Arguments

- ...:

  Optional `cf_criterion` objects to include at construction time.

## Value

A `cf_criteria` object.

## See also

Other criteria builders:
[`cf_criterion()`](https://mattmoo.github.io/cohortflow/reference/cf_criterion.md),
[`check_criteria()`](https://mattmoo.github.io/cohortflow/reference/check_criteria.md),
[`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md),
[`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md),
[`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md),
[`include()`](https://mattmoo.github.io/cohortflow/reference/include.md),
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md),
[`select_within()`](https://mattmoo.github.io/cohortflow/reference/select_within.md)

## Examples

``` r
has_consent <- function(d) !is.na(d$consent_date)

crit <- cf_criteria() |>
  include(~ age >= 18, label = "Adults only") |>
  include(has_consent, label = "Consent recorded", category = "Consent") |>
  exclude(~ withdrew, label = "Withdrew consent", category = "Consent") |>
  group_include(by = "cluster_id", ~ n() >= 5, label = "Cluster size >= 5") |>
  select_within(by = "participant_id", ~ consent_date == min(consent_date, na.rm = TRUE),
                label = "Index operation")

crit
#> Cohort criteria pipeline  (5 steps)
#>    1. [+][~] (include) Adults only
#>           age >= 18
#>    2. [+][f] (include) {Consent} Consent recorded
#>           !is.na(d$consent_date)
#>    3. [-][~] (exclude) {Consent} Withdrew consent
#>           withdrew
#>    4. [+][~] (group_include) [by: cluster_id] Cluster size >= 5
#>           n() >= 5
#>    5. [>][~] (select_within) [by: participant_id] Index operation
#>           consent_date == min(consent_date, na.rm = TRUE)
```
