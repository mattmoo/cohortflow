# Declare the expected set of observational units

Builds a data frame with one row for every combination of the supplied
vectors (a full cross-join), for use as the `expected` argument to
[`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md).
This lets attrition be denominated against the units that *should* exist
(e.g. every participant who was invited) rather than only the rows
actually present in `data` – so a participant who never appears in the
raw data is still counted as failing the first step that requires
non-missing data, instead of being silently absent from the denominator.

## Usage

``` r
cf_expected(..., stringsAsFactors = FALSE)
```

## Arguments

- ...:

  Named vectors of values, one per grouping variable, e.g.
  `participant_id = 1:50, visit = c("baseline", "3mo", "6mo")`. At least
  one named argument is required.

- stringsAsFactors:

  Passed to [`expand.grid()`](https://rdrr.io/r/base/expand.grid.html);
  default `FALSE`.

## Value

A tibble with one row per expected combination and one column per named
argument in `...`.

## See also

Other pipeline:
[`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md),
[`cf_hierarchy()`](https://mattmoo.github.io/cohortflow/reference/cf_hierarchy.md),
[`continue_criteria()`](https://mattmoo.github.io/cohortflow/reference/continue_criteria.md)

## Examples

``` r
cf_expected(participant_id = 1:3, visit = c("baseline", "3mo"))
#> # A tibble: 6 × 2
#>   participant_id visit   
#>            <int> <chr>   
#> 1              1 baseline
#> 2              2 baseline
#> 3              3 baseline
#> 4              1 3mo     
#> 5              2 3mo     
#> 6              3 3mo     
```
