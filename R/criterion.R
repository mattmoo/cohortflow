#' Create a single cohort criterion
#'
#' A `cf_criterion` represents one inclusion or exclusion step in a cohort
#' eligibility pipeline.
#' @importFrom rlang .data
#' Five step types are supported (see `type`). The predicate is always a
#' one-sided **formula** or a **function**; the interpretation depends on
#' the step type.
#'
#' @param predicate A one-sided formula or a function.
#'   * For `include` / `exclude`: evaluated row-wise; must return a logical
#'     vector of length `nrow(data)`.
#'   * For `group_include` / `group_exclude`: evaluated in a
#'     `dplyr::summarise()` context per group (defined by `by`); must return a
#'     scalar logical. The result is broadcast back to all rows in each group.
#'   * For `select_within`: evaluated per group; must return a logical vector
#'     identifying which rows within the group to keep.
#' @param label A short human-readable description of this criterion.
#' @param type One of `"include"`, `"exclude"`, `"group_include"`,
#'   `"group_exclude"`, or `"select_within"`.
#' @param by For grouped step types (`group_include`, `group_exclude`,
#'   `select_within`): a single character string naming the grouping column.
#'   Ignored for row-wise types.
#' @param category An optional character string grouping this criterion with
#'   others for display purposes (e.g. `"Age"` to group age-related steps into
#'   one box in a CONSORT diagram). `NULL` (default) leaves the step
#'   uncategorised (`NA` in output).
#'
#' @return A `cf_criterion` object (an S3 list).
#' @export
#'
#' @examples
#' # Row-wise inclusion
#' cf_criterion(~ age >= 18, label = "Adults only", type = "include")
#'
#' # Grouped under a category
#' cf_criterion(~ !is.na(age), label = "Age recorded",
#'              type = "include", category = "Age")
#'
#' # Group-level inclusion (clusters with >= 5 participants)
#' cf_criterion(
#'   ~ n() >= 5,
#'   label = "Sufficient cluster size",
#'   type  = "group_include",
#'   by    = "cluster_id"
#' )
#'
#' # Select first operation per patient
#' cf_criterion(
#'   ~ consent_date == min(consent_date, na.rm = TRUE),
#'   label = "Index operation",
#'   type  = "select_within",
#'   by    = "participant_id"
#' )
cf_criterion <- function(predicate,
                         label,
                         type = c("include", "exclude",
                                  "group_include", "group_exclude",
                                  "select_within"),
                         by       = NULL,
                         category = NULL) {
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

  grouped_types <- c("group_include", "group_exclude", "select_within")
  if (type %in% grouped_types) {
    if (is.null(by) || !is.character(by) || length(by) != 1L || !nzchar(by)) {
      cli_abort(
        c(
          "{.arg by} must be a single non-empty string for type {.val {type}}.",
          "i" = "e.g. {.code by = \"cluster_id\"}"
        )
      )
    }
  }

  if (!is.null(category)) {
    if (!is.character(category) || length(category) != 1L ||
          is.na(category) || !nzchar(category)) {
      cli_abort("{.arg category} must be a single non-empty string or NULL.")
    }
  }

  structure(
    list(
      predicate = predicate,
      label     = label,
      type      = type,
      by        = by,
      category  = category
    ),
    class = "cf_criterion"
  )
}

# ---------------------------------------------------------------------------
# Helpers

is_formula <- function(x) inherits(x, "formula")

is_one_sided <- function(f) length(f) == 2L

