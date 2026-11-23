# Attrition tables

``` r

library(cohortflow)

dat <- mock_parallel_rct(n_participants = 300, seed = 2024)
crit <- cf_criteria() |>
  include(~ !is.na(age), label = "Age recorded", reason = "Age missing", category = "Age") |>
  include(~ age >= 18, label = "Aged 18 or over", reason = "Under 18", category = "Age") |>
  include(~ eligible_screen, label = "Passed screening", reason = "Failed screening") |>
  include(~ !is.na(consent_date), label = "Consented", reason = "Did not consent") |>
  randomise(by = "participant_id", arms = "arm") |>
  exclude(~ withdrew, label = "Withdrew consent") |>
  include(~ baseline_complete, label = "Baseline complete", reason = "Baseline incomplete")
flow <- apply_criteria(dat, crit, id = "participant_id")
```

An attrition table lists every criterion with the number entering it,
the number it removed and the percentage removed. cohortflow builds it
in two layers:

- [`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
  returns the numbers as a plain tibble.
- [`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md)
  formats that tibble for a report, using flextable, gt or huxtable.

The CONSORT diagram is drawn from the same tibble, so the table and the
diagram always agree.

## The data layer

``` r

tbl <- as_attrition_tibble(flow)
tbl
#> # A tibble: 10 × 9
#>    row_type label    indent_level     n n_removed pct_removed post_randomisation
#>    <chr>    <chr>           <int> <int>     <int>       <dbl> <lgl>             
#>  1 header   Assesse…            0   300        NA        NA   FALSE             
#>  2 category Age                 1   300        21         7   FALSE             
#>  3 step     Age rec…            2   300        15         5   FALSE             
#>  4 step     Aged 18…            2   285         6         2   FALSE             
#>  5 step     Passed …            1   279        26         9.3 FALSE             
#>  6 step     Consent…            1   253        27        10.7 FALSE             
#>  7 step     Randomi…            1   226         0         0   TRUE              
#>  8 step     Withdre…            1   226         8         3.5 TRUE              
#>  9 step     Baselin…            1   218        23        10.6 TRUE              
#> 10 final    Final c…            0   195        NA        65   TRUE              
#> # ℹ 2 more variables: Control <int>, Intervention <int>
```

| Column | Meaning |
|----|----|
| `row_type` | `"header"` (the starting count), `"category"`, `"step"` or `"final"` |
| `label` | The step or category label |
| `indent_level` | `0` for header and final rows, `1` for categories and top-level steps, `2` for steps inside a category |
| `n` | Number entering the step; for the final row, the number remaining |
| `n_removed` | Number the step removed |
| `pct_removed` | `n_removed` as a percentage of `n`; for the final row, the percentage of the starting count that remains |
| `post_randomisation` | Only when there is a [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md) step: `TRUE` from that step on |
| one column per arm | Only when there are arms: the final count in each arm |

Within a category, each step’s percentage uses the category’s entering
count as its denominator, so the step rows add up to the category row.

Because it is ordinary data, you can compute with it or build your own
layout:

``` r

# Steps after randomisation that removed anyone
subset(tbl, row_type == "step" & post_randomisation & n_removed > 0,
       select = c(label, n, n_removed, pct_removed))
#> # A tibble: 2 × 4
#>   label                 n n_removed pct_removed
#>   <chr>             <int>     <int>       <dbl>
#> 1 Withdrew consent    226         8         3.5
#> 2 Baseline complete   218        23        10.6
```

## Formatted tables

The three backends produce the same APA-style layout: no vertical rules,
categories in bold with their steps indented beneath them.

### Choosing a backend

- flextable
- gt
- huxtable

flextable is the default and the best choice when the report is a Word
document.

``` r

as_attrition_table(flow)
```

| Criterion                | N   | Removed | % removed      | Control | Intervention |
|--------------------------|-----|---------|----------------|---------|--------------|
| Assessed for eligibility | 300 |         |                |         |              |
| Age                      | 300 | 21      | 7.0%           |         |              |
| Age recorded             | 300 | 15      | 5.0%           |         |              |
| Aged 18 or over          | 285 | 6       | 2.0%           |         |              |
| Passed screening         | 279 | 26      | 9.3%           |         |              |
| Consented                | 253 | 27      | 10.7%          |         |              |
| Randomised               | 226 | —       | —              |         |              |
| Withdrew consent         | 226 | 8       | 3.5%           |         |              |
| Baseline complete        | 218 | 23      | 10.6%          |         |              |
| Final cohort             | 195 |         | 65.0% included | 107     | 88           |

gt suits HTML and LaTeX output.

``` r

as_attrition_table(flow, backend = "gt")
```

[TABLE]

huxtable writes to HTML, LaTeX, Word and Excel.

``` r

as_attrition_table(flow, backend = "huxtable")
```

| Criterion                |   N | Removed |      % removed | Control | Intervention |
|--------------------------|----:|--------:|---------------:|--------:|-------------:|
| Assessed for eligibility | 300 |         |                |         |              |
| Age                      | 300 |      21 |           7.0% |         |              |
| Age recorded             | 300 |      15 |           5.0% |         |              |
| Aged 18 or over          | 285 |       6 |           2.0% |         |              |
| Passed screening         | 279 |      26 |           9.3% |         |              |
| Consented                | 253 |      27 |          10.7% |         |              |
| Randomised               | 226 |       — |              — |         |              |
| Withdrew consent         | 226 |       8 |           3.5% |         |              |
| Baseline complete        | 218 |      23 |          10.6% |         |              |
| Final cohort             | 195 |         | 65.0% included |     107 |           88 |

