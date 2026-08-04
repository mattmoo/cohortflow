#' Declare the nesting hierarchy for a cohort
#'
#' A `cf_hierarchy` describes how observational units are nested within each
#' other (e.g., participants within clusters within sites). It is an ordered
#' named list mapping role names to column name(s) in the data.
#'
#' The order of `...` is from the **finest** (innermost) level to the
#' **coarsest** (outermost) level. The first role is conventionally the
#' individual participant.
#'
#' @param ... Named arguments mapping role labels to column names, e.g.
#'   `participant = "participant_id", cluster = "cluster_id"`. A role's value
#'   may be a character vector of more than one column when the level is a
#'   composite (multi-column) key, e.g.
#'   `cluster_period = c("cluster_id", "period")` for a stepped-wedge design.
#'   At least one entry is required.
#'
#' @return A `cf_hierarchy` object (a named list with additional class
#'   attribute).
#' @export
#'
#' @examples
#' # Two-level: participants within clusters
#' cf_hierarchy(participant = "pid", cluster = "cid")
#'
#' # Three-level: participants within clusters within sites
#' cf_hierarchy(participant = "pid", cluster = "cluster_id", site = "site_id")
#'
#' # Composite (multi-column) level: stepped-wedge cluster-period
#' cf_hierarchy(participant = "pid",
#'              cluster_period = c("cluster_id", "period"),
#'              cluster = "cluster_id")
cf_hierarchy <- function(...) {
  args <- list(...)

  if (is.null(names(args)) || any(!nzchar(names(args)))) {
    rlang::abort("All arguments to `cf_hierarchy()` must be named.")
  }

  if (length(args) == 0L) {
    rlang::abort("`cf_hierarchy()` requires at least one level.")
  }

  if (!all(vapply(args, is.character, logical(1L)))) {
    rlang::abort("All values in `cf_hierarchy()` must be character strings (column names).")
  }

  if (anyDuplicated(names(args))) {
    rlang::abort("Role names in `cf_hierarchy()` must be unique.")
  }

  # A column may legitimately appear in more than one role (e.g. "cluster_id"
  # is both its own level and part of a composite "cluster_period" level), so
  # only reject roles that map to the *exact same set* of column(s).
  role_signatures <- vapply(args, function(v) paste(sort(v), collapse = "\r"), character(1L))
  if (anyDuplicated(role_signatures)) {
    rlang::abort("Each role in `cf_hierarchy()` must map to a distinct set of column(s).")
  }

  structure(args, class = "cf_hierarchy")
}

# ---------------------------------------------------------------------------
# S3 methods

#' @export
`[.cf_hierarchy` <- function(x, i) {
  vals <- unclass(x)[i]
  if (length(vals) == 1L && length(vals[[1L]]) == 1L) {
    return(stats::setNames(vals[[1L]], names(vals)))
  }
  vals
}

#' @export
print.cf_hierarchy <- function(x, ...) {
  cat("Cohort hierarchy (finest \u2192 coarsest):\n")
  for (i in seq_along(x)) {
    arrow <- if (i < length(x)) "  \u251c\u2500 " else "  \u2514\u2500 "
    cols  <- paste(x[[i]], collapse = " + ")
    cat(sprintf("%s%s  \u2192  column: %s\n", arrow, names(x)[i], cols))
  }
  invisible(x)
}

#' @export
format.cf_hierarchy <- function(x, ...) {
  parts <- vapply(seq_along(x), function(i) {
    sprintf("%s = %s", names(x)[i], paste(x[[i]], collapse = " + "))
  }, character(1L))
  paste0("cf_hierarchy(", paste(parts, collapse = ", "), ")")
}

# ---------------------------------------------------------------------------
# Validators

#' Check that a hierarchy is compatible with a data frame
#'
#' @param hierarchy A `cf_hierarchy`.
#' @param data A data frame.
#' @return `hierarchy`, invisibly, if all column names exist; otherwise errors.
#' @keywords internal
validate_hierarchy <- function(hierarchy, data) {
  missing_cols <- setdiff(unlist(hierarchy, use.names = FALSE), names(data))
  if (length(missing_cols) > 0L) {
    rlang::abort(
      paste0(
        "Hierarchy column(s) not found in data: ",
        paste(missing_cols, collapse = ", "), "."
      )
    )
  }
  invisible(hierarchy)
}

# ---------------------------------------------------------------------------
# Per-step, per-level attrition counting

# Computes, for each hierarchy level (finest -> coarsest), the number of
# distinct units at risk/surviving/failing at a single step.
#
# For `include()`/`exclude()`/`select_within()` steps, every level's loss is
# a *primary* exclusion: bottom-up attribution, where a unit counts as
# "excluded at this step" only when it loses its very last row (partial loss
# is not exclusion, so coarse counts are not additive across steps).
#
# For `group_include()`/`group_exclude()` steps, the level matching the
# step's `by` (and any coarser level) is the primary exclusion; any level
# *finer* than `by` records its loss as `n_consequential` instead, since
# those units disappear as a side effect of their group being removed, not
# because they individually failed a criterion (CONSORT's cluster
# extension -- Campbell, Elbourne & Altman, BMJ 2004;328:702-8 -- expects
# cluster-flow and participant-flow to be reported separately).
#
# @keywords internal
.hierarchy_step_counts <- function(before, after, hierarchy, step_type, by) {
  is_group_step <- step_type %in% c("group_include", "group_exclude")

  by_level_idx <- NA_integer_
  if (is_group_step && !is.null(by)) {
    by_sig       <- paste(sort(by), collapse = "\r")
    level_sigs   <- vapply(hierarchy, function(v) paste(sort(v), collapse = "\r"), character(1L))
    by_level_idx <- match(by_sig, level_sigs)
  }

  rows <- lapply(seq_along(hierarchy), function(i) {
    level_cols <- hierarchy[[i]]
    before_ids <- unique(.composite_key(before, level_cols))
    after_ids  <- unique(.composite_key(after, level_cols))
    n_fail_ids <- length(setdiff(before_ids, after_ids))

    consequential <- is_group_step && !is.na(by_level_idx) && i < by_level_idx

    tibble::tibble(
      level           = names(hierarchy)[i],
      n_risk          = length(before_ids),
      n_pass          = length(after_ids),
      n_fail          = if (consequential) 0L else n_fail_ids,
      n_consequential = if (consequential) n_fail_ids else 0L
    )
  })

  do.call(rbind, rows)
}
