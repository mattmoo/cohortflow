#' The cohort flow result object
#'
#' A `cf_flow` object is returned by [apply_criteria()]. It stores the
#' original data (with an internal `.cf_row_id` column), the criteria pipeline
#' that produced it, a per-step record of attrition, and (optionally) the
#' `cf_hierarchy` used for per-level counting. Use [cohort()] to extract the
#' surviving rows and [excluded()] to extract all removed rows with step
#' metadata attached.
#'
#' @keywords internal
new_cf_flow <- function(data, criteria, steps, hierarchy = NULL) {
  structure(
    list(
      data      = data,
      criteria  = criteria,
      steps     = steps,
      hierarchy = hierarchy
    ),
    class = "cf_flow"
  )
}

# ---------------------------------------------------------------------------
# S3 methods

#' @export
print.cf_flow <- function(x, ...) {
  n_steps   <- length(x$steps)
  n_start   <- nrow(x$data)
  surviving <- cohort(x)
  n_end     <- nrow(surviving)

  cat(sprintf(
    "Cohort flow  (%d step%s | %d -> %d rows | %d excluded)\n",
    n_steps, if (n_steps == 1L) "" else "s",
    n_start, n_end, n_start - n_end
  ))
  cat(rep("-", 60), "\n", sep = "")

  for (s in x$steps) {
    type_sym <- switch(s$type,
      include       = "[+]",
      exclude       = "[-]",
      group_include = "[+]",
      group_exclude = "[-]",
      select_within = "[>]",
      randomise     = "[R]"
    )
    by_str   <- if (!is.null(s$by))   sprintf(" by %s", paste(s$by, collapse = ", ")) else ""
    arms_str <- if (!is.null(s$arms)) sprintf(" arms %s", s$arms) else ""
    cat_str  <- if (!is.null(s$category)) sprintf(" {%s}", s$category) else ""
    cat(sprintf(
      "  %2d. %s %s%s%s%s\n       n_in: %d  kept: %d  removed: %d\n",
      s$step, type_sym, s$label, by_str, arms_str, cat_str,
      s$n_in, s$n_pass, s$n_fail
    ))
  }
  invisible(x)
}

# ---------------------------------------------------------------------------
# Extractors