# Pull a tidy string representation of the predicate for printing / YAML
predicate_label <- function(predicate) {
  if (is_formula(predicate)) {
    paste(deparse(predicate[[2L]], width.cutoff = 60L), collapse = " ")
  } else {
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
  type_sym  <- if (x$type %in% c("include", "group_include")) "+" else
    if (x$type == "select_within") ">" else "-"
  pred_str  <- predicate_label(x$predicate)
  pred_type <- if (is_formula(x$predicate)) "~" else "f"
  by_str    <- if (!is.null(x$by)) sprintf(" [by: %s]", x$by) else ""

  cat(sprintf(
    "[%s][%s] %s%s\n    %s\n",
    type_sym, pred_type, x$label, by_str, pred_str
  ))
  invisible(x)
}

#' @export
format.cf_criterion <- function(x, ...) {
  type_sym  <- if (x$type %in% c("include", "group_include")) "+" else
    if (x$type == "select_within") ">" else "-"
  pred_str  <- predicate_label(x$predicate)
  pred_type <- if (is_formula(x$predicate)) "~" else "f"
  by_str    <- if (!is.null(x$by)) sprintf(" [by: %s]", x$by) else ""
  sprintf("[%s][%s] %s%s  (%s)", type_sym, pred_type, x$label, by_str, pred_str)
}

# ---------------------------------------------------------------------------
# Evaluation

#' Evaluate a row-wise criterion against a data frame
#' @keywords internal
eval_criterion <- function(criterion, data) {
  stopifnot(inherits(criterion, "cf_criterion"), is.data.frame(data))

  result <- if (is_formula(criterion$predicate)) {
    eval(criterion$predicate[[2L]], envir = data,
         enclos = environment(criterion$predicate))
  } else {
    criterion$predicate(data)
  }

  if (!is.logical(result)) {
    cli_abort(c(
      "Criterion predicate must return a logical vector.",
      "x" = "Criterion {.val {criterion$label}} returned {.cls {class(result)}}."
    ))
  }
  if (length(result) != nrow(data)) {
    cli_abort(c(
      "Criterion predicate must return a vector of length {nrow(data)}.",
      "x" = "Criterion {.val {criterion$label}} returned length {length(result)}."
    ))
  }
  result
}

#' Evaluate a group-level criterion — returns a logical vector (nrow(data))
#' @keywords internal
eval_group_criterion <- function(criterion, data) {
  stopifnot(criterion$type %in% c("group_include", "group_exclude"))
  by_col <- criterion$by

  if (!by_col %in% names(data)) {
    cli_abort(c(
      "Grouping column {.val {by_col}} not found in data.",
      "i" = "Criterion: {.val {criterion$label}}"
    ))
  }

  if (is_formula(criterion$predicate)) {
    # Evaluate in summarise() context using dplyr
    grp <- dplyr::group_by(data, .data[[by_col]])
    # while preserving the formula's own enclosing environment for user bindings.
    pred_env <- new.env(parent = environment(criterion$predicate))
    pred_env$n           <- dplyr::n
    pred_env$n_distinct  <- dplyr::n_distinct
    pred_env$cur_group   <- dplyr::cur_group
    pred_env$cur_group_id <- dplyr::cur_group_id
    quo <- rlang::new_quosure(criterion$predicate[[2L]], env = pred_env)
    summary <- dplyr::summarise(grp, .pass = !!quo, .groups = "drop")
  } else {
    # Function receives the grouped data frame; must return a 1-row-per-group
    # tibble with columns: <by_col>, .pass
    summary <- criterion$predicate(dplyr::group_by(data, .data[[by_col]]))
    if (!".pass" %in% names(summary)) {
      cli_abort(c(
        "Function predicate for group criterion must return a data frame with a `.pass` column.",
        "i" = "Criterion: {.val {criterion$label}}"
      ))
    }
  }

  # Broadcast scalar group result back to rows
  pass_map <- stats::setNames(summary$.pass, summary[[by_col]])
  pass_map[as.character(data[[by_col]])]
}

#' Evaluate a select_within criterion — returns a logical vector (nrow(data))
#' @keywords internal
eval_select_criterion <- function(criterion, data) {
  stopifnot(criterion$type == "select_within")
  by_col <- criterion$by

  if (!by_col %in% names(data)) {
    cli_abort(c(
      "Grouping column {.val {by_col}} not found in data.",
      "i" = "Criterion: {.val {criterion$label}}"
    ))
  }

  # Split data by group, evaluate predicate within each group,
  # reassemble a logical vector in original row order
  row_idx <- seq_len(nrow(data))
  keep    <- logical(nrow(data))

  groups <- split(row_idx, data[[by_col]])

  for (grp_rows in groups) {
    grp_data <- data[grp_rows, , drop = FALSE]

    result <- if (is_formula(criterion$predicate)) {
      eval(criterion$predicate[[2L]], envir = grp_data,
           enclos = environment(criterion$predicate))
    } else {
      criterion$predicate(grp_data)
    }

    if (!is.logical(result) || length(result) != nrow(grp_data)) {
      cli_abort(c(
        "select_within predicate must return a logical vector of length equal to the group size.",
        "i" = "Criterion: {.val {criterion$label}}"
      ))
    }

    keep[grp_rows] <- result
  }
  keep
}

# Quiet bindings for cli helpers -------------------------------------------
cli_abort <- function(...) rlang::abort(...)
cli_green <- function(x) x
cli_red   <- function(x) x
