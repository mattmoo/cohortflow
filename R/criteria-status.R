#' Per-criterion status of every row
#'
#' Returns one row per row of the starting data and one logical column per
#' criterion, recording whether the row passed (`TRUE`), failed (`FALSE`), or
#' has no result (`NA`) for that criterion. Use it to audit who failed what,
#' or to plot overlapping exclusion reasons, which the step-by-step cascade
#' hides. To get the cohort itself, use [cohort()].
#'
#' @section Modes:
#' | Value | `mode = "cumulative"` | `mode = "independent"` |
#' |---|---|---|
#' | `TRUE` | Reached the step and passed it | The criterion holds for the row |
#' | `FALSE` | Removed at this step | The criterion fails for the row |
#' | `NA` | **Not assessed**: removed at an earlier step | The predicate gave `NA`, or a grouped step's `by` is `NA` |
#'
#' **Cumulative** mirrors the cascade used by [cohort()], [excluded()] and the
#' CONSORT diagram, and is built from the recorded steps without re-evaluating
#' anything. Each row has at most one `FALSE`. `NA` means the row never
#' reached that criterion, which is not the same as failing it; it only
#' becomes `FALSE` if you ask for that with `na = "false"`. Missing predicate
#' values follow the cascade: an `include()` that evaluates to `NA` removes
#' the row (`FALSE`), an `exclude()` that evaluates to `NA` keeps it (`TRUE`).
#'
#' **Independent** evaluates every criterion against the full starting data,
#' ignoring earlier steps, so a row can fail several criteria. Bear in mind:
#'
#' * `group_include()`, `group_exclude()` and `select_within()` depend on
#'   which rows are in each group. Evaluated on the full data, a group can
#'   pass or fail differently than it did in the cascade, where earlier steps
#'   had already removed some of its rows.
#' * In a [continue_criteria()] flow, columns joined at a later stage are `NA`
#'   for rows excluded before the join, so later-stage predicates are usually
#'   `NA` for those rows.
#' * `randomise()` steps are all `TRUE` (in cumulative mode they are `TRUE`
#'   where reached and `NA` otherwise). They are dropped by default.
#'
#' @section Set plots:
#' Set and overlap plots (e.g. the eulerr, UpSetR or ComplexUpset packages)
#' take a membership matrix with no missing values. The usual question is how
#' exclusion *reasons* overlap, so ask for failures and decide what `NA`
#' means:
#'
#' ```
#' m <- criteria_status(flow, mode = "independent", sets = "fail",
#'                      na = "false", as = "matrix")
#' # eulerr::euler(m); UpSetR::upset(as.data.frame(m * 1))
#' ```
#'
#' @param flow A `cf_flow` object produced by [apply_criteria()].
#' @param mode `"cumulative"` (default) or `"independent"`; see the section
#'   "Modes".
#' @param sets `"pass"` (default) reports whether each row passed each
#'   criterion; `"fail"` negates every criterion column (`NA` stays `NA`), so
#'   `TRUE` marks the reasons a row fails.
#' @param na What to do with `NA` in the criterion columns, applied after
#'   `sets`: `"keep"` (default) leaves them; `"false"` replaces them with
#'   `FALSE`; `"drop"` removes rows with any `NA`.
#' @param names Criterion column names: `"label"` (default) uses step labels,
#'   made unique with a warning if repeated; `"step"` uses `cf_step_<n>`. A
#'   name that clashes with an id or data column is made unique with a
#'   warning.
#' @param drop_randomise Logical. Omit `randomise()` steps (default `TRUE`).
#' @param keep_data Logical. Include the original data columns between the id
#'   column(s) and the criterion columns (default `FALSE`).
#' @param as Return type: `"tibble"` (default), `"data.table"` (requires the
#'   data.table package), or `"matrix"`, a logical matrix of the criterion
#'   columns only, with the row identifier as row names (`keep_data` is
#'   ignored).
#' @return For `"tibble"` and `"data.table"`: the id column(s) given as `id`
#'   to [apply_criteria()] (or `.cf_row_id` if none was given), then the data
#'   columns if `keep_data = TRUE`, then one logical column per criterion in
#'   step order. Rows are in the original data order. For `"matrix"`: a
#'   logical matrix.
#' @seealso [cohort()] for the cohort itself, [excluded()] for removed rows.
#' @examples
#' dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ age >= 18, label = "Adults only") |>
#'   include(~ eligible_screen, label = "Passed screening") |>
#'   exclude(~ withdrew, label = "Withdrew consent")
#' flow <- apply_criteria(dat, crit, id = "participant_id")
#'
#' criteria_status(flow)
#'
#' # How often each exclusion reason applies, counting overlaps
#' m <- criteria_status(flow, mode = "independent", sets = "fail",
#'                      na = "false", as = "matrix")
#' colSums(m)
#' @export
criteria_status <- function(flow,
                            mode = c("cumulative", "independent"),
                            sets = c("pass", "fail"),
                            na = c("keep", "false", "drop"),
                            names = c("label", "step"),
                            drop_randomise = TRUE,
                            keep_data = FALSE,
                            as = c("tibble", "data.table", "matrix")) {
  if (!inherits(flow, "cf_flow")) rlang::abort("`flow` must be a `cf_flow` object.")
  mode   <- match.arg(mode)
  sets   <- match.arg(sets)
  na     <- match.arg(na)
  naming <- match.arg(names)
  as     <- match.arg(as)
  if (!rlang::is_bool(drop_randomise)) rlang::abort("`drop_randomise` must be `TRUE` or `FALSE`.")
  if (!rlang::is_bool(keep_data)) rlang::abort("`keep_data` must be `TRUE` or `FALSE`.")
  if (as == "data.table") rlang::check_installed("data.table", reason = "for `as = \"data.table\"`.")

  idx <- seq_along(flow$steps)
  if (drop_randomise) {
    types <- vapply(flow$steps, function(s) s$type, character(1L))
    idx   <- idx[types != "randomise"]
  }

  id_cols   <- if (is.null(flow[["id"]])) ".cf_row_id" else flow[["id"]]
  data_cols <- if (keep_data && as != "matrix") {
    setdiff(base::names(flow$data), c(".cf_row_id", id_cols))
  } else {
    character(0L)
  }

  crit <- if (mode == "cumulative") .status_cumulative(flow, idx) else .status_independent(flow, idx)
  base::names(crit) <- .status_names(flow, idx, naming, reserved = c(id_cols, data_cols))

  .status_finalise(flow, crit, c(id_cols, data_cols), sets, na, as, keep_data)
}

