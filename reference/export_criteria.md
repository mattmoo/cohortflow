# Export a criteria pipeline to YAML

Serialises a `cf_criteria` object to a human-readable YAML file (or
string). The schema is self-describing and can be re-imported with
[`import_criteria()`](https://mattmoo.github.io/cohortflow/reference/import_criteria.md).

## Usage

``` r
export_criteria(criteria, path = NULL, fn_refs = list())
```

## Arguments

- criteria:

  A `cf_criteria` object.

- path:

  A file path to write to. If `NULL` (default), the YAML text is
  returned as a character string.

- fn_refs:

  An optional named list mapping function objects to `"pkg::name"`
  reference strings.

## Value

When `path = NULL`, the YAML text as a character string (returned
visibly, so it prints at the console). Otherwise, invisibly, the
`criteria` object.

## YAML schema

    cohortflow_criteria:
      version: 1
      steps:
        - label:  "Adults only"
          type:   include
          kind:   formula
          by:     null
          expr:   "age >= 18"
          fn_ref: null
          category: null
          reason: "Under 18"   # only written when set

A file with a higher `version` than this package reads is refused with
an error.

Formula-based criteria round-trip cleanly. For function predicates
(`kind: function`), `expr` holds the full deparsed function source,
including its argument list and any default values (e.g.
`"function(d, thr = 18) d$age >= thr"`); complex closures may not
round-trip and a warning is issued. Named exported functions can be
stored as `"pkg::name"` references via `fn_refs`. Files written by
earlier versions, which stored the function body in `expr` and the
argument names in a separate `fn_args` field, can still be imported,
with a warning that default argument values were not stored and the file
should be re-saved.

## See also

[`import_criteria()`](https://mattmoo.github.io/cohortflow/reference/import_criteria.md)
to read the file back.

Other yaml:
[`import_criteria()`](https://mattmoo.github.io/cohortflow/reference/import_criteria.md)

## Examples

``` r
crit <- cf_criteria() |>
  include(~ age >= 18, label = "Adults only", category = "Age") |>
  exclude(~ withdrew,  label = "Withdrew consent")

# As a string
cat(export_criteria(crit))
#> cohortflow_criteria:
#>   version: 1
#>   steps:
#>   - label: Adults only
#>     type: include
#>     kind: formula
#>     by: ~
#>     expr: age >= 18
#>     fn_ref: ~
#>     category: Age
#>     arms: ~
#>   - label: Withdrew consent
#>     type: exclude
#>     kind: formula
#>     by: ~
#>     expr: withdrew
#>     fn_ref: ~
#>     category: ~
#>     arms: ~

# To a file, then back again
path <- tempfile(fileext = ".yml")
export_criteria(crit, path = path)
import_criteria(path = path)
#> Cohort criteria pipeline  (2 steps)
#>    1. [+][~] (include) {Age} Adults only
#>           age >= 18
#>    2. [-][~] (exclude) Withdrew consent
#>           withdrew
unlink(path)
```
