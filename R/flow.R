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
#' Returns the rows that passed all criteria, with the internal `.cf_row_id`
#' column removed.
#'
#' @param flow A `cf_flow` object produced by [apply_criteria()].
#' @param flag Logical. When `FALSE` (default), returns only the surviving
#'   rows (the historical behaviour). When `TRUE`, returns **all** original
#'   rows, in their original order, with attribution columns added instead of
#'   filtering: `cf_included` (logical), `cf_excluded_step` (integer, `NA` if
#'   included), `cf_excluded_label` (character, `NA` if included), and
#'   `cf_excluded_category` (character, `NA` if uncategorised or included).
#'   Useful when downstream code needs every row present (e.g. plotting a
#'   full recording) while still knowing which rows count.
#' @return A tibble.
#' @export
cohort <- function(flow, flag = FALSE) {
  if (!inherits(flow, "cf_flow")) rlang::abort("`flow` must be a `cf_flow` object.")

  if (flag) {
    lookup_chunks <- lapply(flow$steps, function(s) {
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

  all_excluded_ids <- unlist(lapply(flow$steps, `[[`, "excluded_ids"))
  surviving <- flow$data[!flow$data$.cf_row_id %in% all_excluded_ids, , drop = FALSE]
  surviving$.cf_row_id <- NULL
  tibble::as_tibble(surviving)
}

# Like cohort(), but keeps `.cf_row_id` (needed internally by
# continue_criteria(), which must be able to re-attach step records using the
# same identifier).
.surviving_with_id <- function(flow) {
  all_excluded_ids <- unlist(lapply(flow$steps, `[[`, "excluded_ids"))
  flow$data[!flow$data$.cf_row_id %in% all_excluded_ids, , drop = FALSE]
}

#' Extract excluded rows from a flow object
#'
#' Returns a flat tibble of all rows removed at any step, with additional
#' columns `cf_step` (integer), `cf_label` (character), `cf_type` (character),
#' and `cf_category` (character, `NA` if the criterion had no category).
#' Rows are in step order.
#'
#' @param flow A `cf_flow` object produced by [apply_criteria()].
#' @return A tibble with original columns plus `cf_step`, `cf_label`,
#'   `cf_type`, `cf_category`.
#' @export
excluded <- function(flow) {
  if (!inherits(flow, "cf_flow")) rlang::abort("`flow` must be a `cf_flow` object.")

  chunks <- lapply(flow$steps, function(s) {
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
