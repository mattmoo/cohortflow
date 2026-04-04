#' Create an eligibility criteria pipeline
#'
#' `cf_criteria()` initialises an empty criteria pipeline. Use the pipe
#' operators `include()` and `exclude()` to add steps, and `set_hierarchy()`
#' to attach a nesting structure.
#'
#' @param ... Optional `cf_criterion` objects to include at construction time.
#' @param hierarchy An optional `cf_hierarchy` object.
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
#'   exclude(~ baseline_complete == 0, label = "Missing baseline")
#'
#' crit
cf_criteria <- function(..., hierarchy = NULL) {
  steps <- list(...)

  if (!all(vapply(steps, inherits, logical(1L), "cf_criterion"))) {
    rlang::abort("All `...` arguments to `cf_criteria()` must be `cf_criterion` objects.")
  }

  if (!is.null(hierarchy) && !inherits(hierarchy, "cf_hierarchy")) {
    rlang::abort("`hierarchy` must be a `cf_hierarchy` object or NULL.")
  }

  structure(
    list(
      steps     = steps,
      hierarchy = hierarchy
    ),
    class = "cf_criteria"
  )
}

# ---------------------------------------------------------------------------
# Pipe builders

#' Add an inclusion criterion to a criteria pipeline
#'
#' @param criteria A `cf_criteria` object (or `NULL` to start a new one).
#' @param predicate A one-sided formula or a function (see [cf_criterion()]).
#' @param label A short human-readable description of this criterion.
#'
#' @return The updated `cf_criteria` object.
#' @export
#'
#' @examples
#' cf_criteria() |>
#'   include(~ age >= 18, label = "Adults") |>
#'   include(function(d) d$enrolled == TRUE, label = "Enrolled")
include <- function(criteria, predicate, label) {
  criteria <- .ensure_criteria(criteria)
  crit <- cf_criterion(predicate = predicate, label = label, type = "include")
  criteria$steps <- c(criteria$steps, list(crit))
  criteria
}

#' Add an exclusion criterion to a criteria pipeline
#'
#' @param criteria A `cf_criteria` object (or `NULL` to start a new one).
#' @param predicate A one-sided formula or a function (see [cf_criterion()]).
#' @param label A short human-readable description of this criterion.
#'
#' @return The updated `cf_criteria` object.
#' @export
#'
#' @examples
#' cf_criteria() |>
#'   exclude(~ is.na(age), label = "Missing age") |>
#'   exclude(~ withdrew == TRUE, label = "Withdrew consent")
exclude <- function(criteria, predicate, label) {
  criteria <- .ensure_criteria(criteria)
  crit <- cf_criterion(predicate = predicate, label = label, type = "exclude")
  criteria$steps <- c(criteria$steps, list(crit))
  criteria
}

#' Attach a hierarchy to a criteria pipeline
#'
#' @param criteria A `cf_criteria` object (or `NULL` to start a new one).
#' @param hierarchy A `cf_hierarchy` object.
#'
#' @return The updated `cf_criteria` object.
#' @export
#'
#' @examples
#' cf_criteria() |>
#'   set_hierarchy(cf_hierarchy(participant = "pid", cluster = "cid")) |>
#'   include(~ age >= 18, label = "Adults")
set_hierarchy <- function(criteria, hierarchy) {
  criteria <- .ensure_criteria(criteria)
  if (!inherits(hierarchy, "cf_hierarchy")) {
    rlang::abort("`hierarchy` must be a `cf_hierarchy` object.")
  }
  criteria$hierarchy <- hierarchy
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

  if (!is.null(x$hierarchy)) {
    cat("Hierarchy: ", format(x$hierarchy), "\n", sep = "")
  }

  if (n == 0L) {
    cat("  <empty — use include() / exclude() to add steps>\n")
  } else {
    for (i in seq_along(x$steps)) {
      s <- x$steps[[i]]
      type_sym  <- if (s$type == "include") "+" else "-"
      pred_type <- if (is_formula(s$predicate)) "~" else "f"
      pred_str  <- predicate_label(s$predicate)
      cat(sprintf("  %2d. [%s][%s] %s\n          %s\n",
                  i, type_sym, pred_type, s$label, pred_str))
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
  # Use hierarchy from the first non-NULL hierarchy found
  hier <- NULL
  for (a in args) {
    if (!is.null(a$hierarchy)) { hier <- a$hierarchy; break }
  }
  all_steps <- do.call(c, lapply(args, `[[`, "steps"))
  structure(list(steps = all_steps, hierarchy = hier), class = "cf_criteria")
}
