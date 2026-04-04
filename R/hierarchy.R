#' Declare the nesting hierarchy for a cohort
#'
#' A `cf_hierarchy` describes how observational units are nested within each
#' other (e.g., participants within clusters within sites). It is an ordered
#' named character vector mapping role names to column names in the data.
#'
#' The order of `...` is from the **finest** (innermost) level to the
#' **coarsest** (outermost) level. The first role is conventionally the
#' individual participant.
#'
#' @param ... Named character scalars mapping role labels to column names,
#'   e.g. `participant = "participant_id", cluster = "cluster_id"`. At least
#'   one entry is required.
#'
#' @return A `cf_hierarchy` object (a named character vector with additional
#'   class attribute).
#' @export
#'
#' @examples
#' # Two-level: participants within clusters
#' cf_hierarchy(participant = "pid", cluster = "cid")
#'
#' # Three-level: participants within clusters within sites
#' cf_hierarchy(participant = "pid", cluster = "cluster_id", site = "site_id")
cf_hierarchy <- function(...) {
  args <- c(...)  # named character vector after c() coercion

  if (is.null(names(args)) || any(!nzchar(names(args)))) {
    rlang::abort("All arguments to `cf_hierarchy()` must be named.")
  }

  if (any(!is.character(args))) {
    rlang::abort("All values in `cf_hierarchy()` must be character strings (column names).")
  }

  if (length(args) == 0L) {
    rlang::abort("`cf_hierarchy()` requires at least one level.")
  }

  if (anyDuplicated(names(args))) {
    rlang::abort("Role names in `cf_hierarchy()` must be unique.")
  }

  if (anyDuplicated(unname(args))) {
    rlang::abort("Column names in `cf_hierarchy()` must be unique.")
  }

  structure(args, class = "cf_hierarchy")
}

# ---------------------------------------------------------------------------
# S3 methods

#' @export
print.cf_hierarchy <- function(x, ...) {
  cat("Cohort hierarchy (finest \u2192 coarsest):\n")
  for (i in seq_along(x)) {
    arrow <- if (i < length(x)) "  \u251c\u2500 " else "  \u2514\u2500 "
    cat(sprintf("%s%s  \u2192  column: %s\n", arrow, names(x)[i], x[i]))
  }
  invisible(x)
}

#' @export
format.cf_hierarchy <- function(x, ...) {
  parts <- paste(names(x), x, sep = " = ")
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
  missing_cols <- setdiff(unname(hierarchy), names(data))
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
