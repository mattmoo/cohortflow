# Get started with cohortflow

Most cohort studies and trials report how a starting population was
whittled down to the analysed cohort: who was assessed, who was excluded
and why, and how many were left at each stage. That record usually ends
up scattered across [`filter()`](https://rdrr.io/r/stats/filter.html)
calls, hand-counted tables and a flow diagram drawn in PowerPoint, and
the three drift apart as the analysis changes.

cohortflow keeps a single record. You write the eligibility criteria
once as a pipeline, apply it to your data, and derive the final cohort,
the excluded rows, the attrition table and the CONSORT diagram from the
same object, so they always agree.

``` r

library(cohortflow)
```

## Example data

The package ships with generators for four common trial designs. Here we
use a two-arm parallel-group randomised trial with 300 people assessed
for eligibility. Like real data, it is untidy: some ages are missing,
some people failed screening or never consented, and some withdrew.

``` r

dat <- mock_parallel_rct(n_participants = 300, seed = 2024)
dat
#> # A tibble: 300 × 10
#>    participant_id arm            age age_group sex   ethnicity eligible_screen
#>    <chr>          <chr>        <dbl> <chr>     <chr> <chr>     <lgl>          
#>  1 P0001          Intervention    28 18-39     M     European  TRUE           
#>  2 P0002          Control         44 40-64     F     Pacific   TRUE           
#>  3 P0003          Control         81 65+       M     European  TRUE           
#>  4 P0004          Intervention    64 40-64     M     European  TRUE           
#>  5 P0005          Control         NA NA        M     Pacific   TRUE           
#>  6 P0006          Control          5 <18       F     Maori     TRUE           
#>  7 P0007          Control         50 40-64     M     European  FALSE          
#>  8 P0008          Intervention    40 40-64     F     European  TRUE           
#>  9 P0009          Control         34 18-39     M     Pacific   TRUE           
#> 10 P0010          Intervention    49 40-64     M     European  TRUE           
#> # ℹ 290 more rows
#> # ℹ 3 more variables: consent_date <date>, baseline_complete <lgl>,
#> #   withdrew <lgl>
```

## 1. Define the criteria

A pipeline starts with
[`cf_criteria()`](https://mattmoo.github.io/cohortflow/reference/cf_criteria.md),
and each step is added with a pipe.
[`include()`](https://mattmoo.github.io/cohortflow/reference/include.md)
keeps the rows where its condition is `TRUE`;
[`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md)
drops the rows where its condition is `TRUE`. Each step has a `label`
for reporting, and steps can share a `category` so they are reported
together.

[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
removes nobody. It marks the point at which people were allocated, so
later reports can show what happened in each arm afterwards.

``` r

crit <- cf_criteria() |>
  include(~ !is.na(age), label = "Age recorded", reason = "Age missing", category = "Age") |>
  include(~ age >= 18, label = "Aged 18 or over", reason = "Under 18", category = "Age") |>
  include(~ eligible_screen, label = "Passed screening", reason = "Failed screening") |>
  include(~ !is.na(consent_date), label = "Consented", reason = "Did not consent") |>
  randomise(by = "participant_id", arms = "arm") |>
  exclude(~ withdrew, label = "Withdrew consent") |>
  include(~ baseline_complete, label = "Baseline complete", reason = "Baseline incomplete")

crit
#> Cohort criteria pipeline  (7 steps)
#>    1. [+][~] (include) {Age} Age recorded
#>           !is.na(age)
#>           removes: Age missing
#>    2. [+][~] (include) {Age} Aged 18 or over
#>           age >= 18
#>           removes: Under 18
#>    3. [+][~] (include) Passed screening
#>           eligible_screen
#>           removes: Failed screening
#>    4. [+][~] (include) Consented
#>           !is.na(consent_date)
#>           removes: Did not consent
#>    5. [R][-] (randomise) [by: participant_id] [arms: arm] Randomised
#>           <none>
#>    6. [-][~] (exclude) Withdrew consent
#>           withdrew
#>    7. [+][~] (include) Baseline complete
#>           baseline_complete
#>           removes: Baseline incomplete
```

In the printout, `[+]` marks an inclusion step, `[-]` an exclusion and
`[R]` the randomisation point. `[~]` means the condition is a formula.
The [Writing
criteria](https://mattmoo.github.io/cohortflow/articles/writing-criteria.md)
article covers every step type.

## 2. Apply them

[`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md)
runs the steps in order. Each step sees only the rows that survived the
steps before it. `id` names the column that identifies a row.

``` r

flow <- apply_criteria(dat, crit, id = "participant_id")
flow
#> Cohort flow  (7 steps | 300 -> 195 rows | 105 excluded)
#> ------------------------------------------------------------
#>    1. [+] Age recorded {Age}
#>        n_in: 300  kept: 285  removed: 15
#>    2. [+] Aged 18 or over {Age}
#>        n_in: 285  kept: 279  removed: 6
#>    3. [+] Passed screening
#>        n_in: 279  kept: 253  removed: 26
#>    4. [+] Consented
#>        n_in: 253  kept: 226  removed: 27
#>    5. [R] Randomised by participant_id arms arm
#>        n_in: 226  kept: 226  removed: 0
#>    6. [-] Withdrew consent
#>        n_in: 226  kept: 218  removed: 8
#>    7. [+] Baseline complete
#>        n_in: 218  kept: 195  removed: 23
```

The result is a `cf_flow`: the original data plus a record of which rows
each step removed. Everything below is read from it.

## 3. Get the cohort

[`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md)
returns the rows that passed every step, and
[`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md)
returns the rows that were removed, labelled with the step that removed
them:

``` r

final <- cohort(flow)
nrow(final)
#> [1] 195

removed <- excluded(flow)
table(removed$cf_label)
#> 
#>      Age recorded   Aged 18 or over Baseline complete         Consented 
#>                15                 6                23                27 
#>  Passed screening  Withdrew consent 
#>                26                 8
```

Both take a step selector (a step number, a label or a category), so you
can also get the cohort as it stood at an earlier point. For example,
here is everyone who was randomised:

``` r

nrow(cohort(flow, at = "Consented"))
#> [1] 226
```

## 4. Attrition table

[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
returns the counts as a plain data frame, ready for your own formatting
or further calculation:

``` r

as_attrition_tibble(flow)
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

[`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md)
formats the same data with flextable (the default, best for Word), gt or
huxtable. Steps that share a category are grouped under one heading, and
because there is a
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
step, the final row is broken out by arm.

``` r

as_attrition_table(flow, backend = "gt")
```

[TABLE]

The [Attrition
tables](https://mattmoo.github.io/cohortflow/articles/attrition-tables.html)
article covers grouped tables, shading and the other backends.

## 5. CONSORT flow diagram

[`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md)
draws the flow. Up to the randomisation box there is one shared trunk.
After it, each arm gets its own column, so post-allocation losses are
reported separately for each arm, as CONSORT asks.

``` r

diagram <- as_consort_diagram(flow)
diagram
```

![CONSORT flow diagram. 300 people were assessed; 105 were excluded at
six steps; after randomisation the Control and Intervention arms finish
with 107 and 88.](cohortflow_files/figure-html/unnamed-chunk-9-1.png)

Each main box shows how many people remain after a step, and each side
box how many that step removed, each beside text that describes those
people. An inclusion step’s label (“Passed screening”) goes on the main
box and its `reason` (“Failed screening”) on the side box. An exclusion
step’s label (“Withdrew consent”) goes on the side box, and the main box
below it reads “Remaining”. A category’s side box lists the reason for
each of its steps (here, *Age*).

The diagram is a ggplot. Save it for a manuscript with
[`save_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/save_consort_diagram.md),
which picks the format from the file extension and sizes the page so the
text fits its boxes:

``` r

save_consort_diagram(diagram, "consort.pdf")
save_consort_diagram(diagram, "consort.png", dpi = 300)
```

The [CONSORT
diagrams](https://mattmoo.github.io/cohortflow/articles/consort-diagrams.html)
article covers styling and other trial designs.

## 6. Who was excluded?

Reviewers often ask whether exclusions changed the make-up of the
cohort.
[`as_characteristics_table()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_table.md)
summarises chosen variables at every step, in one column per step:

``` r

as_characteristics_table(
  flow,
  vars = c("age", "sex"),
  steps = list(0, "Consented", "Baseline complete"),
  var_labels = c(age = "Age, years", sex = "Sex"),
  backend = "gt"
)
```

| Characteristic | Assessed for eligibility (n = 300) | Consented (n = 226) | Baseline complete (n = 195) |
|----|----|----|----|
| Age, years |  |  |  |
| Mean (SD) | 46.8 (14.5) | 47.7 (13.7) | 47.4 (13.2) |
| Missing | 15 (5.0%) | 0 (0.0%) | 0 (0.0%) |
| Sex |  |  |  |
| F | 146 (48.7%) | 114 (50.4%) | 103 (52.8%) |
| M | 144 (48.0%) | 106 (46.9%) | 86 (44.1%) |
| O | 10 (3.3%) | 6 (2.7%) | 6 (3.1%) |

Use `excluded = TRUE` to describe the people removed at each step
instead. The [Describing who was
excluded](https://mattmoo.github.io/cohortflow/articles/describing-exclusions.html)
article covers this and overlapping exclusion reasons.

> **Missing values.** A condition that gives `NA` is treated differently
> by the two step types. `include(~ age >= 18)` *removes* a row with a
> missing age; `exclude(~ age < 18)` *keeps* it. Here 15 people have no
> recorded age, so the choice changes the denominator. This pipeline
> makes the choice visible with a separate “Age recorded” step. See
> [Missing
> values](https://mattmoo.github.io/cohortflow/articles/writing-criteria.html#missing-values)
> for a worked example.

## 7. Writing it up

The methods section usually describes the same flow in words.
[`as_narrative()`](https://mattmoo.github.io/cohortflow/reference/as_narrative.md)
writes that paragraph from the flow, so its numbers match the table and
the diagram. Each step is described by its `reason`, and after
randomisation each sentence gives the counts for each arm:

``` r

as_narrative(flow)
```

Of 300 participants assessed for eligibility, 21 (7.0%) were excluded:
age missing (n = 15) and under 18 (n = 6). A further 26 (9.3%) were
excluded (failed screening). A further 27 (10.7%) were excluded (did not
consent), leaving 226. The remaining 226 were randomised to Control (n =
121) and Intervention (n = 105). After randomisation, 3 (2.5%) in
Control and 5 (4.8%) in Intervention were excluded (withdrew consent). A
further 11 (9.3%) in Control and 12 (12.0%) in Intervention were
excluded (baseline incomplete). The final cohort comprised 195
participants (65.0% of those assessed): 107 in Control and 88 in
Intervention.

Use `style = "bullets"` to get one sentence per line, which is easier to
edit into a draft. Set `unit` to the noun your study counts (for example
“patients”). Read the text through and adapt it to the journal’s style.

``` r

as_narrative(flow, style = "bullets", unit = "people")
```

- Of 300 people assessed for eligibility, 21 (7.0%) were excluded: age
  missing (n = 15) and under 18 (n = 6).
- A further 26 (9.3%) were excluded (failed screening).
- A further 27 (10.7%) were excluded (did not consent), leaving 226.
- The remaining 226 were randomised to Control (n = 121) and
  Intervention (n = 105).
- After randomisation, 3 (2.5%) in Control and 5 (4.8%) in Intervention
  were excluded (withdrew consent).
- A further 11 (9.3%) in Control and 12 (12.0%) in Intervention were
  excluded (baseline incomplete).
- The final cohort comprised 195 people (65.0% of those assessed): 107
  in Control and 88 in Intervention.

## 8. Save the criteria

A criteria pipeline can be written to YAML and read back, so the exact
definitions can be kept under version control, shared with collaborators
or attached to a protocol:

``` r

yml <- export_criteria(crit)
cat(yml)
#> cohortflow_criteria:
#>   version: 1
#>   steps:
#>   - label: Age recorded
#>     type: include
#>     kind: formula
#>     by: ~
#>     expr: '!is.na(age)'
#>     fn_ref: ~
#>     category: Age
#>     arms: ~
#>     reason: Age missing
#>   - label: Aged 18 or over
#>     type: include
#>     kind: formula
#>     by: ~
#>     expr: age >= 18
#>     fn_ref: ~
#>     category: Age
#>     arms: ~
#>     reason: Under 18
#>   - label: Passed screening
#>     type: include
#>     kind: formula
#>     by: ~
#>     expr: eligible_screen
#>     fn_ref: ~
#>     category: ~
#>     arms: ~
#>     reason: Failed screening
#>   - label: Consented
#>     type: include
#>     kind: formula
#>     by: ~
#>     expr: '!is.na(consent_date)'
#>     fn_ref: ~
#>     category: ~
#>     arms: ~
#>     reason: Did not consent
#>   - label: Randomised
#>     type: randomise
#>     kind: none
#>     by: participant_id
#>     expr: ~
#>     fn_ref: ~
#>     category: ~
#>     arms: arm
#>   - label: Withdrew consent
#>     type: exclude
#>     kind: formula
#>     by: ~
#>     expr: withdrew
#>     fn_ref: ~
#>     category: ~
#>     arms: ~
#>   - label: Baseline complete
#>     type: include
#>     kind: formula
#>     by: ~
#>     expr: baseline_complete
#>     fn_ref: ~
#>     category: ~
#>     arms: ~
#>     reason: Baseline incomplete

identical(
  as_attrition_tibble(apply_criteria(dat, import_criteria(text = yml), id = "participant_id")),
  as_attrition_tibble(flow)
)
#> [1] TRUE
```

Pass `path =` to
[`export_criteria()`](https://mattmoo.github.io/cohortflow/reference/export_criteria.md)
and
[`import_criteria()`](https://mattmoo.github.io/cohortflow/reference/import_criteria.md)
to write and read a file instead.

## Next steps

- [Writing
  criteria](https://mattmoo.github.io/cohortflow/articles/writing-criteria.md):
  formula and function conditions, categories, grouped steps and missing
  values.
- [Hierarchical and cluster
  designs](https://mattmoo.github.io/cohortflow/articles/hierarchical-designs.md):
  counting clusters and participants side by side.
- [Study design
  gallery](https://mattmoo.github.io/cohortflow/articles/design-gallery.html):
  complete examples for parallel, crossover, cluster and stepped-wedge
  trials.