#' Extract the surviving cohort from a flow object
#'
#' Returns the rows that passed all criteria (or, with a step selector, all
#' criteria up to a chosen step), with the internal `.cf_row_id` column
#' removed.
#'
#' @section Intermediate steps:
#' A selector picks a step and means "up to and including that step". With
#' none given, the last step is used. At most one may be given:
#'
#' * `step_number`: a whole number `k` from `0` to the number of steps; `0` is
#'   the starting data.
#' * `label`: an exact step label. Errors if no step, or several steps, have it.
#' * `category`: a category name; selects the last step in that category.
#' * `at`: picks automatically. A number is a `step_number`; a string is a
#'   `label` if one matches, else a `category`. A string that is both a label
#'   and a category is an error: use `label` or `category` explicitly.
#'
#' @param flow A `cf_flow` object produced by [apply_criteria()].
#' @param flag Logical. When `FALSE` (default), returns only the surviving
#'   rows (the historical behaviour). When `TRUE`, returns **all** original
#'   rows, in their original order, with attribution columns added instead of
#'   filtering: `cf_included` (logical), `cf_excluded_step` (integer, `NA` if
#'   included), `cf_excluded_label` (character, `NA` if included), and
#'   `cf_excluded_category` (character, `NA` if uncategorised or included).
#'   Useful when downstream code needs every row present (e.g. plotting a
#'   full recording) while still knowing which rows count. Combined with a
#'   step selector, attribution only considers steps up to that step; rows
#'   removed later count as included.
#' @param at Optional automatic step selector (number, label or category);
#'   see the section "Intermediate steps".
#' @param step_number Optional whole step number (`0` = starting data).
#' @param label Optional exact step label.
#' @param category Optional category name (last step in that category).
#' @return A tibble.
#' @examples
#' dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ !is.na(age), label = "Age recorded") |>
#'   include(~ eligible_screen, label = "Passed screening") |>
#'   exclude(~ withdrew, label = "Withdrew consent")
#' flow <- apply_criteria(dat, crit)
#' cohort(flow)                            # final survivors
#' cohort(flow, at = "Passed screening")   # screening cohort (auto-select)
#' cohort(flow, label = "Passed screening") # same, explicit
#' nrow(cohort(flow, step_number = 0))     # the starting data
#' excluded(flow, at = 2)                  # removed by steps 1-2
#' @export
cohort <- function(flow, flag = FALSE, at = NULL, step_number = NULL, label = NULL, category = NULL) {
  if (!inherits(flow, "cf_flow")) rlang::abort("`flow` must be a `cf_flow` object.")
  k <- .resolve_step(flow, at, step_number, label, category)

  if (flag) {
    lookup_chunks <- lapply(flow$steps[seq_len(k)], function(s) {
      if (length(s$excluded_ids) == 0L) return(NULL)
      tibble::tibble(
        .cf_row_id           = s$excluded_ids,
        cf_excluded_step     = s$step,
        cf_excluded_label    = s$label,
        cf_excluded_category = if (is.null(s$category)) NA_character_ else s$category
      )
    })
    lookup_chunks <- Filter(Negate(is.null), lookup_chunks)

    flagged <- if (length(lookup_chunks) > 0L) {
      dplyr::left_join(flow$data, do.call(rbind, lookup_chunks), by = ".cf_row_id")
    } else {
      flow$data$cf_excluded_step     <- NA_integer_
      flow$data$cf_excluded_label    <- NA_character_
      flow$data$cf_excluded_category <- NA_character_
      flow$data
    }
    flagged$cf_included <- is.na(flagged$cf_excluded_step)
    flagged$.cf_row_id  <- NULL
    return(tibble::as_tibble(flagged))
  }

  surviving <- flow$data[flow$data$.cf_row_id %in% .surviving_ids(flow, k), , drop = FALSE]
  surviving$.cf_row_id <- NULL
  tibble::as_tibble(surviving)
}

# Row ids from `flow$data` not excluded by steps 1..step_num (0 = all rows).
.surviving_ids <- function(flow, step_num = length(flow$steps)) {
  if (step_num <= 0L) return(flow$data$.cf_row_id)
  excluded_ids <- unlist(lapply(flow$steps[seq_len(step_num)], `[[`, "excluded_ids"))
  flow$data$.cf_row_id[!flow$data$.cf_row_id %in% excluded_ids]
}

# Like cohort(), but keeps `.cf_row_id` (needed internally by
# continue_criteria(), which must be able to re-attach step records using the
# same identifier).
.surviving_with_id <- function(flow) {
  flow$data[flow$data$.cf_row_id %in% .surviving_ids(flow), , drop = FALSE]
}

# Resolve the step selectors to a step number in 0..length(flow$steps).
# At most one of `at` (auto), `step_number`, `label`, `category` may be given.
.resolve_step <- function(flow, at = NULL, step_number = NULL, label = NULL, category = NULL) {
  given <- c(at = !is.null(at), step_number = !is.null(step_number),
             label = !is.null(label), category = !is.null(category))
  if (sum(given) > 1L) {
    rlang::abort(sprintf(
      "Give at most one of `at`, `step_number`, `label`, `category`; got %s.",
      paste0("`", names(given)[given], "`", collapse = ", ")
    ))
  }
  if (!any(given)) return(length(flow$steps))
  if (given[["step_number"]]) return(.step_by_number(flow, step_number, "step_number"))
  if (given[["label"]]) return(.step_by_label(flow, label, "label"))
  if (given[["category"]]) return(.step_by_category(flow, category, "category"))

  # `at`: numbers are step numbers; strings are a label, else a category.
  if (length(at) != 1L || is.na(at)) {
    rlang::abort("`at` must be a single non-missing step number, label or category name.")
  }
  if (is.numeric(at)) return(.step_by_number(flow, at, "at"))
  if (!is.character(at)) {
    rlang::abort("`at` must be a step number or a step label/category name.")
  }
  has_label    <- any(.step_labels(flow) == at)
  has_category <- any(.step_categories(flow) == at, na.rm = TRUE)
  if (has_label && has_category) {
    rlang::abort(sprintf(
      "`at` = \"%s\" is both a step label and a category name; use `label =` or `category =` instead.", at
    ))
  }
  if (has_label) return(.step_by_label(flow, at, "at"))
  if (has_category) return(.step_by_category(flow, at, "at"))
  rlang::abort(sprintf("`at` = \"%s\" matches no step label or category.", at))
}

