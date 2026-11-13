#' Create a single cohort criterion
#'
#' A `cf_criterion` represents one inclusion or exclusion step in a cohort
#' eligibility pipeline. Five step types are supported (see `type`). The
#' predicate is always a
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
#'   * For `randomise`: must be `NULL` (a randomise step never removes rows).
#' @param label A short human-readable description of this criterion.
#' @param type One of `"include"`, `"exclude"`, `"group_include"`,
#'   `"group_exclude"`, `"select_within"`, or `"randomise"`.
#' @param by For grouped step types (`group_include`, `group_exclude`,
#'   `select_within`): one or more character strings naming the grouping
#'   column(s); supply more than one for composite (multi-column) grouping.
#'   For `randomise`: one or more character strings naming the
#'   randomisation unit column(s) (e.g. `"cluster_id"`). Must be `NULL` for
#'   the row-wise types (`include`, `exclude`). Rows with an `NA` in any `by`
#'   column cannot be assigned to a group and are always removed by grouped
#'   step types.
#' @param category An optional character string grouping this criterion with
#'   others for display purposes (e.g. `"Valid age"` to group age-related steps
#'   into one box in a CONSORT diagram). `NULL` (default) leaves the step
#'   uncategorised (`NA` in output).
#' @param arms For `type = "randomise"` only: a single character string
#'   naming the column in the data that holds each unit's allocated arm
#'   (e.g. `"arm"`). Used by [as_consort_diagram()]/[as_attrition_tibble()]
#'   to default `branch_by` when not explicitly supplied. Must be `NULL` for
#'   all other types.
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
#'              type = "include", category = "Valid age")
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
#'
#' # Randomisation marker (no predicate; excludes nothing)
#' cf_criterion(
#'   predicate = NULL,
#'   label = "Randomised",
#'   type  = "randomise",
#'   by    = "cluster_id",
#'   arms  = "arm"
#' )
cf_criterion <- function(predicate,
                         label,
                         type = c("include", "exclude",
                                  "group_include", "group_exclude",
                                  "select_within", "randomise"),
                         by       = NULL,
                         category = NULL,
                         arms     = NULL) {
  type <- match.arg(type)

  if (is.null(predicate)) {
    if (type != "randomise") {
      rlang::abort("`predicate` must be a formula or a function.")
    }
  } else if (type == "randomise") {
    rlang::abort("`predicate` must be `NULL` for type \"randomise\".")
  } else if (!is_formula(predicate) && !is.function(predicate)) {
    rlang::abort(c(
      "`predicate` must be a formula or a function.",
      "i" = sprintf("Supplied: <%s>.", paste(class(predicate), collapse = "/"))
    ))
  }

  if (!is.character(label) || length(label) != 1L || is.na(label) || !nzchar(label)) {
    rlang::abort("`label` must be a single non-empty string.")
  }

  if (!is.null(predicate) && is_formula(predicate) && !is_one_sided(predicate)) {
    rlang::abort(c(
      "Formulas must be one-sided (e.g. `~ age >= 18`).",
      "x" = "A two-sided formula was supplied."
    ))
  }

  grouped_types <- c("group_include", "group_exclude", "select_within", "randomise")
  if (type %in% grouped_types) {
    if (is.null(by) || !is.character(by) || length(by) == 0L ||
          anyNA(by) || any(!nzchar(by))) {
      rlang::abort(c(
        sprintf("`by` must be one or more non-empty strings for type \"%s\".", type),
        "i" = "e.g. `by = \"cluster_id\"` or `by = c(\"cluster_id\", \"period\")`."
      ))
    }
  } else if (!is.null(by)) {
    rlang::abort(c(
      sprintf("`by` must be NULL for row-wise type \"%s\".", type),
      "i" = "Use group_include(), group_exclude() or select_within() for grouped steps."
    ))
  }

  if (type == "randomise") {
    if (is.null(arms) || !is.character(arms) || length(arms) != 1L ||
          is.na(arms) || !nzchar(arms)) {
      rlang::abort("`arms` must be a single non-empty string for type \"randomise\".")
    }
  } else if (!is.null(arms)) {
    rlang::abort("`arms` is only used for type \"randomise\".")
  }

  if (!is.null(category)) {
    if (!is.character(category) || length(category) != 1L ||
          is.na(category) || !nzchar(category)) {
      rlang::abort("`category` must be a single non-empty string or NULL.")
    }
  }

  structure(
    list(
      predicate = predicate,
      label     = label,
      type      = type,
      by        = by,
      category  = category,
      arms      = arms
    ),
    class = "cf_criterion"
  )
}

