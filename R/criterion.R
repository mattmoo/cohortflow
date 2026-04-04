#' Create a single cohort criterion
#'
#' A `cf_criterion` represents one inclusion or exclusion step in a cohort
#' eligibility pipeline. The predicate can be supplied as:
#'
#' * A **formula** whose RHS is evaluated against each row of the data and
#'   must return a logical vector (`~ age >= 18`).
#' * A **function** that accepts a data frame and returns a logical vector of
#'   the same length as the number of rows (`function(d) d$age >= 18`).
#'   Functions may also return a data frame (for aggregate/cluster-level
#'   predicates) — see Details.
#'
#' @param predicate A one-sided formula or a function.
#' @param label A short human-readable description of this criterion. Used in
#'   output tables and CONSORT diagrams.
#' @param type `"include"` or `"exclude"`. Determines how the logical vector
#'   produced by `predicate` is interpreted: `include` keeps rows where the
#'   predicate is `TRUE`; `exclude` drops rows where it is `TRUE`.
#'
#' @details
#' **Row-wise vs. aggregate predicates**
#'
#' For simple row-wise filters (e.g., `~ age >= 18`), the predicate is
#' evaluated with the data frame as the enclosing environment and must return a
#' logical vector of length `nrow(data)`.
#'
#' For aggregate predicates — e.g., "cluster must have ≥ 5 consenting
#' participants" — supply a function that returns a named logical vector (names
#' = row indices or a column of row identifiers) or a single-column data frame.
#' The function receives the *current* data (after previous criteria have been
#' applied).
#'
#' **Formula shorthand**
#'
#' One-sided formulas (`~ expr`) are evaluated as if the RHS is wrapped in
#' `with(data, expr)`, so column names are available without `$`.
#'
#' @return A `cf_criterion` object (an S3 list).
#' @export
#'
#' @examples
#' # Formula predicate
#' cf_criterion(~ age >= 18, label = "Adults only", type = "include")
#'
#' # Function predicate
#' cf_criterion(
#'   function(d) !is.na(d$consent_date),
#'   label = "Consent recorded",
#'   type = "include"
#' )
cf_criterion <- function(predicate, label, type = c("include", "exclude")) {
  type <- match.arg(type)

  if (!is_formula(predicate) && !is.function(predicate)) {
    cli_abort(
      c(
        "{.arg predicate} must be a formula or a function.",
        "i" = "Supplied: {.cls {class(predicate)}}."
      )
    )
  }

  if (!is.character(label) || length(label) != 1L || is.na(label) || !nzchar(label)) {
    cli_abort("{.arg label} must be a single non-empty string.")
  }

  if (is_formula(predicate) && !is_one_sided(predicate)) {
    cli_abort(
      c(
        "Formulas must be one-sided (e.g. {.code ~ age >= 18}).",
        "x" = "A two-sided formula was supplied."
      )
    )
  }

  structure(
    list(
      predicate = predicate,
      label     = label,
      type      = type
    ),
    class = "cf_criterion"
  )
}

# ---------------------------------------------------------------------------
# Helpers

is_formula <- function(x) inherits(x, "formula")

is_one_sided <- function(f) {
  # A one-sided formula has length 2: . ~ rhs  → c(`~`, rhs)
  # A two-sided formula has length 3: lhs ~ rhs → c(`~`, lhs, rhs)
  length(f) == 2L
}

# Pull a tidy string representation of the predicate for printing / YAML
predicate_label <- function(predicate) {
  if (is_formula(predicate)) {
    paste(deparse(predicate[[2L]], width.cutoff = 60L), collapse = " ")
  } else {
    # functions: try to get the name from the enclosing env, else show body
    fn_name <- tryCatch(
      deparse(substitute(predicate)),
      error = function(e) NULL
    )
    if (!is.null(fn_name) && nzchar(fn_name) && fn_name != "predicate") {
      fn_name
    } else {
      paste(deparse(body(predicate), width.cutoff = 60L), collapse = " ")
    }
  }
}

# ---------------------------------------------------------------------------
# S3 methods

#' @export
print.cf_criterion <- function(x, ...) {
  type_sym  <- if (x$type == "include") cli_green("\u2714") else cli_red("\u2718")
  pred_str  <- predicate_label(x$predicate)
  pred_type <- if (is_formula(x$predicate)) "formula" else "function"

  cat(sprintf(
    "%s [%s] %s  (%s: %s)\n",
    type_sym, x$type, x$label, pred_type, pred_str
  ))
  invisible(x)
}

#' @export
format.cf_criterion <- function(x, ...) {
  type_sym  <- if (x$type == "include") "\u2714" else "\u2718"
  pred_str  <- predicate_label(x$predicate)
  pred_type <- if (is_formula(x$predicate)) "formula" else "function"
  sprintf(
    "%s [%s] %s  (%s: %s)",
    type_sym, x$type, x$label, pred_type, pred_str
  )
}

# ---------------------------------------------------------------------------
# Evaluation

#' Evaluate a criterion against a data frame
#'
#' Internal helper used by `apply_criteria()`. Returns a logical vector of
#' length `nrow(data)` indicating which rows satisfy the criterion's predicate
#' (before accounting for include/exclude direction).
#'
#' @param criterion A `cf_criterion`.
#' @param data A data frame.
#' @return A logical vector of length `nrow(data)`.
#' @keywords internal
eval_criterion <- function(criterion, data) {
  stopifnot(inherits(criterion, "cf_criterion"), is.data.frame(data))

  result <- if (is_formula(criterion$predicate)) {
    eval(criterion$predicate[[2L]], envir = data, enclos = environment(criterion$predicate))
  } else {
    criterion$predicate(data)
  }

  if (!is.logical(result)) {
    cli_abort(
      c(
        "Criterion predicate must return a logical vector.",
        "x" = "Criterion {.val {criterion$label}} returned {.cls {class(result)}}."
      )
    )
  }
  if (length(result) != nrow(data)) {
    cli_abort(
      c(
        "Criterion predicate must return a vector of length {nrow(data)}.",
        "x" = "Criterion {.val {criterion$label}} returned length {length(result)}."
      )
    )
  }
  result
}

# Quiet bindings for cli helpers used without importing the full package ------
cli_abort  <- function(...) rlang::abort(...)
cli_green  <- function(x) x   # plain fallback; replace with cli if added
cli_red    <- function(x) x
