# Print method for `consort_diagram` objects

Draws a `consort_diagram` (produced by
[`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md))
on the current graphics device via the standard `ggplot2` print method
(which opens a new page before drawing).

## Usage

``` r
# S3 method for class 'consort_diagram'
print(x, ...)
```

## Arguments

- x:

  A `consort_diagram` object.

- ...:

  Additional arguments passed on to
  [`ggplot2::print.ggplot()`](https://ggplot2.tidyverse.org/reference/print.ggplot.html).

## Value

`x`, invisibly.

## Examples

``` r
dat  <- mock_parallel_rct(n_participants = 100, seed = 1)
crit <- cf_criteria() |> include(~ age >= 18, label = "Adults only")
diagram <- as_consort_diagram(apply_criteria(dat, crit))
#> No `id` supplied and no `.cf_row_id` column found. Adding a sequential `.cf_row_id`.
print(diagram)
```
