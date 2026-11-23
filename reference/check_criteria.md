# Check that criteria only refer to columns present in the data

A pre-flight check run before any step is evaluated. For every step in
`criteria`, the variables used by a formula predicate, the `by`
column(s) and the `arms` column must exist in `data`. If any are
missing, `check_criteria()` aborts with one line per offending step,
naming the step number, its label and the missing column(s), instead of
letting evaluation fail later with `object 'x' not found`.

## Usage

``` r
check_criteria(criteria, data)
```

## Arguments

- criteria:

  A `cf_criteria` object.

- data:

  A data frame.

## Value

`NULL`, invisibly. Called for its side effect of aborting when a
criterion refers to a column not in `data`.

## Details

[`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md)
and
[`continue_criteria()`](https://mattmoo.github.io/cohortflow/reference/continue_criteria.md)
call this automatically (after the `expected` / `join` step, so joined
columns count as present). Call it directly to validate a criteria set
against a dataset without applying it.

## What is checked

Variables in a formula predicate count as present when they are a column
of `data`, or when they resolve in the formula's environment (e.g. a
local `min_age <- 18` used as `~ age >= min_age`), matching how
predicates are evaluated. A consequence is that a missing column whose
name matches an object on the search path (e.g. `c` or `t`) is not
reported, because evaluation would find that object too. The dplyr
helpers `n()`, `n_distinct()`, `cur_group()` and `cur_group_id()` and
the `.data` / `.env` pronouns are always allowed; `.data$x` is checked
as column `x`. Function names, `pkg::fn` references and the right-hand
side of `obj$field` are not treated as columns.

Function predicates cannot be inspected statically and are skipped
(their `by` / `arms` columns are still checked); the error message notes
which steps were skipped.

## See also

[`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md),
[`continue_criteria()`](https://mattmoo.github.io/cohortflow/reference/continue_criteria.md).

Other criteria builders:
[`cf_criteria()`](https://mattmoo.github.io/cohortflow/reference/cf_criteria.md),
[`cf_criterion()`](https://mattmoo.github.io/cohortflow/reference/cf_criterion.md),
[`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md),
[`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md),
[`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md),
[`include()`](https://mattmoo.github.io/cohortflow/reference/include.md),
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md),
[`select_within()`](https://mattmoo.github.io/cohortflow/reference/select_within.md)

## Examples

``` r
dat  <- mock_parallel_rct(n_participants = 50, seed = 1)
crit <- cf_criteria() |>
  include(~ age >= 18, label = "Adults only") |>
  include(~ !is.na(consent_date), label = "Consent recorded")
check_criteria(crit, dat)   # passes silently

# A column that is not in the data is reported with its step
bad <- crit |> exclude(~ lost_to_follow_up, label = "Lost to follow-up")
try(check_criteria(bad, dat))
#> Error in .check_criteria(criteria, data) : 
#>   Criteria refer to column(s) not found in `data`.
#> ✖ Criterion 3 "Lost to follow-up" refers to column(s) not in data: lost_to_follow_up.
```
