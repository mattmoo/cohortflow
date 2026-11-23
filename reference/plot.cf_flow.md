# Plot method for `cf_flow` objects

A thin wrapper around
[`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md)
so that `plot(flow)` draws a CONSORT flow diagram directly from a
`cf_flow` object.

## Usage

``` r
# S3 method for class 'cf_flow'
plot(x, ...)
```

## Arguments

- x:

  A `cf_flow` object produced by
  [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md).

- ...:

  Additional arguments passed on to
  [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md).

## Value

A `consort_diagram` object, invisibly printed.

## Examples

``` r
dat  <- mock_parallel_rct(n_participants = 100, seed = 1)
crit <- cf_criteria() |>
  include(~ age >= 18, label = "Adults only") |>
  exclude(~ withdrew,  label = "Withdrew consent")
flow <- apply_criteria(dat, crit)
#> No `id` supplied and no `.cf_row_id` column found. Adding a sequential `.cf_row_id`.
plot(flow)

plot(flow, wrap_width = 20, title = "Participant flow")
```
