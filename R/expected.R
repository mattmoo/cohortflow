#' Declare the expected set of observational units
#'
#' Builds a data frame with one row for every combination of the supplied
#' vectors (a full cross-join), for use as the `expected` argument to
#' [apply_criteria()]. This lets attrition be denominated against the units
#' that *should* exist (e.g. every participant who was invited) rather than
#' only the rows actually present in `data` -- so a participant who never
#' appears in the raw data is still counted as failing the first step that
#' requires non-missing data, instead of being silently absent from the
#' denominator.
#'
#' @param ... Named vectors of values, one per grouping variable, e.g.
#'   `participant_id = 1:50, visit = c("baseline", "3mo", "6mo")`. At least
#'   one named argument is required.
#' @param stringsAsFactors Passed to [expand.grid()]; default `FALSE`.
#'
#' @return A tibble with one row per expected combination and one column per
#'   named argument in `...`.
#' @export
#'
#' @examples
#' cf_expected(participant_id = 1:3, visit = c("baseline", "3mo"))
cf_expected <- function(..., stringsAsFactors = FALSE) {
  args <- list(...)

  if (length(args) == 0L) {
    rlang::abort("`cf_expected()` requires at least one named argument.")
  }
  if (is.null(names(args)) || any(!nzchar(names(args)))) {
    rlang::abort("All arguments to `cf_expected()` must be named.")
  }

  grid <- expand.grid(args, stringsAsFactors = stringsAsFactors, KEEP.OUT.ATTRS = FALSE)
  tibble::as_tibble(grid)
}
