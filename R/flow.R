#' The cohort flow result object
#'
#' A `cf_flow` object is returned by [apply_criteria()]. It stores the
#' original data (with an internal `.cf_row_id` column), the criteria pipeline
#' that produced it, and a per-step record of attrition. Use [cohort()] to
#' extract the surviving rows and [excluded()] to extract all removed rows with
#' step metadata attached.
#'
#' @keywords internal
new_cf_flow <- function(data, criteria, steps) {
  structure(
    list(
      data     = data,
      criteria = criteria,
      steps    = steps
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
      select_within = "[>]"
    )
    by_str <- if (!is.null(s$by)) sprintf(" by %s", s$by) else ""
    cat(sprintf(
      "  %2d. %s %s%s\n       n_in: %d  kept: %d  removed: %d\n",
      s$step, type_sym, s$label, by_str,
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
#' @return A tibble.
#' @export
cohort <- function(flow) {
  if (!inherits(flow, "cf_flow")) rlang::abort("`flow` must be a `cf_flow` object.")
  all_excluded_ids <- unlist(lapply(flow$steps, `[[`, "excluded_ids"))
  surviving <- flow$data[!flow$data$.cf_row_id %in% all_excluded_ids, , drop = FALSE]
  surviving$.cf_row_id <- NULL
  tibble::as_tibble(surviving)
}

#' Extract excluded rows from a flow object
#'
#' Returns a flat tibble of all rows removed at any step, with additional
#' columns `cf_step` (integer), `cf_label` (character), and `cf_type`
#' (character). Rows are in step order.
#'
#' @param flow A `cf_flow` object produced by [apply_criteria()].
#' @return A tibble with original columns plus `cf_step`, `cf_label`, `cf_type`.
#' @export
excluded <- function(flow) {
  if (!inherits(flow, "cf_flow")) rlang::abort("`flow` must be a `cf_flow` object.")

  chunks <- lapply(flow$steps, function(s) {
    if (length(s$excluded_ids) == 0L) return(NULL)
    rows <- flow$data[flow$data$.cf_row_id %in% s$excluded_ids, , drop = FALSE]
    rows$cf_step  <- s$step
    rows$cf_label <- s$label
    rows$cf_type  <- s$type
    rows
  })
  chunks <- Filter(Negate(is.null), chunks)

  if (length(chunks) == 0L) {
    empty <- flow$data[0L, , drop = FALSE]
    empty$cf_step  <- integer(0L)
    empty$cf_label <- character(0L)
    empty$cf_type  <- character(0L)
    return(tibble::as_tibble(empty))
  }

  tibble::as_tibble(do.call(rbind, chunks))
}

