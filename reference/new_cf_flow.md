# The cohort flow result object

A `cf_flow` object is returned by
[`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md).
It stores the original data (with an internal `.cf_row_id` column), the
criteria pipeline that produced it, a per-step record of attrition, and
(optionally) the `cf_hierarchy` used for per-level counting. Use
[`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md)
to extract the surviving rows and
[`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md)
to extract all removed rows with step metadata attached.

## Usage

``` r
new_cf_flow(data, criteria, steps, hierarchy = NULL, id = NULL)
```

## Details

`id` records the column name(s) passed as `id` to
[`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md),
or `NULL` when `.cf_row_id` was pre-existing or auto-generated. Flows
built before this field existed lack it, so read it with `flow[["id"]]`.
