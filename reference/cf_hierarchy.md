# Declare the nesting hierarchy for a cohort

A `cf_hierarchy` describes how observational units are nested within
each other (e.g., participants within clusters within sites). It is an
ordered named list mapping role names to column name(s) in the data.

## Usage

``` r
cf_hierarchy(...)
```

## Arguments

- ...:

  Named arguments mapping role labels to column names, e.g.
  `participant = "participant_id", cluster = "cluster_id"`. A role's
  value may be a character vector of more than one column when the level
  is a composite (multi-column) key, e.g.
  `cluster_period = c("cluster_id", "period")` for a stepped-wedge
  design. At least one entry is required.

## Value

A `cf_hierarchy` object (a named list with additional class attribute).

## Details

The order of `...` is from the **finest** (innermost) level to the
**coarsest** (outermost) level. The first role is conventionally the
individual participant.

## See also

Other pipeline:
[`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md),
[`cf_expected()`](https://mattmoo.github.io/cohortflow/reference/cf_expected.md),
[`continue_criteria()`](https://mattmoo.github.io/cohortflow/reference/continue_criteria.md)

## Examples

``` r
# Two-level: participants within clusters
cf_hierarchy(participant = "pid", cluster = "cid")
#> Cohort hierarchy (finest → coarsest):
#>   ├─ participant  →  column: pid
#>   └─ cluster  →  column: cid

# Three-level: participants within clusters within sites
cf_hierarchy(participant = "pid", cluster = "cluster_id", site = "site_id")
#> Cohort hierarchy (finest → coarsest):
#>   ├─ participant  →  column: pid
#>   ├─ cluster  →  column: cluster_id
#>   └─ site  →  column: site_id

# Composite (multi-column) level: stepped-wedge cluster-period
cf_hierarchy(participant = "pid",
             cluster_period = c("cluster_id", "period"),
             cluster = "cluster_id")
#> Cohort hierarchy (finest → coarsest):
#>   ├─ participant  →  column: pid
#>   ├─ cluster_period  →  column: cluster_id + period
#>   └─ cluster  →  column: cluster_id
```
