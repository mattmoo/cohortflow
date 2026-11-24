# Changelog

## cohortflow 0.0.0.9017

### New features

- New
  [`as_narrative()`](https://mattmoo.github.io/cohortflow/reference/as_narrative.md)
  writes the attrition cascade as a paragraph for a methods section: “Of
  200 participants assessed for eligibility, 16 (8.0%) were excluded:
  age missing (n = 10) and under 18 (n = 6). …” The numbers come from
  [`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md),
  and after a
  [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
  step from the same per-arm counts as
  [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md),
  so the text agrees with the table and diagram. There is one sentence
  per category (or per step), each step described by its `reason` (an
  inclusion step without one reads `not meeting "<label>"`), per-arm
  sentences after randomisation, and a final-cohort sentence broken down
  by arm. `count_by` counts units as in the table; `unit` sets the noun;
  `style = "bullets"` gives one sentence per line. The result prints
  wrapped to the console and drops into R Markdown and Quarto documents
  as text.

## cohortflow 0.0.0.9016

### Breaking changes

- CONSORT diagrams put every number beside text that describes those
  people. An uncategorised
  [`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md)
  or
  [`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md)
  step’s label now appears in its exclusion box with the number removed
  (“Withdrew consent (n=4)”), and the main box below it reads “Remaining
  (n=118)”. Previously the main box showed “Withdrew consent (n=118)”,
  which read as 118 withdrawals. The new `remaining_label` argument
  changes that text.
  [`include()`](https://mattmoo.github.io/cohortflow/reference/include.md)-type
  steps keep their label on the main box.
- `count_by` now counts distinct units in every box and row, not only
  the arm boxes and columns. In
  [`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md),
  [`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md)
  and
  [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md),
  `n`, `n_removed` and the percentages all count units, so a crossover
  trial reports participants throughout instead of participant-periods
  in the trunk and participants in the arms. A unit counts as removed at
  the step where it loses its last row. `count_by` must name a level of
  the flow’s hierarchy (a level name, or the column of a single-column
  level), so the flow needs `apply_criteria(hierarchy = )`. Old calls
  without a hierarchy, or naming a column that is not a level, fail with
  an error (class `cohortflow_count_by_hierarchy`) that explains the
  change and shows the
  [`cf_hierarchy()`](https://mattmoo.github.io/cohortflow/reference/cf_hierarchy.md)
  call to add.

### New features

- [`include()`](https://mattmoo.github.io/cohortflow/reference/include.md),
  [`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md),
  [`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md),
  [`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md),
  [`select_within()`](https://mattmoo.github.io/cohortflow/reference/select_within.md)
  and
  [`cf_criterion()`](https://mattmoo.github.io/cohortflow/reference/cf_criterion.md)
  gain `reason`: a description of the rows the step removes (“Under 18”
  for `include(~ age >= 18, "Aged 18 or over")`). Diagram exclusion
  boxes use it. Exclusion steps default to their label. An inclusion
  step without one gets an exclusion box that says “Excluded”. If it is
  listed in a category’s exclusion box, its label is used and
  [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md)
  warns (class `cohortflow_missing_reason`, at most every 8 hours;
  `options(cohortflow.warn_missing_reason = FALSE)` turns it off).
  `reason` is printed with the pipeline and round-trips through
  [`export_criteria()`](https://mattmoo.github.io/cohortflow/reference/export_criteria.md)
  /
  [`import_criteria()`](https://mattmoo.github.io/cohortflow/reference/import_criteria.md);
  it is written only when set, so other files are unchanged. Flows built
  before `reason` existed still draw.
- `count_by` no longer requires `branch_by`, and works with a
  [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
  split (each arm’s cascade counts the same units as the trunk).

### Better messages for old usage

- A step selector such as `steps = c(0, "Consented")` turns `0` into the
  text `"0"`, which matches no step. The error now says so and suggests
  `list(0, "Consented")`. This applies wherever steps are selected
  ([`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md),
  [`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md),
  [`as_characteristics_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_tibble.md),
  [`stack_cohorts()`](https://mattmoo.github.io/cohortflow/reference/stack_cohorts.md)).
  A step labelled `"1"` still resolves by label.
- [`import_criteria()`](https://mattmoo.github.io/cohortflow/reference/import_criteria.md)
  warns (class `cohortflow_legacy_yaml`) when a file uses the
  pre-0.0.0.9011 `fn_args` format, naming the step, explaining that
  default argument values were not stored, and giving the call to
  re-save the file. A file with a schema `version` newer than 1 is
  refused with a message to update the package, instead of being
  misread.
- The
  [`mock_cohortflow()`](https://mattmoo.github.io/cohortflow/reference/mock_cohortflow.md)
  deprecation warning lists which generator suits which design, and has
  class `cohortflow_deprecated`.

## cohortflow 0.0.0.9015

### Documentation

- New package website at <https://mattmoo.github.io/cohortflow/>, with a
  reference index grouped by task and eight articles.
- Three vignettes: “Get started”, “Writing criteria” (including a worked
  example of how
  [`include()`](https://mattmoo.github.io/cohortflow/reference/include.md)
  and
  [`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md)
  treat missing values) and “Hierarchical and cluster designs”.
- Web-only articles: “Attrition tables”, “CONSORT diagrams”, “Staged
  pipelines and missing units”, “Describing who was excluded” and a
  “Study design gallery” covering parallel, crossover, cluster and
  stepped-wedge trials.
- Reference pages cross-link related functions, and
  [`export_criteria()`](https://mattmoo.github.io/cohortflow/reference/export_criteria.md),
  [`import_criteria()`](https://mattmoo.github.io/cohortflow/reference/import_criteria.md),
  [`plot.cf_flow()`](https://mattmoo.github.io/cohortflow/reference/plot.cf_flow.md)
  and
  [`print.consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/print.consort_diagram.md)
  gain examples.

### Bug fixes

- `as_consort_diagram(stage_by = )` no longer draws stage boxes on top
  of each other. Stages (e.g. crossover periods) now stack below their
  branch box with the same gap as the rest of the diagram, and a wrapped
  label pushes later stages down instead of overlapping them.
- The gt backend of
  [`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md)
  and
  [`as_characteristics_table()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_table.md)
  now leaves empty cells blank, as flextable and huxtable do. Previously
  it printed `NA` in the header row’s removed count and in every arm
  column above the final row.
- `as_attrition_table(levels = NULL)` now shows every hierarchy level,
  as documented and as `as_attrition_tibble(levels = NULL)` does.
  Previously it failed with an internal subsetting error.

## cohortflow 0.0.0.9014

### New features

- [`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md)
  gains `only = FALSE`. With `only = TRUE` it returns just the rows
  removed at the selected step, rather than every row removed up to and
  including it: `excluded(flow, at = 2, only = TRUE)`.

## cohortflow 0.0.0.9013

### New features

- [`save_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/save_consort_diagram.md)
  writes a CONSORT diagram (or a `cf_flow`, drawn with default settings)
  to PNG, TIFF, JPEG, PDF, SVG or EPS, choosing the format from the file
  extension. Defaults suit manuscript submission: 300 dpi, a white
  background, `ragg` devices for raster output when installed,
  [`cairo_pdf()`](https://rdrr.io/r/grDevices/cairo.html) for PDF
  (embeds fonts), and `svglite` for SVG when installed. When `width` and
  `height` are omitted the page size comes from the diagram layout, so
  box text fits its boxes and longer pipelines give taller files;
  supplying one dimension keeps the aspect ratio.

### Bug fixes

- [`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md)
  now shows every percentage to `digits` decimal places, keeping
  trailing zeros: a 10% removal reads `10.0%` rather than `10%`, and the
  final row `90.0% included`. This applies to plain, `group_x`/`group_y`
  and `levels =` tables, matching
  [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md).

## cohortflow 0.0.0.9012

### New features

- [`as_characteristics_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_tibble.md)
  and
  [`as_characteristics_table()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_table.md)
  build a step-wise baseline-characteristics (“Table 1”) table:
  variables as rows, one column per criteria step, each cell summarising
  the cohort surviving up to and including that step
  (`cohort(flow, step_number = k)`). Numeric variables show mean (SD)
  and/or median \[Q1, Q3\]; factor, character and logical variables show
  n (%); each variable gets a missing-values row. `steps =` takes the
  same selectors as
  [`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md)
  to restrict or reorder the columns, `excluded = TRUE` describes the
  rows removed *at* each step instead, and `level =` summarises one row
  per hierarchy unit. The table renders through the same flextable, gt
  and huxtable backends as
  [`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md).
- [`stack_cohorts()`](https://mattmoo.github.io/cohortflow/reference/stack_cohorts.md)
  returns the per-step cohorts stacked with a `step` factor, ready for
  `gtsummary::tbl_summary(by = step)`.

## cohortflow 0.0.0.9011

### Smoke-test fixes

- Error messages from
  [`cf_criterion()`](https://mattmoo.github.io/cohortflow/reference/cf_criterion.md)
  and the criterion evaluators no longer show raw markup such as
  `{.arg label}`; they now include the actual label, class, lengths and
  missing column names.
- Per-level hierarchy counts (`as_attrition_tibble(levels = )`,
  `as_attrition_table(levels = )`) no longer count an `NA` key as a
  unit. For example, an expected participant with no cluster counts as
  one participant and zero clusters, not as an extra “phantom” cluster.
- The `.data` and `.env` pronouns now work in
  [`include()`](https://mattmoo.github.io/cohortflow/reference/include.md),
  [`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md)
  and
  [`select_within()`](https://mattmoo.github.io/cohortflow/reference/select_within.md)
  formulas, as they already did in grouped steps and as
  [`check_criteria()`](https://mattmoo.github.io/cohortflow/reference/check_criteria.md)
  assumed.
- [`export_criteria()`](https://mattmoo.github.io/cohortflow/reference/export_criteria.md)
  no longer errors on a primitive-function predicate such as
  `include(is.na, ...)`. Such predicates now print as
  `.Primitive("is.na")` rather than `NULL`.
- [`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md),
  [`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md)
  and
  [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md)
  now give a clear error (“`branch_by` must be a single column name.”)
  when `branch_by`, `count_by`, `stage_by`, `stage_label_by`, `group_x`
  or `group_y` is not a single column name. Previously this failed with
  an R internals error.
- [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md)
  now draws a plain linear cascade when no rows reach the branch point
  (a zero-row flow, or every row excluded before
  [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)).
  Previously it warned, or with `branch_by` failed.
- A row-wise predicate in
  [`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md)
  /
  [`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md)
  (e.g. `~ age > 18`) now gives “Group criterion”” must return one value
  per group” with a hint, not dplyr’s raw size error. Other predicate
  errors are reported under the criterion’s label with the original
  error attached.

### Audit fixes

- `NA` values in `branch_by` / `stage_by` (including
  [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
  arms) now form their own branch, labelled by the new `branch_na_label`
  argument (default `"Missing"`) of
  [`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md),
  [`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md)
  and
  [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md).
  Previously they were counted in every branch.
- [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md)
  now aborts (instead of warning) when the row identifier (`id`, single
  or composite, or a pre-existing `.cf_row_id`) has duplicate or `NA`
  values, which silently corrupted
  [`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md)
  /
  [`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md).
- Group predicates must return a logical `.pass`, the `by` column(s),
  and exactly one row per group; anything else now aborts.
- Rows with an `NA` in any `by` column are removed by every grouped step
  type
  ([`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md)
  used to keep them).
- [`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md)
  gains `group_na_label`.
- Function predicates print their body rather than `x$predicate`.
- [`export_criteria()`](https://mattmoo.github.io/cohortflow/reference/export_criteria.md)
  stores the full function source, so default argument values survive a
  YAML round-trip; the `fn_args` field is dropped (old files still
  import). It now returns the YAML visibly when `path = NULL`.
  [`import_criteria()`](https://mattmoo.github.io/cohortflow/reference/import_criteria.md)
  documents that criteria files contain executable code.
- A warning is issued when a category’s steps are not consecutive.
- CONSORT boxes are spaced by their content, so long pipelines and tall
  exclusion boxes no longer overlap.
- Zero-row flows no longer show `NaN% included`.
- `branch_by` values that clash with standard column names (e.g. `"n"`)
  abort.
- The always-`NA` `branch` column is removed from
  [`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
  output.
- [`cf_criterion()`](https://mattmoo.github.io/cohortflow/reference/cf_criterion.md)
  aborts when `by` is given for `include` / `exclude`;
  [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md)
  aborts when `count_by` is given without `branch_by`.
- [`mock_cohortflow()`](https://mattmoo.github.io/cohortflow/reference/mock_cohortflow.md)
  warns once per session.

### New features

- [`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md)
  and
  [`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md)
  can stop at an intermediate step, returning the rows surviving (or
  removed) up to and including it. Select the step with `step_number`
  (`0` = starting data), `label`, or `category` (last step in that
  category); or use `at`, which auto-selects (number, else label, else
  category). At most one selector may be given. With
  `cohort(flag = TRUE)`, attribution only covers steps up to the chosen
  step.

- New
  [`criteria_status()`](https://mattmoo.github.io/cohortflow/reference/criteria_status.md)
  returns one row per data row and one logical column per criterion, for
  auditing who failed what and for set/overlap plots of exclusion
  reasons. `mode = "cumulative"` follows the cascade (`FALSE` at the
  removing step, `NA` = not assessed afterwards); `mode = "independent"`
  evaluates every criterion on the full data. Options cover failure sets
  (`sets = "fail"`), `NA` handling (`na = "keep"/"false"/"drop"`),
  column naming, `keep_data`, and output as a tibble, data.table or
  logical matrix. `data.table` is a new suggested package.

- New `check_criteria(criteria, data)` checks before evaluation that
  every formula predicate, `by` and `arms` refers only to columns in
  `data`, and aborts naming each offending step’s number, label and
  missing column(s).
  [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md)
  and
  [`continue_criteria()`](https://mattmoo.github.io/cohortflow/reference/continue_criteria.md)
  run it automatically, so a forgotten `join` in a staged pipeline now
  fails up front instead of with `object 'x' not found` inside
  evaluation. Names bound in the formula’s environment are allowed;
  function predicates are not checked.

- `cf_flow` objects record the `id` column(s) passed to
  [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md)
  (older flow objects still work).

- [`?include`](https://mattmoo.github.io/cohortflow/reference/include.md)
  /
  [`?exclude`](https://mattmoo.github.io/cohortflow/reference/exclude.md)
  document how a predicate that evaluates to `NA` is handled:
  [`include()`](https://mattmoo.github.io/cohortflow/reference/include.md)
  removes the row,
  [`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md)
  keeps it.

- [`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md)
  gained a `levels` argument, mirroring
  `as_attrition_tibble(levels = )`: it renders one row per criterion
  with a column block (N / Removed / % removed) per hierarchy level, so
  a single row reports its effect at both the unit of analysis and the
  unit of recruitment (e.g. participants and clusters) side by side.
  This is the reporting form required by the CONSORT cluster extension
  (Campbell, Elbourne & Altman, BMJ 2004;328:702-8) and the
  within-person extension. New `level_labels` argument supplies display
  names for the column blocks (level names are otherwise used as-is,
  unmangled). A `show_consequential` argument adds an optional fourth
  column per level for units lost only because a
  [`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md)/[`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md)
  group they belonged to was removed; by default it appears only when
  populated. `levels` cannot be combined with
  `group_x`/`group_y`/`branch_by`/`count_by`. Shading
  (`shade`/`shade_fn`) is computed per level.
