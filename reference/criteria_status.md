# Per-criterion status of every row

Returns one row per row of the starting data and one logical column per
criterion, recording whether the row passed (`TRUE`), failed (`FALSE`),
or has no result (`NA`) for that criterion. Use it to audit who failed
what, or to plot overlapping exclusion reasons, which the step-by-step
cascade hides. To get the cohort itself, use
[`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md).

## Usage

``` r
criteria_status(
  flow,
  mode = c("cumulative", "independent"),
  sets = c("pass", "fail"),
  na = c("keep", "false", "drop"),
  names = c("label", "step"),
  drop_randomise = TRUE,
  keep_data = FALSE,
  as = c("tibble", "data.table", "matrix")
)
```

## Arguments

- flow:

  A `cf_flow` object produced by
  [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md).

- mode:

  `"cumulative"` (default) or `"independent"`; see the section "Modes".

- sets:

  `"pass"` (default) reports whether each row passed each criterion;
  `"fail"` negates every criterion column (`NA` stays `NA`), so `TRUE`
  marks the reasons a row fails.

- na:

  What to do with `NA` in the criterion columns, applied after `sets`:
  `"keep"` (default) leaves them; `"false"` replaces them with `FALSE`;
  `"drop"` removes rows with any `NA`.

- names:

  Criterion column names: `"label"` (default) uses step labels, made
  unique with a warning if repeated; `"step"` uses `cf_step_<n>`. A name
  that clashes with an id or data column is made unique with a warning.

- drop_randomise:

  Logical. Omit
  [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
  steps (default `TRUE`).

- keep_data:

  Logical. Include the original data columns between the id column(s)
  and the criterion columns (default `FALSE`).

- as:

  Return type: `"tibble"` (default), `"data.table"` (requires the
  data.table package), or `"matrix"`, a logical matrix of the criterion
  columns only, with the row identifier as row names (`keep_data` is
  ignored).

## Value

For `"tibble"` and `"data.table"`: the id column(s) given as `id` to
[`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md)
(or `.cf_row_id` if none was given), then the data columns if
`keep_data = TRUE`, then one logical column per criterion in step order.
Rows are in the original data order. For `"matrix"`: a logical matrix.

## Modes

|  |  |  |
|----|----|----|
| Value | `mode = "cumulative"` | `mode = "independent"` |
| `TRUE` | Reached the step and passed it | The criterion holds for the row |
| `FALSE` | Removed at this step | The criterion fails for the row |
| `NA` | **Not assessed**: removed at an earlier step | The predicate gave `NA`, or a grouped step's `by` is `NA` |

**Cumulative** mirrors the cascade used by
[`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md),
[`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md)
and the CONSORT diagram, and is built from the recorded steps without
re-evaluating anything. Each row has at most one `FALSE`. `NA` means the
row never reached that criterion, which is not the same as failing it;
it only becomes `FALSE` if you ask for that with `na = "false"`. Missing
predicate values follow the cascade: an
[`include()`](https://mattmoo.github.io/cohortflow/reference/include.md)
that evaluates to `NA` removes the row (`FALSE`), an
[`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md)
that evaluates to `NA` keeps it (`TRUE`).

**Independent** evaluates every criterion against the full starting
data, ignoring earlier steps, so a row can fail several criteria. Bear
in mind:

- [`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md),
  [`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md)
  and
  [`select_within()`](https://mattmoo.github.io/cohortflow/reference/select_within.md)
  depend on which rows are in each group. Evaluated on the full data, a
  group can pass or fail differently than it did in the cascade, where
  earlier steps had already removed some of its rows.

- In a
  [`continue_criteria()`](https://mattmoo.github.io/cohortflow/reference/continue_criteria.md)
  flow, columns joined at a later stage are `NA` for rows excluded
  before the join, so later-stage predicates are usually `NA` for those
  rows.

- [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
  steps are all `TRUE` (in cumulative mode they are `TRUE` where reached
  and `NA` otherwise). They are dropped by default.

## Set plots

Set and overlap plots (e.g. the eulerr, UpSetR or ComplexUpset packages)
take a membership matrix with no missing values. The usual question is
how exclusion *reasons* overlap, so ask for failures and decide what
`NA` means:

    m <- criteria_status(flow, mode = "independent", sets = "fail",
                         na = "false", as = "matrix")
    # eulerr::euler(m); UpSetR::upset(as.data.frame(m * 1))

## See also

[`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md)
for the cohort itself,
[`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md)
for removed rows.

Other flow accessors:
[`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md),
[`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md),
[`stack_cohorts()`](https://mattmoo.github.io/cohortflow/reference/stack_cohorts.md)

## Examples

``` r
dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
crit <- cf_criteria() |>
  include(~ age >= 18, label = "Adults only") |>
  include(~ eligible_screen, label = "Passed screening") |>
  exclude(~ withdrew, label = "Withdrew consent")
flow <- apply_criteria(dat, crit, id = "participant_id")

criteria_status(flow)
#> # A tibble: 200 × 4
#>    participant_id `Adults only` `Passed screening` `Withdrew consent`
#>    <chr>          <lgl>         <lgl>              <lgl>             
#>  1 P0001          TRUE          FALSE              NA                
#>  2 P0002          TRUE          TRUE               TRUE              
#>  3 P0003          TRUE          TRUE               TRUE              
#>  4 P0004          TRUE          TRUE               TRUE              
#>  5 P0005          TRUE          TRUE               TRUE              
#>  6 P0006          TRUE          TRUE               TRUE              
#>  7 P0007          TRUE          TRUE               TRUE              
#>  8 P0008          TRUE          TRUE               TRUE              
#>  9 P0009          TRUE          FALSE              NA                
#> 10 P0010          TRUE          TRUE               TRUE              
#> # ℹ 190 more rows

# How often each exclusion reason applies, counting overlaps
m <- criteria_status(flow, mode = "independent", sets = "fail",
                     na = "false", as = "matrix")
colSums(m)
#>      Adults only Passed screening Withdrew consent 
#>                6               17                7 
```
