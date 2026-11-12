# cohortflow 0.0.0.9011

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
