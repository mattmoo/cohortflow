#' Create an eligibility criteria pipeline
#'
#' `cf_criteria()` initialises an empty criteria pipeline. Use the pipe
#' operators `include()`, `exclude()`, `group_include()`, `group_exclude()`,
#' and `select_within()` to add steps.
#'
#' @param ... Optional `cf_criterion` objects to include at construction time.
#'
#' @return A `cf_criteria` object.
#' @export
#'
#' @examples
#' has_consent <- function(d) !is.na(d$consent_date)
#'
#' crit <- cf_criteria() |>
#'   include(~ age >= 18, label = "Adults only") |>
#'   include(has_consent, label = "Consent recorded") |>
#'   exclude(~ withdrew, label = "Withdrew consent") |>
#'   group_include(by = "cluster_id", ~ n() >= 5, label = "Cluster size >= 5") |>
#'   select_within(by = "participant_id", ~ consent_date == min(consent_date, na.rm = TRUE),
#'                 label = "Index operation")
#'
#' crit
cf_criteria <- function(...) {
  steps <- list(...)

  if (!all(vapply(steps, inherits, logical(1L), "cf_criterion"))) {
    rlang::abort("All `...` arguments to `cf_criteria()` must be `cf_criterion` objects.")
  }

  structure(
    list(steps = steps),
    class = "cf_criteria"
  )
}

# ---------------------------------------------------------------------------
# Pipe builders

#' Add an inclusion criterion to a criteria pipeline
#'
#' @param criteria A `cf_criteria` object (or `NULL` to start a new one).
#' @param predicate A one-sided formula or a function evaluated row-wise.
#' @param label A short human-readable description of this criterion.
#' @param category An optional string grouping this step with others for
#'   display (e.g. `"Age"`). `NULL` leaves it uncategorised.
#'
#' @return The updated `cf_criteria` object.
#' @export
#'
#' @examples
#' cf_criteria() |>
#'   include(~ age >= 18, label = "Adults", category = "Age")
include <- function(criteria, predicate, label, category = NULL) {
  criteria <- .ensure_criteria(criteria)
  crit <- cf_criterion(predicate = predicate, label = label,
                       type = "include", category = category)
  criteria$steps <- c(criteria$steps, list(crit))
  criteria
}

#' Add an exclusion criterion to a criteria pipeline
#'
#' @param criteria A `cf_criteria` object (or `NULL` to start a new one).
#' @param predicate A one-sided formula or a function evaluated row-wise.
#' @param label A short human-readable description of this criterion.
#' @param category An optional string grouping this step with others for
#'   display. `NULL` leaves it uncategorised.
#'
#' @return The updated `cf_criteria` object.
#' @export
#'
#' @examples
#' cf_criteria() |>
#'   exclude(~ withdrew, label = "Withdrew consent")
exclude <- function(criteria, predicate, label, category = NULL) {
  criteria <- .ensure_criteria(criteria)
  crit <- cf_criterion(predicate = predicate, label = label,
                       type = "exclude", category = category)
  criteria$steps <- c(criteria$steps, list(crit))
  criteria
}

#' Add a group-level inclusion criterion
#'
#' The predicate is evaluated in a `dplyr::summarise()` context per group
#' (when a formula) or receives a grouped data frame (when a function). Groups
#' where the predicate returns `TRUE` are kept; all rows in failing groups are
#' removed.
#'
#' @param criteria A `cf_criteria` object (or `NULL` to start a new one).
#' @param by A single column name (string) to group by.
#' @param predicate A one-sided formula using summary functions (`n()`,
#'   `mean()`, `n_distinct()`, etc.) or a function that receives a grouped
#'   data frame and returns a tibble with columns `<by>` and `.pass`.
#' @param label A short human-readable description of this criterion.
#' @param category An optional string grouping this step with others for
#'   display. `NULL` leaves it uncategorised.
#'
#' @return The updated `cf_criteria` object.
#' @export
#'
#' @examples
#' cf_criteria() |>
#'   group_include(by = "cluster_id", ~ n() >= 5, label = "Cluster size >= 5")
group_include <- function(criteria, by, predicate, label, category = NULL) {
  criteria <- .ensure_criteria(criteria)
  crit <- cf_criterion(predicate = predicate, label = label,
                       type = "group_include", by = by, category = category)
  criteria$steps <- c(criteria$steps, list(crit))
  criteria
}

