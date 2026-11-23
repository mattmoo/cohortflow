# Import a criteria pipeline from YAML

Reads a YAML file (or string) written by
[`export_criteria()`](https://mattmoo.github.io/cohortflow/reference/export_criteria.md)
and reconstructs a `cf_criteria` object.

## Usage

``` r
import_criteria(path = NULL, text = NULL, envir = parent.frame())
```

## Arguments

- path:

  A file path to read from. Exactly one of `path` or `text` must be
  supplied.

- text:

  A YAML string. Exactly one of `path` or `text` must be supplied.

- envir:

  The environment in which to evaluate re-parsed expressions.

## Value

A `cf_criteria` object.

## Security

Criteria files contain R code: every formula and function predicate is
parsed and evaluated when the file is imported (and again when the
criteria are applied), and `fn_ref` entries are looked up and called.
Treat a criteria file like an R script: do not import files from
untrusted sources.

## See also

[`export_criteria()`](https://mattmoo.github.io/cohortflow/reference/export_criteria.md)
to write a pipeline.

Other yaml:
[`export_criteria()`](https://mattmoo.github.io/cohortflow/reference/export_criteria.md)

## Examples

``` r
yml <- "
cohortflow_criteria:
  version: 1
  steps:
    - label: Adults only
      type: include
      kind: formula
      expr: age >= 18
    - label: Withdrew consent
      type: exclude
      kind: formula
      expr: withdrew
"
crit <- import_criteria(text = yml)
crit
#> Cohort criteria pipeline  (2 steps)
#>    1. [+][~] (include) Adults only
#>           age >= 18
#>    2. [-][~] (exclude) Withdrew consent
#>           withdrew

dat <- mock_parallel_rct(n_participants = 100, seed = 1)
apply_criteria(dat, crit)
#> No `id` supplied and no `.cf_row_id` column found. Adding a sequential `.cf_row_id`.
#> Cohort flow  (2 steps | 100 -> 90 rows | 10 excluded)
#> ------------------------------------------------------------
#>    1. [+] Adults only
#>        n_in: 100  kept: 94  removed: 6
#>    2. [-] Withdrew consent
#>        n_in: 94  kept: 90  removed: 4
```