# Cascade status from the step records: TRUE before the step that removed the
# row, FALSE at it, NA (not assessed) after it. Never-excluded rows are TRUE.
.status_cumulative <- function(flow, idx) {
  lookup <- .exclusion_lookup(flow)
  e <- lookup$cf_excluded_step[match(flow$data$.cf_row_id, lookup$.cf_row_id)]
  removed <- !is.na(e)
  lapply(flow$steps[idx], function(s) {
    out <- rep(TRUE, length(e))
    out[removed & e == s$step] <- FALSE
    out[removed & e < s$step]  <- NA
    out
  })
}

# Each criterion re-evaluated on the full data, keeping predicate NAs.
# This deliberately does not share code with the cascade's `switch()` in
# .run_criteria_steps() (R/apply.R): the cascade resolves NA per step type
# (include fails NA, exclude keeps it), whereas here NA is reported as is.
# Keep the two in step when adding a step type.
.status_independent <- function(flow, idx) {
  data <- flow$data
  lapply(flow$criteria$steps[idx], function(s) {
    switch(s$type,
      include       = eval_criterion(s, data),
      exclude       = !eval_criterion(s, data),
      group_include = eval_group_criterion(s, data),
      group_exclude = !eval_group_criterion(s, data),
      select_within = {
        pass <- eval_select_criterion(s, data)
        # The evaluator leaves rows with an NA group key as FALSE; they have
        # no group, so report NA.
        pass[!stats::complete.cases(data[s$by])] <- NA
        pass
      },
      randomise = rep(TRUE, nrow(data)),
      rlang::abort(sprintf("Unknown criterion type: %s", s$type))
    )
  })
}

# Criterion column names: step labels (made unique) or cf_step_<n>, then
# disambiguated against the id/data columns in `reserved`.
.status_names <- function(flow, idx, naming, reserved) {
  if (length(idx) == 0L) return(character(0L))
  if (naming == "step") {
    nm <- paste0("cf_step_", .step_numbers(flow)[idx])
  } else {
    nm <- .step_labels(flow)[idx]
    if (anyDuplicated(nm)) {
      dup <- unique(nm[duplicated(nm)])
      rlang::warn(sprintf(
        "Step label(s) used more than once: %s. Column names made unique with \" #<n>\".",
        paste0("\"", dup, "\"", collapse = ", ")
      ))
      nm <- make.unique(nm, sep = " #")
    }
  }
  clash <- nm[nm %in% reserved]
  if (length(clash) > 0L) {
    rlang::warn(sprintf(
      "Criterion column name(s) clash with id or data columns: %s. Made unique with \" #<n>\".",
      paste0("\"", clash, "\"", collapse = ", ")
    ))
    nm <- make.unique(c(reserved, nm), sep = " #")[length(reserved) + seq_along(nm)]
  }
  nm
}

# Applies `sets` and `na`, then assembles the requested return type.
.status_finalise <- function(flow, crit, lead_cols, sets, na, as, keep_data) {
  n <- nrow(flow$data)
  if (sets == "fail") crit <- lapply(crit, `!`)
  if (na == "false") crit <- lapply(crit, function(x) replace(x, is.na(x), FALSE))
  keep_rows <- if (na == "drop") {
    Reduce(`&`, lapply(crit, Negate(is.na)), rep(TRUE, n))
  } else {
    rep(TRUE, n)
  }

  if (as == "matrix") {
    if (keep_data) message("`keep_data` is ignored when `as = \"matrix\"`.")
    row_key <- gsub("\r", "|", as.character(flow$data$.cf_row_id), fixed = TRUE)
    m <- matrix(as.logical(unlist(crit, use.names = FALSE)), nrow = n, ncol = length(crit),
                dimnames = list(row_key, base::names(crit)))
    return(m[keep_rows, , drop = FALSE])
  }

  out <- tibble::as_tibble(flow$data[lead_cols])
  for (nm in base::names(crit)) out[[nm]] <- crit[[nm]]
  out <- out[keep_rows, , drop = FALSE]
  if (as == "data.table") data.table::as.data.table(out) else out
}