# ---------------------------------------------------------------------------
# Helpers

#' @importFrom rlang .data
NULL

is_formula <- function(x) inherits(x, "formula")

is_one_sided <- function(f) length(f) == 2L

# Pull a tidy string representation of the predicate for printing / YAML
predicate_label <- function(predicate) {
  if (is.null(predicate)) {
    return("<none>")
  }
  if (is_formula(predicate)) {
    paste(deparse(predicate[[2L]], width.cutoff = 60L), collapse = " ")
  } else {
    # Show the function body (collapsed onto one line, truncated). Deparsing
    # the call site via substitute() would only ever show the caller's
    # expression (e.g. `x$predicate`), not the function itself.
    body_str <- paste(trimws(deparse(body(predicate), width.cutoff = 60L)), collapse = " ")
    if (nchar(body_str) > 60L) body_str <- paste0(substr(body_str, 1L, 57L), "...")
    body_str
  }
}

# ---------------------------------------------------------------------------
# S3 methods

#' @export
print.cf_criterion <- function(x, ...) {
  type_sym  <- if (x$type %in% c("include", "group_include")) "+" else
    if (x$type == "select_within") ">" else
      if (x$type == "randomise") "R" else "-"
  pred_str  <- predicate_label(x$predicate)
  pred_type <- if (is.null(x$predicate)) "-" else if (is_formula(x$predicate)) "~" else "f"
  by_str    <- if (!is.null(x$by)) sprintf(" [by: %s]", paste(x$by, collapse = ", ")) else ""
  arms_str  <- if (!is.null(x$arms)) sprintf(" [arms: %s]", x$arms) else ""

  cat(sprintf(
    "[%s][%s] %s%s%s\n    %s\n",
    type_sym, pred_type, x$label, by_str, arms_str, pred_str
  ))
  invisible(x)
}

#' @export
format.cf_criterion <- function(x, ...) {
  type_sym  <- if (x$type %in% c("include", "group_include")) "+" else
    if (x$type == "select_within") ">" else
      if (x$type == "randomise") "R" else "-"
  pred_str  <- predicate_label(x$predicate)
  pred_type <- if (is.null(x$predicate)) "-" else if (is_formula(x$predicate)) "~" else "f"
  by_str    <- if (!is.null(x$by)) sprintf(" [by: %s]", paste(x$by, collapse = ", ")) else ""
  arms_str  <- if (!is.null(x$arms)) sprintf(" [arms: %s]", x$arms) else ""
  sprintf("[%s][%s] %s%s%s  (%s)", type_sym, pred_type, x$label, by_str, arms_str, pred_str)
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
    rlang::abort(c(
      "Criterion predicate must return a logical vector.",
      "x" = sprintf("Criterion \"%s\" returned <%s>.", criterion$label,
                    paste(class(result), collapse = "/"))
    ))
  }
  if (length(result) != nrow(data)) {
    rlang::abort(c(
      sprintf("Criterion predicate must return a vector of length %d (`nrow(data)`).", nrow(data)),
      "x" = sprintf("Criterion \"%s\" returned length %d.", criterion$label, length(result))
    ))
  }
  result
}

