# cohortflow 0.0.0.9011

## Smoke-test fixes

* Error messages from `cf_criterion()` and the criterion evaluators no longer
  show raw markup such as `{.arg label}`; they now include the actual label,
  class, lengths and missing column names.
* Per-level hierarchy counts (`as_attrition_tibble(levels = )`,
  `as_attrition_table(levels = )`) no longer count an `NA` key as a unit.
  For example, an expected participant with no cluster counts as one
  participant and zero clusters, not as an extra "phantom" cluster.
* The `.data` and `.env` pronouns now work in `include()`, `exclude()` and
  `select_within()` formulas, as they already did in grouped steps and as
  `check_criteria()` assumed.
* `export_criteria()` no longer errors on a primitive-function predicate such
  as `include(is.na, ...)`. Such predicates now print as `.Primitive("is.na")`
  rather than `NULL`.
* `as_attrition_tibble()`, `as_attrition_table()` and `as_consort_diagram()`
  now give a clear error ("`branch_by` must be a single column name.") when
  `branch_by`, `count_by`, `stage_by`, `stage_label_by`, `group_x` or
  `group_y` is not a single column name. Previously this failed with an R
  internals error.
* `as_consort_diagram()` now draws a plain linear cascade when no rows reach
  the branch point (a zero-row flow, or every row excluded before
  `randomise()`). Previously it warned, or with `branch_by` failed.
* A row-wise predicate in `group_include()` / `group_exclude()` (e.g.
  `~ age > 18`) now gives "Group criterion "<label>" must return one value
  per group" with a hint, not dplyr's raw size error. Other predicate
  errors are reported under the criterion's label with the original error
  attached.

## Audit fixes

* `NA` values in `branch_by` / `stage_by` (including `randomise()` arms) now
  form their own branch, labelled by the new `branch_na_label` argument
  (default `"Missing"`) of `as_attrition_tibble()`, `as_attrition_table()`
  and `as_consort_diagram()`. Previously they were counted in every branch.
* `apply_criteria()` now aborts (instead of warning) when the row identifier
  (`id`, single or composite, or a pre-existing `.cf_row_id`) has duplicate
  or `NA` values, which silently corrupted `cohort()` / `excluded()`.
* Group predicates must return a logical `.pass`, the `by` column(s), and
  exactly one row per group; anything else now aborts.
* Rows with an `NA` in any `by` column are removed by every grouped step type
  (`group_exclude()` used to keep them).
* `as_attrition_table()` gains `group_na_label`.
* Function predicates print their body rather than `x$predicate`.
* `export_criteria()` stores the full function source, so default argument
  values survive a YAML round-trip; the `fn_args` field is dropped (old files
  still import). It now returns the YAML visibly when `path = NULL`.
  `import_criteria()` documents that criteria files contain executable code.
* A warning is issued when a category's steps are not consecutive.
* CONSORT boxes are spaced by their content, so long pipelines and tall
  exclusion boxes no longer overlap.
* Zero-row flows no longer show `NaN% included`.
* `branch_by` values that clash with standard column names (e.g. `"n"`)
  abort.
* The always-`NA` `branch` column is removed from `as_attrition_tibble()`
  output.
* `cf_criterion()` aborts when `by` is given for `include` / `exclude`;
  `as_consort_diagram()` aborts when `count_by` is given without
  `branch_by`.
* `mock_cohortflow()` warns once per session.

## New features

* `cohort()` and `excluded()` can stop at an intermediate step, returning the
  rows surviving (or removed) up to and including it. Select the step with
  `step_number` (`0` = starting data), `label`, or `category` (last step in
  that category); or use `at`, which auto-selects (number, else label, else
  category). At most one selector may be given. With `cohort(flag = TRUE)`,
  attribution only covers steps up to the chosen step.

* New `criteria_status()` returns one row per data row and one logical column
  per criterion, for auditing who failed what and for set/overlap plots of
  exclusion reasons. `mode = "cumulative"` follows the cascade (`FALSE` at the
  removing step, `NA` = not assessed afterwards); `mode = "independent"`
  evaluates every criterion on the full data. Options cover failure sets
  (`sets = "fail"`), `NA` handling (`na = "keep"/"false"/"drop"`), column
  naming, `keep_data`, and output as a tibble, data.table or logical matrix.
  `data.table` is a new suggested package.

* New `check_criteria(criteria, data)` checks before evaluation that every
  formula predicate, `by` and `arms` refers only to columns in `data`, and
  aborts naming each offending step's number, label and missing column(s).
  `apply_criteria()` and `continue_criteria()` run it automatically, so a
  forgotten `join` in a staged pipeline now fails up front instead of with
  `object 'x' not found` inside evaluation. Names bound in the formula's
  environment are allowed; function predicates are not checked.

* `cf_flow` objects record the `id` column(s) passed to `apply_criteria()`
  (older flow objects still work).

* `?include` / `?exclude` document how a predicate that evaluates to `NA` is
  handled: `include()` removes the row, `exclude()` keeps it.

* `as_attrition_table()` gained a `levels` argument, mirroring
  `as_attrition_tibble(levels = )`: it renders one row per criterion with a
  column block (N / Removed / % removed) per hierarchy level, so a single
  row reports its effect at both the unit of analysis and the unit of
  recruitment (e.g. participants and clusters) side by side. This is the
  reporting form required by the CONSORT cluster extension (Campbell,
  Elbourne & Altman, BMJ 2004;328:702-8) and the within-person extension.
  New `level_labels` argument supplies display names for the column blocks
  (level names are otherwise used as-is, unmangled). A `show_consequential`
  argument adds an optional fourth column per level for units lost only
  because a `group_include()`/`group_exclude()` group they belonged to was
  removed; by default it appears only when populated. `levels` cannot be
  combined with `group_x`/`group_y`/`branch_by`/`count_by`. Shading
  (`shade`/`shade_fn`) is computed per level.