.step_labels <- function(flow) vapply(flow$steps, function(s) s$label, character(1L))

.step_categories <- function(flow) {
  vapply(flow$steps, function(s) if (is.null(s$category)) NA_character_ else s$category, character(1L))
}

.step_numbers <- function(flow) vapply(flow$steps, function(s) as.integer(s$step), integer(1L))

.step_by_number <- function(flow, x, arg) {
  n_steps <- length(flow$steps)
  if (!is.numeric(x) || length(x) != 1L || is.na(x)) {
    rlang::abort(sprintf("`%s` must be a single non-missing whole number.", arg))
  }
  if (x %% 1 != 0) {
    rlang::abort(sprintf("`%s` must be a whole step number, not %s.", arg, format(x)))
  }
  if (x < 0 || x > n_steps) {
    rlang::abort(sprintf("`%s` = %s is out of range; the flow has %d step(s) (use 0..%d).",
                         arg, format(x), n_steps, n_steps))
  }
  as.integer(x)
}

.step_by_label <- function(flow, x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    rlang::abort(sprintf("`%s` must be a single non-missing string.", arg))
  }
  hits <- .step_numbers(flow)[.step_labels(flow) == x]
  if (length(hits) == 0L) rlang::abort(sprintf("`%s` = \"%s\" matches no step label.", arg, x))
  if (length(hits) > 1L) {
    rlang::abort(sprintf(
      "`%s` = \"%s\" matches %d steps by label (%s); use `step_number` instead.",
      arg, x, length(hits), paste(hits, collapse = ", ")
    ))
  }
  hits
}

.step_by_category <- function(flow, x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    rlang::abort(sprintf("`%s` must be a single non-missing string.", arg))
  }
  cats <- .step_categories(flow)
  hits <- .step_numbers(flow)[!is.na(cats) & cats == x]
  if (length(hits) == 0L) rlang::abort(sprintf("`%s` = \"%s\" matches no category.", arg, x))
  max(hits)
}

#' Extract excluded rows from a flow object
#'
#' Returns a flat tibble of all rows removed at any step (or, with `at`, up to
#' and including a chosen step), with additional
#' columns `cf_step` (integer), `cf_label` (character), `cf_type` (character),
#' and `cf_category` (character, `NA` if the criterion had no category).
#' Rows are in step order. Rows removed at a single step `k` are
#' `excluded(flow) |> dplyr::filter(cf_step == k)`.
#'
#' @inheritParams cohort
#' @inheritSection cohort Intermediate steps
#' @return A tibble with original columns plus `cf_step`, `cf_label`,
#'   `cf_type`, `cf_category`.
#' @export
excluded <- function(flow, at = NULL, step_number = NULL, label = NULL, category = NULL) {
  if (!inherits(flow, "cf_flow")) rlang::abort("`flow` must be a `cf_flow` object.")
  k <- .resolve_step(flow, at, step_number, label, category)

  chunks <- lapply(flow$steps[seq_len(k)], function(s) {
    if (length(s$excluded_ids) == 0L) return(NULL)
    rows <- flow$data[flow$data$.cf_row_id %in% s$excluded_ids, , drop = FALSE]
    rows$cf_step     <- s$step
    rows$cf_label    <- s$label
    rows$cf_type     <- s$type
    rows$cf_category <- if (is.null(s$category)) NA_character_ else s$category
    rows
  })
  chunks <- Filter(Negate(is.null), chunks)

  if (length(chunks) == 0L) {
    empty <- flow$data[0L, , drop = FALSE]
    empty$cf_step     <- integer(0L)
    empty$cf_label    <- character(0L)
    empty$cf_type     <- character(0L)
    empty$cf_category <- character(0L)
    return(tibble::as_tibble(empty))
  }

  tibble::as_tibble(do.call(rbind, chunks))
}
