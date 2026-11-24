# Describe a cohort flow in words, for a methods section

Writes the attrition cascade as a short paragraph, ready to paste into
the participant-flow part of a methods or results section. The numbers
come from
[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
(and, after a
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
step, from the same per-arm re-application
[`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md)
uses), so the text always agrees with the table and the diagram.

## Usage

``` r
as_narrative(
  flow,
  assessed_label = "assessed for eligibility",
  unit = "participants",
  count_by = NULL,
  big_mark = ",",
  digits = 1L,
  show_categories = TRUE,
  drop_randomise = FALSE,
  lowercase_reasons = TRUE,
  style = c("prose", "bullets")
)

# S3 method for class 'cf_narrative'
print(x, ...)
```

## Arguments

- flow:

  A `cf_flow` object produced by
  [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md).

- assessed_label:

  Text after the starting count in the first sentence, as in "Of 200
  participants *assessed for eligibility*". Default
  `"assessed for eligibility"`.

- unit:

  Plural noun for what is counted, used verbatim (it is not pluralised
  or inflected). Default `"participants"`.

- count_by:

  Optional hierarchy level to count instead of rows, passed to
  [`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
  (see there). Set `unit` to match.

- big_mark:

  Thousands separator for counts (`"1,234"` with the default `","`);
  `""` turns grouping off.

- digits:

  Decimal places for percentages. Default `1`.

- show_categories:

  Logical. When `TRUE` (default) steps with the same `category` are
  collapsed under a single parent row. When `FALSE` one row per step is
  produced.

- drop_randomise:

  Logical. When `TRUE`, a
  [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
  step is ignored and everything is reported pooled, as if there were no
  arms. Default `FALSE`.

- lowercase_reasons:

  Logical. When `TRUE` (default), the first letter of each reason is
  lower-cased so it reads mid-sentence ("Age missing" becomes "age
  missing"), unless the first word looks like an acronym (its second
  letter is upper case, as in "BMI missing"). Quoted labels
  (`not meeting "<label>"`) are never changed.

- style:

  `"prose"` (default) for one paragraph, or `"bullets"` for one sentence
  per line, each starting `"- "` (Markdown list items).

- x:

  A `cf_narrative` object.

- ...:

  Ignored.

## Value

A single string with class `c("cf_narrative", "character")`. Printing
wraps it to the console width; in an R Markdown or Quarto chunk it is
inserted as text. Use
[`as.character()`](https://rdrr.io/r/base/character.html) for the bare
string.

## Wording

- One sentence per category (or per step with `show_categories = FALSE`,
  and for uncategorised steps). Category names group reasons into a
  sentence but are not themselves narrated. Steps and categories that
  removed nobody are left out.

- The first sentence opens "Of N \<assessed_label\>, ..."; later ones
  open "A further ...". Each gives the number removed and its percentage
  of those entering that category or step, then the reason(s): one
  reason in brackets, several as a list with their own counts. The last
  sentence before randomisation (or before the final sentence) ends ",
  leaving n".

- The removal text for each step is its `reason`. Exclusion steps
  default to their label; an inclusion step without a `reason` reads
  `not meeting "<label>"`.

- A
  [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
  step gives "The remaining n were randomised to A (n = a) and B (n =
  b)." Arms are in factor-level order (else sorted); a missing arm value
  forms an arm called "Missing", as in the diagram. After it, each
  sentence gives per-arm counts, with percentages of the number of that
  arm entering the step.

- The last sentence gives the final cohort and its percentage of those
  assessed, broken down by arm when there are arms.

- `count_by` changes what is counted but not the noun: set `unit` to
  match (e.g. `count_by = "participant_id", unit = "participants"` for a
  crossover trial with one row per participant-period).

- Grouped steps read like any other step; units removed only because
  their group was removed (`n_consequential`) are not narrated
  separately.

Lists use the serial (Oxford) comma: "a, b, and c". The text is a
starting point: read it, and edit it to suit the journal's style.

## See also

[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
and
[`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md),
which report the same numbers.

Other reporting:
[`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md),
[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md),
[`as_characteristics_table()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_table.md),
[`as_characteristics_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_tibble.md),
[`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md),
[`save_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/save_consort_diagram.md)

## Examples

``` r
dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
crit <- cf_criteria() |>
  include(~ !is.na(age), label = "Age recorded", reason = "Age missing", category = "Age") |>
  include(~ age >= 18, label = "Aged 18 or over", reason = "Under 18", category = "Age") |>
  include(~ !is.na(consent_date), label = "Consented", reason = "Did not consent") |>
  randomise(by = "participant_id", arms = "arm") |>
  exclude(~ withdrew, label = "Withdrew consent")
flow <- apply_criteria(dat, crit, id = "participant_id")
as_narrative(flow)
#> Of 200 participants assessed for eligibility, 16 (8.0%) were excluded: age
#> missing (n = 10) and under 18 (n = 6). A further 41 (22.3%) were excluded (did
#> not consent), leaving 143. The remaining 143 were randomised to Control (n =
#> 74) and Intervention (n = 69). After randomisation, 3 (4.1%) in Control and 4
#> (5.8%) in Intervention were excluded (withdrew consent). The final cohort
#> comprised 136 participants (68.0% of those assessed): 71 in Control and 65 in
#> Intervention.
as_narrative(flow, style = "bullets")
#> - Of 200 participants assessed for eligibility, 16 (8.0%) were excluded: age
#>   missing (n = 10) and under 18 (n = 6).
#> - A further 41 (22.3%) were excluded (did not consent), leaving 143.
#> - The remaining 143 were randomised to Control (n = 74) and Intervention (n =
#>   69).
#> - After randomisation, 3 (4.1%) in Control and 4 (5.8%) in Intervention were
#>   excluded (withdrew consent).
#> - The final cohort comprised 136 participants (68.0% of those assessed): 71 in
#>   Control and 65 in Intervention.
as_narrative(flow, drop_randomise = TRUE)
#> Of 200 participants assessed for eligibility, 16 (8.0%) were excluded: age
#> missing (n = 10) and under 18 (n = 6). A further 41 (22.3%) were excluded (did
#> not consent). A further 7 (4.9%) were excluded (withdrew consent), leaving 136.
#> The final cohort comprised 136 participants (68.0% of those assessed).
```
