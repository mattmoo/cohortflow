# Continue a criteria pipeline on top of an existing flow

Applies additional criteria steps to the surviving cohort of an existing
`cf_flow`, optionally joining on new columns first. This lets an
attrition pipeline be built up in stages – e.g. apply screening
criteria, then join newly collected follow-up data and continue with
further criteria – while keeping a single, continuous step numbering and
denominators that correctly reflect the cohort at each stage (rather
than restarting counts from the original data).

## Usage

``` r
continue_criteria(flow, criteria, join = NULL, by = NULL)
```

## Arguments

- flow:

  A `cf_flow` object produced by
  [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md)
  (or a previous call to `continue_criteria()`).

- criteria:

  A `cf_criteria` object with the additional steps to apply. If empty
  (`length(criteria) == 0`), `flow` is returned unchanged.

- join:

  Optional data frame of new columns to attach before evaluating
  `criteria`, e.g. follow-up data collected after the initial screening.
  Joined onto **all** of `flow`'s original rows (via a left join), so
  rows already excluded at an earlier stage also gain the new columns
  (as `NA` where `join` has no match) – this keeps the full row history
  intact. Requires `by`.

- by:

  Column name(s) shared by `flow`'s data and `join`, used to join them.
  Required, and only used, when `join` is supplied.

## Value

A `cf_flow` object whose `criteria` and `steps` are the concatenation of
`flow`'s existing pipeline and `criteria`, with step numbers continuing
on from `flow`.

## Details

Before any new step is evaluated,
[`check_criteria()`](https://mattmoo.github.io/cohortflow/reference/check_criteria.md)
verifies that every step refers only to columns present in `flow`'s data
plus `join`, so a forgotten join fails up front naming the step and the
missing column(s).

## See also

Other pipeline:
[`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md),
[`cf_expected()`](https://mattmoo.github.io/cohortflow/reference/cf_expected.md),
[`cf_hierarchy()`](https://mattmoo.github.io/cohortflow/reference/cf_hierarchy.md)

## Examples

``` r
dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
crit <- cf_criteria() |>
  include(~ eligible_screen, label = "Passed screening")
flow <- apply_criteria(dat, crit)
#> No `id` supplied and no `.cf_row_id` column found. Adding a sequential `.cf_row_id`.

more_crit <- cf_criteria() |>
  include(~ !is.na(consent_date), label = "Consent recorded")
flow2 <- continue_criteria(flow, more_crit)
flow2
#> Cohort flow  (2 steps | 200 -> 157 rows | 43 excluded)
#> ------------------------------------------------------------
#>    1. [+] Passed screening
#>        n_in: 200  kept: 183  removed: 17
#>    2. [+] Consent recorded
#>        n_in: 183  kept: 157  removed: 26
```