### Saving to a file

Each backend’s own tools then take over. For example, to write a Word
file:

``` r

ft <- as_attrition_table(flow)
flextable::save_as_docx(ft, path = "attrition.docx")

gt::gtsave(as_attrition_table(flow, backend = "gt"), "attrition.html")
```

## Changing the wording

Every piece of text has an argument. `show_categories = FALSE` lists
every step on its own row:

``` r

as_attrition_table(
  flow,
  backend = "gt",
  show_categories = FALSE,
  assessed_label = "Screened",
  final_label = "Analysed",
  criterion_col_label = "Stage",
  removed_col_label = "Excluded",
  pct_col_label = "%",
  digits = 0
)
```

[TABLE]

## Counts by arm

When the pipeline contains
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md),
the final row is broken down by arm automatically (see the Control and
Intervention columns above). Without a
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
step, name the column with `branch_by`.

For designs with several rows per person, count people rather than rows
with `count_by`. In this crossover trial each participant has one row
per period. `count_by` names a level of the flow’s hierarchy (or that
level’s column), so the flow is built with a one-level
[`cf_hierarchy()`](https://mattmoo.github.io/cohortflow/reference/cf_hierarchy.md):

``` r

co <- mock_crossover(n_participants = 120, seed = 11)
flow_co <- apply_criteria(
  co,
  cf_criteria() |>
    include(~ eligible_screen, label = "Passed screening", reason = "Failed screening") |>
    include(~ !is.na(consent_date), label = "Consented", reason = "Did not consent") |>
    exclude(~ withdrew, label = "Withdrew"),
  id = "event_id",
  hierarchy = cf_hierarchy(participant = "participant_id")
)

as_attrition_tibble(flow_co, branch_by = "sequence", count_by = "participant_id")
#> # A tibble: 5 × 8
#>   row_type label            indent_level     n n_removed pct_removed    AB    BA
#>   <chr>    <chr>                   <int> <int>     <int>       <dbl> <int> <int>
#> 1 header   Assessed for el…            0   120        NA        NA      NA    NA
#> 2 step     Passed screening            1   120        12        10      NA    NA
#> 3 step     Consented                   1   108        23        21.3    NA    NA
#> 4 step     Withdrew                    1    85         3         3.5    NA    NA
#> 5 final    Final cohort                0    82        NA        68.3    38    44
```

Every count is now of people: `n`, `n_removed`, the percentages and the
arm columns. A person counts as removed at the step where they lose
their last row. To report several levels side by side (for example
clusters and participants), use [hierarchy
levels](https://mattmoo.github.io/cohortflow/articles/hierarchical-designs.md)
instead.

## Grids by site and period

`group_x` and `group_y` repeat the whole table for each value of a
column: `group_x` values become column blocks and `group_y` values
become row blocks. The pipeline is re-run within each group, so every
block has its own denominators. This is the usual layout for a
stepped-wedge trial:

``` r

sw <- mock_stepped_wedge(n_clusters = 8, n_participants = 400,
                         n_periods = 4, n_sites = 2, seed = 3)
flow_sw <- apply_criteria(
  sw,
  cf_criteria() |>
    include(~ !is.na(consent_date), label = "Consented", reason = "Did not consent") |>
    exclude(~ withdrew, label = "Withdrew"),
  id = "event_id"
)

as_attrition_table(
  flow_sw,
  backend = "gt",
  group_x = "site_id", group_x_label = "Site",
  group_y = "period", group_y_label = "Period"
)
```

[TABLE]

Rows whose grouping value is `NA` are not dropped: they form their own
group, labelled by `group_na_label` (default `"Missing"`), so the blocks
always add up to the whole dataset. The long form, with `group_x` and
`group_y` columns, comes from
[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
with the same arguments.

## Shading

`shade` colours the count cells by `"pct_removed"` or `"n_removed"`,
which makes the steps that lose the most people stand out:

``` r

as_attrition_table(flow, backend = "gt", shade = "pct_removed",
                   shade_palette = c("#FFFFFF", "#E07B39"))
```

[TABLE]

For a rule of your own, `shade_fn` takes the attrition tibble and
returns one colour (or `NA`) per row. Here, any exclusion after
randomisation is highlighted:

``` r

flag_post_randomisation <- function(tbl) {
  hit <- tbl$row_type == "step" & tbl$post_randomisation & tbl$n_removed > 0
  ifelse(hit, "#FDE2C8", NA_character_)
}

as_attrition_table(flow, backend = "gt", shade_fn = flag_post_randomisation)
```

[TABLE]

## Hierarchy levels

For clustered data, `levels` repeats the N / Removed / % columns once
per level of a
[`cf_hierarchy()`](https://mattmoo.github.io/cohortflow/reference/cf_hierarchy.md),
so each criterion reports clusters and participants side by side. See
[Hierarchical and cluster
designs](https://mattmoo.github.io/cohortflow/articles/hierarchical-designs.md).