#' Evaluate a group-level criterion -- returns a logical vector (nrow(data))
#' @keywords internal
eval_group_criterion <- function(criterion, data) {
  stopifnot(criterion$type %in% c("group_include", "group_exclude"))
  by_col <- criterion$by

  missing_by <- setdiff(by_col, names(data))
  if (length(missing_by) > 0L) {
    rlang::abort(c(
      sprintf("Grouping column(s) %s not found in data.", paste0("`", missing_by, "`", collapse = ", ")),
      "i" = sprintf("Criterion: \"%s\"", criterion$label)
    ))
  }

  if (is_formula(criterion$predicate)) {
    # Evaluate in summarise() context using dplyr
    grp <- dplyr::group_by(data, dplyr::across(dplyr::all_of(by_col)))
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
    summary <- criterion$predicate(dplyr::group_by(data, dplyr::across(dplyr::all_of(by_col))))
    if (!".pass" %in% names(summary)) {
      rlang::abort(c(
        "Function predicate for group criterion must return a data frame with a `.pass` column.",
        "i" = sprintf("Criterion: \"%s\"", criterion$label)
      ))
    }
  }

  by_str <- paste(by_col, collapse = ", ")
  if (!is.logical(summary$.pass)) {
    rlang::abort(c(
      "Group criterion must produce a logical `.pass` value per group.",
      "x" = sprintf("`.pass` is of class <%s>.", paste(class(summary$.pass), collapse = "/")),
      "i" = sprintf("Criterion: \"%s\"", criterion$label)
    ))
  }
  if (!all(by_col %in% names(summary))) {
    rlang::abort(c(
      sprintf("Group criterion result must contain the grouping column(s) `%s`.", by_str),
      "i" = sprintf("Criterion: \"%s\"", criterion$label)
    ))
  }
  summary_key <- as.character(.composite_key(summary, by_col))
  if (anyDuplicated(summary_key)) {
    rlang::abort(c(
      "Group criterion must return exactly one row per group.",
      "x" = sprintf("Duplicate values found in `%s` of the returned summary.", by_str),
      "i" = sprintf("Criterion: \"%s\"", criterion$label)
    ))
  }

  # Broadcast scalar group result back to rows, keyed on the (possibly
  # composite) `by` column(s). Rows with an NA in any `by` column get NA (and
  # so are removed): they cannot be assigned to a group.
  pass_map <- stats::setNames(summary$.pass, summary_key)
  out <- unname(pass_map[as.character(.composite_key(data, by_col))])
  out[!stats::complete.cases(data[by_col])] <- NA
  out
}

#' Evaluate a select_within criterion -- returns a logical vector (nrow(data))
#' @keywords internal
eval_select_criterion <- function(criterion, data) {
  stopifnot(criterion$type == "select_within")
  by_col <- criterion$by

  missing_by <- setdiff(by_col, names(data))
  if (length(missing_by) > 0L) {
    rlang::abort(c(
      sprintf("Grouping column(s) %s not found in data.", paste0("`", missing_by, "`", collapse = ", ")),
      "i" = sprintf("Criterion: \"%s\"", criterion$label)
    ))
  }

  # Split data by group, evaluate predicate within each group,
  # reassemble a logical vector in original row order
  row_idx <- seq_len(nrow(data))
  keep    <- logical(nrow(data))

  # Rows with an NA in any `by` column are never visited, so their `keep`
  # entry stays FALSE: by design, rows that cannot be assigned to a group are
  # always removed by grouped step types. (A pasted composite key is never NA,
  # so this is checked explicitly rather than relying on split() dropping NA.)
  complete <- stats::complete.cases(data[by_col])
  groups   <- split(row_idx[complete], .composite_key(data[complete, , drop = FALSE], by_col),
                    drop = TRUE)

  for (grp_rows in groups) {
    grp_data <- data[grp_rows, , drop = FALSE]

    result <- if (is_formula(criterion$predicate)) {
      eval(criterion$predicate[[2L]], envir = grp_data,
           enclos = environment(criterion$predicate))
    } else {
      criterion$predicate(grp_data)
    }

    if (!is.logical(result) || length(result) != nrow(grp_data)) {
      rlang::abort(c(
        "select_within predicate must return a logical vector of length equal to the group size.",
        "x" = sprintf("A group of %d row(s) returned <%s> of length %d.", nrow(grp_data),
                      paste(class(result), collapse = "/"), length(result)),
        "i" = sprintf("Criterion: \"%s\"", criterion$label)
      ))
    }

    keep[grp_rows] <- result
  }
  keep
}
