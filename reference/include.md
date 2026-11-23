# Add an inclusion criterion to a criteria pipeline

Add an inclusion criterion to a criteria pipeline

## Usage

``` r
include(criteria, predicate, label, category = NULL, reason = NULL)
```

## Arguments

- criteria:

  A `cf_criteria` object (or `NULL` to start a new one).

- predicate:

  A one-sided formula or a function evaluated row-wise.

- label:

  A short human-readable description of this criterion. See the Labels
  section.

- category:

  An optional string grouping this step with others for display (e.g.
  `"Valid age"`). `NULL` leaves it uncategorised.

- reason:

  An optional short description of the rows this step removes, shown in
  diagram exclusion boxes. `NULL` (default) uses `label` for exclusion
  steps; for inclusion steps it should be set. See the Labels section.

## Value

The updated `cf_criteria` object.

## Missing values

A predicate that evaluates to `NA` for a row is treated differently by
the two step types, and the difference changes denominators:

- `include()` treats `NA` as failing: the row is **removed**. Write
  `include(~ age >= 18)` and rows with missing `age` are excluded here.

- [`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md)
  treats `NA` as not matching: the row is **kept**. Write
  `exclude(~ withdrew)` and rows with missing `withdrew` stay in.

To make the intent explicit, handle `NA` in the predicate itself, e.g.
`include(~ !is.na(age) & age >= 18)` or
`exclude(~ is.na(withdrew) | withdrew)`. Grouped steps
([`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md),
[`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md),
[`select_within()`](https://mattmoo.github.io/cohortflow/reference/select_within.md))
always remove rows whose `by` value is `NA`. To see the raw predicate
values, `NA` included, use
[`criteria_status()`](https://mattmoo.github.io/cohortflow/reference/criteria_status.md)
with `mode = "independent"`.

## Labels

A step has up to two pieces of text, and diagrams put each next to the
count it describes:

- `label` names the step. For `include()`,
  [`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md)
  and
  [`select_within()`](https://mattmoo.github.io/cohortflow/reference/select_within.md)
  it describes the rows **kept** ("Aged 18 or over"), and an
  uncategorised step's main box in
  [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md)
  shows it with the number remaining. For
  [`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md)
  and
  [`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md)
  it describes the rows **removed** ("Withdrew consent"), so the diagram
  shows it in the exclusion box with the number removed, and the main
  box below reads "Remaining (n = ...)".

- `reason` describes the rows **removed**, for exclusion boxes.
  Exclusion steps default to their label. For inclusion steps the label
  would read backwards in an exclusion box ("Aged 18 or over (n=6)" for
  six people *under* 18), so give a `reason` ("Under 18"). Without one,
  an uncategorised inclusion step's exclusion box just says "Excluded",
  and one listed under a category falls back to its label with a
  warning.

Attrition tables list every step by `label`, beside a "Removed" column.

## See also

Other criteria builders:
[`cf_criteria()`](https://mattmoo.github.io/cohortflow/reference/cf_criteria.md),
[`cf_criterion()`](https://mattmoo.github.io/cohortflow/reference/cf_criterion.md),
[`check_criteria()`](https://mattmoo.github.io/cohortflow/reference/check_criteria.md),
[`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md),
[`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md),
[`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md),
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md),
[`select_within()`](https://mattmoo.github.io/cohortflow/reference/select_within.md)

## Examples

``` r
cf_criteria() |>
  include(~ age >= 18, label = "Adults", category = "Valid age",
          reason = "Under 18")
#> Cohort criteria pipeline  (1 step)
#>    1. [+][~] (include) {Valid age} Adults
#>           age >= 18
#>           removes: Under 18
```