#' Add a group-level exclusion criterion
#'
#' The predicate is evaluated per group; groups where the predicate returns
#' `TRUE` are removed (all their rows dropped).
#'
#' @param criteria A `cf_criteria` object (or `NULL` to start a new one).
#' @param by A single column name (string) to group by.
#' @param predicate A one-sided formula using summary functions, or a function.
#' @param label A short human-readable description of this criterion.
#' @param category An optional string grouping this step with others for
#'   display. `NULL` leaves it uncategorised.
#'
#' @return The updated `cf_criteria` object.
#' @export
#'
#' @examples
#' cf_criteria() |>
#'   group_exclude(by = "cluster_id", ~ mean(is.na(age)) > 0.5,
#'                 label = "Excessive missing age in cluster")
group_exclude <- function(criteria, by, predicate, label, category = NULL) {
  criteria <- .ensure_criteria(criteria)
  crit <- cf_criterion(predicate = predicate, label = label,
                       type = "group_exclude", by = by, category = category)
  criteria$steps <- c(criteria$steps, list(crit))
  criteria
}

#' Select rows within groups
#'
#' The predicate is evaluated separately within each group defined by `by` and
#' must return a logical vector the same length as the group. Rows where the
#' predicate is `FALSE` are dropped and recorded in the excluded rows store.
#' This is the natural way to select one (or more) records per unit, e.g. the
#' index operation per patient.
#'
#' @param criteria A `cf_criteria` object (or `NULL` to start a new one).
#' @param by A single column name (string) defining the grouping (e.g.
#'   `"participant_id"`).
#' @param predicate A one-sided formula evaluated within each group, or a
#'   function that receives a group's rows as a data frame and returns a
#'   logical vector.
#' @param label A short human-readable description of this step.
#' @param category An optional string grouping this step with others for
#'   display. `NULL` leaves it uncategorised.
#'
#' @return The updated `cf_criteria` object.
#' @export
#'
#' @examples
#' cf_criteria() |>
#'   select_within(by = "participant_id",
#'                 ~ consent_date == min(consent_date, na.rm = TRUE),
#'                 label = "Index operation per patient")
select_within <- function(criteria, by, predicate, label, category = NULL) {
  criteria <- .ensure_criteria(criteria)
  crit <- cf_criterion(predicate = predicate, label = label,
                       type = "select_within", by = by, category = category)
  criteria$steps <- c(criteria$steps, list(crit))
  criteria
}

# ---------------------------------------------------------------------------
# Internal helpers

.ensure_criteria <- function(x) {
  if (is.null(x)) return(cf_criteria())
  if (!inherits(x, "cf_criteria")) {
    rlang::abort("First argument must be a `cf_criteria` object or NULL.")
  }
  x
}

# ---------------------------------------------------------------------------
# S3 methods

#' @export
print.cf_criteria <- function(x, ...) {
  n <- length(x$steps)
  cat(sprintf("Cohort criteria pipeline  (%d step%s)\n", n, if (n == 1) "" else "s"))

  if (n == 0L) {
    cat("  <empty -- use include() / exclude() / group_include() etc. to add steps>\n")
  } else {
    for (i in seq_along(x$steps)) {
      s <- x$steps[[i]]
      type_sym <- switch(s$type,
        include        = "+",
        exclude        = "-",
        group_include  = "+",
        group_exclude  = "-",
        select_within  = ">"
      )
      pred_type  <- if (is_formula(s$predicate)) "~" else "f"
      pred_str   <- predicate_label(s$predicate)
      by_str     <- if (!is.null(s$by))       sprintf(" [by: %s]",  s$by)      else ""
      cat_str    <- if (!is.null(s$category)) sprintf(" {%s}",      s$category) else ""
      type_label <- s$type
      cat(sprintf("  %2d. [%s][%s] (%s)%s%s %s\n          %s\n",
                  i, type_sym, pred_type, type_label, by_str, cat_str,
                  s$label, pred_str))
    }
  }
  invisible(x)
}

#' @export
format.cf_criteria <- function(x, ...) {
  n <- length(x$steps)
  sprintf("<cf_criteria: %d step%s>", n, if (n == 1) "" else "s")
}

#' @export
length.cf_criteria <- function(x) length(x$steps)

#' @export
`[.cf_criteria` <- function(x, i) {
  x$steps <- x$steps[i]
  x
}

#' @export
c.cf_criteria <- function(...) {
  args <- list(...)
  if (!all(vapply(args, inherits, logical(1L), "cf_criteria"))) {
    rlang::abort("All arguments to `c()` must be `cf_criteria` objects.")
  }
  all_steps <- do.call(c, lapply(args, `[[`, "steps"))
  structure(list(steps = all_steps), class = "cf_criteria")
}
