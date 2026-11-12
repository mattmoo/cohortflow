#' Check that criteria only refer to columns present in the data
#'
#' A pre-flight check run before any step is evaluated. For every step in
#' `criteria`, the variables used by a formula predicate, the `by` column(s)
#' and the `arms` column must exist in `data`. If any are missing,
#' `check_criteria()` aborts with one line per offending step, naming the step
#' number, its label and the missing column(s), instead of letting evaluation
#' fail later with `object 'x' not found`.
#'
#' [apply_criteria()] and [continue_criteria()] call this automatically
#' (after the `expected` / `join` step, so joined columns count as present).
#' Call it directly to validate a criteria set against a dataset without
#' applying it.
#'
#' @section What is checked:
#' Variables in a formula predicate count as present when they are a column of
#' `data`, or when they resolve in the formula's environment (e.g. a local
#' `min_age <- 18` used as `~ age >= min_age`), matching how predicates are
#' evaluated. A consequence is that a missing column whose name matches an
#' object on the search path (e.g. `c` or `t`) is not reported, because
#' evaluation would find that object too. The dplyr helpers `n()`, `n_distinct()`, `cur_group()` and
#' `cur_group_id()` and the `.data` / `.env` pronouns are always allowed;
#' `.data$x` is checked as column `x`. Function names, `pkg::fn` references
#' and the right-hand side of `obj$field` are not treated as columns.
#'
#' Function predicates cannot be inspected statically and are skipped (their
#' `by` / `arms` columns are still checked); the error message notes which
#' steps were skipped.
#'
#' @param criteria A `cf_criteria` object.
#' @param data A data frame.
#'
#' @return `NULL`, invisibly. Called for its side effect of aborting when a
#'   criterion refers to a column not in `data`.
#' @seealso [apply_criteria()], [continue_criteria()].
#' @export
#'
#' @examples
#' dat  <- mock_parallel_rct(n_participants = 50, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ age >= 18, label = "Adults only") |>
#'   include(~ !is.na(consent_date), label = "Consent recorded")
#' check_criteria(crit, dat)   # passes silently
#'
#' # A column that is not in the data is reported with its step
#' bad <- crit |> exclude(~ lost_to_follow_up, label = "Lost to follow-up")
#' try(check_criteria(bad, dat))
check_criteria <- function(criteria, data) {
  if (!inherits(criteria, "cf_criteria")) {
    rlang::abort("`criteria` must be a `cf_criteria` object.")
  }
  if (!is.data.frame(data)) rlang::abort("`data` must be a data frame.")
  .check_criteria(criteria, data)
}

# Worker shared by check_criteria(), apply_criteria() and continue_criteria().
# `step_offset` shifts the reported step numbers so continue_criteria() matches
# the flow's continuous numbering; `hint` adds a final "i" bullet.
.check_criteria <- function(criteria, data, step_offset = 0L, hint = NULL) {
  known   <- c("n", "n_distinct", "cur_group", "cur_group_id", ".data", ".env")
  cols    <- names(data)
  bad     <- character()
  skipped <- integer()

  for (i in seq_along(criteria$steps)) {
    s       <- criteria$steps[[i]]
    step_no <- step_offset + i
    missing <- character()

    if (is_formula(s$predicate)) {
      env  <- environment(s$predicate)
      if (is.null(env)) env <- globalenv()
      vars <- setdiff(.predicate_vars(s$predicate[[2L]]), c(cols, known))
      bound <- vapply(vars, exists, logical(1L), envir = env)
      missing <- vars[!bound]
    } else if (is.function(s$predicate)) {
      skipped <- c(skipped, step_no)
    }

    missing <- unique(c(missing, setdiff(c(s$by, s$arms), cols)))
    if (length(missing) > 0L) {
      bad <- c(bad, sprintf(
        "Criterion %d \"%s\" refers to column(s) not in data: %s.",
        step_no, s$label, paste(missing, collapse = ", ")
      ))
    }
  }

  if (length(bad) == 0L) return(invisible(NULL))

  msg <- c("Criteria refer to column(s) not found in `data`.", stats::setNames(bad, rep("x", length(bad))))
  if (length(skipped) > 0L) {
    msg <- c(msg, i = sprintf(
      "Function predicates (criterion %s) cannot be checked statically and were skipped.",
      paste(skipped, collapse = ", ")
    ))
  }
  if (!is.null(hint)) msg <- c(msg, i = hint)
  rlang::abort(msg)
}

# Free variables of a predicate expression. Unlike all.vars(), this does not
# report `pkg` / `fn` in `pkg::fn`, the field in `obj$field`, or variables
# local to a nested lambda (`~ .x`, `function(a) a`), and it reports `x` for
# the `.data$x` / `.data[["x"]]` pronoun forms. Symbols in call position are
# function names and are skipped, as in all.vars().
.predicate_vars <- function(expr) {
  if (is.symbol(expr)) {
    nm <- as.character(expr)
    return(if (nzchar(nm)) nm else character())  # empty symbol: `x[, 1]`
  }
  if (!is.call(expr)) return(character())

  head <- expr[[1L]]
  if (is.symbol(head)) {
    fn <- as.character(head)
    if (fn %in% c("::", ":::", "~")) return(character())
    if (fn %in% c("$", "@", "[[")) {
      lhs <- expr[[2L]]
      if (identical(lhs, quote(.data))) {
        rhs <- expr[[3L]]
        if (is.symbol(rhs) || (is.character(rhs) && length(rhs) == 1L)) return(as.character(rhs))
      }
      if (identical(lhs, quote(.env))) return(character())
      if (fn != "[[") return(.predicate_vars(lhs))
    }
    if (fn == "function") {
      return(setdiff(.predicate_vars(expr[[3L]]), names(expr[[2L]])))
    }
    args <- as.list(expr)[-1L]
  } else {
    args <- as.list(expr)
  }
  unique(unlist(lapply(args, .predicate_vars), use.names = FALSE))
}
