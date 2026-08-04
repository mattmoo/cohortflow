#' Continue a criteria pipeline on top of an existing flow
#'
#' Applies additional criteria steps to the surviving cohort of an existing
#' `cf_flow`, optionally joining on new columns first. This lets an
#' attrition pipeline be built up in stages -- e.g. apply screening criteria,
#' then join newly collected follow-up data and continue with further
#' criteria -- while keeping a single, continuous step numbering and
#' denominators that correctly reflect the cohort at each stage (rather than
#' restarting counts from the original data).
#'
#' @param flow A `cf_flow` object produced by [apply_criteria()] (or a
#'   previous call to `continue_criteria()`).
#' @param criteria A `cf_criteria` object with the additional steps to apply.
#'   If empty (`length(criteria) == 0`), `flow` is returned unchanged.
#' @param join Optional data frame of new columns to attach before evaluating
#'   `criteria`, e.g. follow-up data collected after the initial screening.
#'   Joined onto **all** of `flow`'s original rows (via a left join), so rows
#'   already excluded at an earlier stage also gain the new columns (as `NA`
#'   where `join` has no match) -- this keeps the full row history intact.
#'   Requires `by`.
#' @param by Column name(s) shared by `flow`'s data and `join`, used to join
#'   them. Required, and only used, when `join` is supplied.
#'
#' @return A `cf_flow` object whose `criteria` and `steps` are the
#'   concatenation of `flow`'s existing pipeline and `criteria`, with step
#'   numbers continuing on from `flow`.
#' @export
#'
#' @examples
#' dat  <- mock_cohortflow(n_participants = 200, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ eligible_screen, label = "Passed screening")
#' flow <- apply_criteria(dat, crit)
#'
#' more_crit <- cf_criteria() |>
#'   include(~ !is.na(consent_date), label = "Consent recorded")
#' flow2 <- continue_criteria(flow, more_crit)
#' flow2
continue_criteria <- function(flow, criteria, join = NULL, by = NULL) {
  if (!inherits(flow, "cf_flow")) rlang::abort("`flow` must be a `cf_flow` object.")
  if (!inherits(criteria, "cf_criteria")) {
    rlang::abort("`criteria` must be a `cf_criteria` object.")
  }

  if (length(criteria) == 0L) return(flow)

  updated_data <- flow$data

  if (!is.null(join)) {
    updated_data <- .join_continue(updated_data, join, by)
  } else if (!is.null(by)) {
    rlang::abort("`by` is only used together with `join`.")
  }

  surviving_ids <- .surviving_with_id(flow)$.cf_row_id
  current <- updated_data[updated_data$.cf_row_id %in% surviving_ids, , drop = FALSE]

  result <- .run_criteria_steps(current, criteria$steps, step_offset = length(flow$steps),
                                hierarchy = flow$hierarchy)

  new_cf_flow(
    data      = updated_data,
    criteria  = c(flow$criteria, criteria),
    steps     = c(flow$steps, result$step_records),
    hierarchy = flow$hierarchy
  )
}

# ---------------------------------------------------------------------------
# Internal: left-join new columns onto the full (pre-exclusion) flow data

.join_continue <- function(data, join, by) {
  if (!is.data.frame(join)) rlang::abort("`join` must be a data frame.")
  if (is.null(by)) {
    rlang::abort("`by` must be supplied when `join` is used.")
  }

  missing_in_join <- setdiff(by, names(join))
  if (length(missing_in_join) > 0L) {
    rlang::abort(sprintf(
      "`by` column(s) not found in `join`: %s.",
      paste(missing_in_join, collapse = ", ")
    ))
  }
  missing_in_data <- setdiff(by, names(data))
  if (length(missing_in_data) > 0L) {
    rlang::abort(sprintf(
      "`by` column(s) not found in `flow`'s data: %s.",
      paste(missing_in_data, collapse = ", ")
    ))
  }

  colliding <- intersect(setdiff(names(join), by), names(data))
  if (length(colliding) > 0L) {
    rlang::abort(sprintf(
      "`join` column(s) also present in `flow`'s data (other than `by`): %s.",
      paste(colliding, collapse = ", ")
    ))
  }

  .assert_no_join_fanout(join, by)

  dplyr::left_join(data, join, by = by)
}
