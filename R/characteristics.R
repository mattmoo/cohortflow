# ===========================================================================
# Step-wise characteristics table
# ===========================================================================
#
# A baseline-characteristics ("Table 1") table whose columns follow the
# attrition cascade: one column per step, each describing the cohort that
# survives up to and including that step (or, with `excluded = TRUE`, the
# rows removed at that step). Every column comes from `cohort()` /
# `excluded()`, so step semantics are shared with the rest of the package
# rather than re-derived here.

# ---------------------------------------------------------------------------
# stack_cohorts() -- per-step cohorts stacked long
# ---------------------------------------------------------------------------

#' Stack the cohort at each step into one data frame
#'
#' Returns the rows of the cohort surviving each step (or, with
#' `excluded = TRUE`, the rows removed at each step), stacked with a `step`
#' factor and a `step_number` column in front of the original columns. A row
#' that survives several steps appears once per step. This is the input shape
#' summary-table packages expect, e.g.
#' `gtsummary::tbl_summary(stack_cohorts(flow), by = step, include = c(age, sex))`;
#' [as_characteristics_tibble()] is the dependency-light equivalent.
#'
#' @inheritSection as_characteristics_tibble Steps
#' @inheritSection as_characteristics_tibble Hierarchy levels
#'
#' @inheritParams as_characteristics_tibble
#' @return A tibble: `step_number` (integer), `step` (factor whose levels are
#'   the step headings in column order), then the data columns. With `level`,
#'   only the level's key column(s) and the columns constant within every
#'   unit of that level are kept.
#' @seealso [as_characteristics_tibble()], [cohort()], [excluded()].
#' @examples
#' dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ age >= 18, label = "Adults only") |>
#'   include(~ eligible_screen, label = "Passed screening") |>
#'   exclude(~ withdrew, label = "Withdrew consent")
#' flow <- apply_criteria(dat, crit, id = "participant_id")
#' stacked <- stack_cohorts(flow)
#' table(stacked$step)
#' @export
stack_cohorts <- function(flow,
                          steps = NULL,
                          excluded = FALSE,
                          level = NULL,
                          drop_randomise = TRUE,
                          assessed_label = "Assessed for eligibility") {
  if (!inherits(flow, "cf_flow")) rlang::abort("`flow` must be a `cf_flow` object.")
  if (!rlang::is_bool(excluded)) rlang::abort("`excluded` must be `TRUE` or `FALSE`.")
  if (!rlang::is_bool(drop_randomise)) rlang::abort("`drop_randomise` must be `TRUE` or `FALSE`.")
  .check_string(assessed_label, "assessed_label")

  ks         <- .resolve_steps(flow, steps, excluded, drop_randomise)
  headings   <- .step_headings(flow, ks, assessed_label)
  level_cols <- .check_level(flow, level)
  keep <- if (is.null(level_cols)) {
    setdiff(names(flow$data), ".cf_row_id")
  } else {
    c(level_cols, .level_constant_cols(flow$data, level_cols))
  }

  chunks <- lapply(seq_along(ks), function(i) {
    d <- .step_rows(flow, ks[i], removed = excluded, level_cols = level_cols, keep = keep)
    d$step_number <- rep(ks[i], nrow(d))
    d$step        <- rep(headings[i], nrow(d))
    d
  })
  out <- dplyr::bind_rows(chunks)
  out$step <- factor(out$step, levels = headings)
  tibble::as_tibble(out[c("step_number", "step", keep)])
}

# ---------------------------------------------------------------------------
# as_characteristics_tibble() -- plain data layer
# ---------------------------------------------------------------------------

#' Characteristics of the cohort at each step
#'
#' Summarises chosen variables (demographics, baseline measures) for the
#' cohort at each step of a flow: a baseline-characteristics ("Table 1")
#' table with one column per step, each describing the rows surviving up to
#' and including that step. `as_characteristics_tibble()` is the data layer;
#' [as_characteristics_table()] renders it; [stack_cohorts()] gives the
#' per-step rows themselves for other summary-table packages.
#'
#' @section Steps:
#' By default there is one column per step from `0` (the starting data) to
#' the last step, omitting `randomise()` steps (see `drop_randomise`). Column
#' `k` holds `cohort(flow, step_number = k)`: the rows that passed steps `1`
#' to `k`. `steps` restricts or reorders the columns. Each element is resolved
#' like `at` in [cohort()]: a number is a step number (`0` = starting data); a
#' string is a step label if one matches, else a category, meaning its last
#' step. Steps named in `steps` are never dropped, even `randomise()` steps.
#'
#' With `excluded = TRUE`, column `k` instead holds the rows removed *at*
#' step `k` (those of [excluded()] with `cf_step == k`): the usual
#' supplementary table of excluded participants' characteristics. Step `0`
#' removes nothing and cannot be selected.
#'
#' A column's heading is the step label, or `assessed_label` for step `0`.
#' Repeated headings are made unique with `" #<n>"`.
#'
#' @section Summaries:
#' How a variable is summarised depends on its type:
#'
#' * **numeric**: a `"Mean (SD)"` row and/or a `"Median [IQR]"` row (shown
#'   as median \[Q1, Q3\]), chosen with `numeric`.
#' * **factor**: one row per level of the factor, in level order, whether or
#'   not the level occurs; `n (%)` of the non-missing values.
#' * **character**: as a factor whose levels are the distinct values in the
#'   starting data, sorted.
#' * **logical**: a single row (`level` is `NA`) counting `TRUE`; `n (%)` of
#'   the non-missing values.
#'
#' Each variable also gets a `missing_label` row counting `NA` values, as a
#' percentage of the column's `n`; `missing` controls when it appears. Dates
#' and other types are not summarised: convert them first.
#'
#' @section Hierarchy levels:
#' When the flow was built with `apply_criteria(hierarchy = )`, rows are
#' summarised unless `level` names one of the hierarchy's levels, in which
#' case each unit at that level (each distinct, complete key) contributes
#' once and `n` counts units. A row with an `NA` in the level's key is not a
#' unit. Every variable must then be constant within each unit across the
#' starting data; a variable that varies within a unit is an error, since
#' there is no single value to summarise.
#'
#' @param flow A `cf_flow` object produced by [apply_criteria()].
#' @param vars Character vector of column names to summarise.
#' @param steps Optional step selectors (a vector or list); see the section
#'   "Steps". `NULL` (default) means every step.
#' @param excluded Logical. `FALSE` (default) describes the cohort surviving
#'   each step; `TRUE` describes the rows removed at each step.
#' @param level Optional hierarchy level name at which to count units; see
#'   the section "Hierarchy levels". Requires a flow built with a hierarchy.
#' @param numeric How to summarise numeric variables: `"mean_sd"` (default),
#'   `"median_iqr"`, or both.
#' @param missing When to include the row counting `NA` values per variable:
#'   `"ifany"` (default) if any column has one, `"always"`, or `"never"`.
#' @param digits Decimal places for means, SDs, medians, quartiles and
#'   percentages. Default `1`.
#' @param drop_randomise Logical. Omit `randomise()` steps when `steps` is
#'   `NULL` (default `TRUE`).
#' @param assessed_label Heading for step `0`, the starting data. Default
#'   `"Assessed for eligibility"`.
#' @param missing_label Label of the row counting `NA` values. Default
#'   `"Missing"`.
#' @param wide Logical. `FALSE` (default) returns the long form; `TRUE`
#'   pivots the columns to one per step for display.
#'
#' @return With `wide = FALSE`, a tibble with one row per variable, summary
#'   row and step, ordered by variable (in `vars` order), then summary row,
#'   then step column:
#' \describe{
#'   \item{`variable`}{Column name}
#'   \item{`level`}{Factor level, `"Mean (SD)"`, `"Median [IQR]"`,
#'     `missing_label`, or `NA` for a logical variable's single row}
#'   \item{`step`}{Step number (`0` = starting data)}
#'   \item{`label`}{Step heading}
#'   \item{`n`}{Rows (or units, with `level`) in that step's column}
#'   \item{`count`}{Rows in the level, or missing; `NA` for numeric
#'     summaries}
#'   \item{`pct`}{`count` as a percentage of the non-missing values (of `n`
#'     for the missing row); `NA` where the denominator is zero}
#'   \item{`stat`}{Display text: `"12 (6.0%)"`, `"45.2 (14.8)"`,
#'     `"45.0 [35.0, 56.0]"`; `NA` when there is nothing to summarise}
#' }
#' With `wide = TRUE`, `variable` and `level` followed by one character column
#' per step, named `"<heading> (n = <n>)"`, holding `stat`.
#' @seealso [as_characteristics_table()] for a formatted table,
#'   [stack_cohorts()] for the per-step rows, [as_attrition_tibble()] for
#'   the attrition counts themselves.
#' @examples
#' dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ age >= 18, label = "Adults only") |>
#'   include(~ eligible_screen, label = "Passed screening") |>
#'   exclude(~ withdrew, label = "Withdrew consent")
#' flow <- apply_criteria(dat, crit, id = "participant_id")
#'
#' as_characteristics_tibble(flow, vars = c("age", "sex"))
#' as_characteristics_tibble(flow, vars = c("age", "sex"), wide = TRUE)
#'
#' # Who was removed at each step?
#' as_characteristics_tibble(flow, vars = "age", excluded = TRUE, wide = TRUE)
#'
#' # Only the starting data and the final cohort, with both numeric summaries
#' as_characteristics_tibble(flow, vars = "age", steps = c(0, 3),
#'                           numeric = c("mean_sd", "median_iqr"), wide = TRUE)
#' @export
as_characteristics_tibble <- function(flow,
                                      vars,
                                      steps = NULL,
                                      excluded = FALSE,
                                      level = NULL,
                                      numeric = "mean_sd",
                                      missing = c("ifany", "always", "never"),
                                      digits = 1L,
                                      drop_randomise = TRUE,
                                      assessed_label = "Assessed for eligibility",
                                      missing_label = "Missing",
                                      wide = FALSE) {
  if (!inherits(flow, "cf_flow")) rlang::abort("`flow` must be a `cf_flow` object.")
  vars    <- .check_vars(flow, vars)
  missing <- match.arg(missing)
  numeric <- .check_numeric_stats(numeric)
  if (!rlang::is_bool(excluded)) rlang::abort("`excluded` must be `TRUE` or `FALSE`.")
  if (!rlang::is_bool(drop_randomise)) rlang::abort("`drop_randomise` must be `TRUE` or `FALSE`.")
  if (!rlang::is_bool(wide)) rlang::abort("`wide` must be `TRUE` or `FALSE`.")
  .check_digits(digits)
  .check_string(assessed_label, "assessed_label")
  .check_string(missing_label, "missing_label")

  ks         <- .resolve_steps(flow, steps, excluded, drop_randomise)
  headings   <- .step_headings(flow, ks, assessed_label)
  level_cols <- .check_level(flow, level)
  if (!is.null(level_cols)) {
    varying <- setdiff(vars, c(level_cols, .level_constant_cols(flow$data, level_cols, vars)))
    if (length(varying) > 0L) {
      rlang::abort(sprintf(
        "`vars` column(s) %s vary within `%s` units; summarise at the row level or choose unit-level variables.",
        paste0("`", varying, "`", collapse = ", "), level
      ))
    }
  }
  keep <- union(level_cols, vars)

  cohorts <- lapply(ks, function(k) {
    .step_rows(flow, k, removed = excluded, level_cols = level_cols, keep = keep)
  })
  kinds  <- vapply(vars, function(v) .var_kind(flow$data[[v]]), character(1L))
  lvls   <- lapply(vars, function(v) .var_levels(flow$data[[v]]))

  blocks <- lapply(seq_along(vars), function(j) {
    per_step <- lapply(seq_along(ks), function(i) {
      rows <- .var_rows(cohorts[[i]][[vars[j]]], kinds[[j]], lvls[[j]], numeric, digits, missing_label)
      rows$step  <- rep(ks[i], nrow(rows))
      rows$label <- rep(headings[i], nrow(rows))
      rows$n     <- rep(nrow(cohorts[[i]]), nrow(rows))
      rows
    })
    block <- do.call(rbind, per_step)
    block <- block[order(block$.row, match(block$step, ks)), , drop = FALSE]
    if (missing == "never" || (missing == "ifany" && all(block$count[block$.missing] == 0L))) {
      block <- block[!block$.missing, , drop = FALSE]
    }
    block$variable <- rep(vars[j], nrow(block))
    block
  })
  tbl <- do.call(rbind, blocks)
  tbl <- tibble::as_tibble(tbl[c("variable", "level", "step", "label", "n", "count", "pct", "stat")])
  rownames(tbl) <- NULL

  if (wide) .characteristics_wide(tbl, ks, headings) else tbl
}

# ---------------------------------------------------------------------------
# Step selection and per-step rows
# ---------------------------------------------------------------------------

# Resolve `steps` to step numbers. NULL means 0..n (1..n when describing
# removed rows), minus randomise() steps if `drop_randomise`. Explicit
# selectors each resolve like cohort(at = ) and are never dropped.
.resolve_steps <- function(flow, steps, removed, drop_randomise) {
  n_steps <- length(flow$steps)
  if (is.null(steps)) {
    out <- seq.int(if (removed) 1L else 0L, n_steps)
    if (n_steps == 0L && removed) out <- integer(0L)
    if (drop_randomise) {
      types <- vapply(flow$steps, function(s) s$type, character(1L))
      out <- setdiff(out, .step_numbers(flow)[types == "randomise"])
    }
    if (length(out) == 0L) rlang::abort("The flow has no steps to describe.")
    return(as.integer(out))
  }
  if (!(is.atomic(steps) || is.list(steps)) || length(steps) == 0L) {
    rlang::abort("`steps` must be a vector or list of step numbers, labels or category names.")
  }
  out <- vapply(seq_along(steps), function(i) {
    as.integer(.resolve_step(flow, at = steps[[i]]))
  }, integer(1L))
  if (removed && any(out == 0L)) {
    rlang::abort("`steps` cannot include step 0 when `excluded = TRUE`: the starting data removes no rows.")
  }
  if (anyDuplicated(out)) {
    rlang::abort(sprintf(
      "`steps` selects step %s more than once.",
      paste(unique(out[duplicated(out)]), collapse = ", ")
    ))
  }
  out
}

# Column headings for the selected steps: the step label (fallback
# "Step <k>"), or `assessed_label` for step 0; made unique.
.step_headings <- function(flow, ks, assessed_label) {
  labels <- .step_labels(flow)
  out <- vapply(ks, function(k) {
    if (k == 0L) return(assessed_label)
    lbl <- labels[[k]]
    if (is.na(lbl) || !nzchar(lbl)) sprintf("Step %d", k) else lbl
  }, character(1L))
  make.unique(out, sep = " #")
}

# The rows described by step `k`: survivors of steps 1..k, or the rows
# removed at step k. Restricted to `keep` columns and, with `level_cols`,
# collapsed to one row per complete unit key.
.step_rows <- function(flow, k, removed, level_cols = NULL, keep) {
  if (removed) {
    d <- excluded(flow, step_number = k)
    d <- d[d$cf_step == k, , drop = FALSE]
  } else {
    d <- cohort(flow, step_number = k)
  }
  d <- as.data.frame(d)[keep]
  if (!is.null(level_cols)) {
    d <- d[stats::complete.cases(d[level_cols]), , drop = FALSE]
    d <- d[!duplicated(.composite_key(d, level_cols)), , drop = FALSE]
  }
  rownames(d) <- NULL
  d
}

# Level name -> its key column(s), or NULL. Needs a hierarchy on the flow.
.check_level <- function(flow, level) {
  if (is.null(level)) return(NULL)
  if (!is.character(level) || length(level) != 1L || is.na(level)) {
    rlang::abort("`level` must be a single hierarchy level name.")
  }
  if (is.null(flow$hierarchy)) {
    rlang::abort("`level` requires a flow built with `apply_criteria(hierarchy = )`.")
  }
  if (!level %in% names(flow$hierarchy)) {
    rlang::abort(sprintf(
      "`level` = \"%s\" is not a hierarchy level; available: %s.",
      level, paste0("\"", names(flow$hierarchy), "\"", collapse = ", ")
    ))
  }
  unname(unclass(flow$hierarchy)[[level]])
}

# Columns (among `cols`, default all but the row id) that take a single
# value within every complete unit at the level keyed by `level_cols`.
.level_constant_cols <- function(data, level_cols, cols = NULL) {
  if (is.null(cols)) cols <- setdiff(names(data), c(".cf_row_id", level_cols))
  cols <- setdiff(cols, level_cols)
  complete <- stats::complete.cases(data[level_cols])
  data <- data[complete, , drop = FALSE]
  if (nrow(data) == 0L) return(cols)
  key <- .composite_key(data, level_cols)
  constant <- vapply(cols, function(v) {
    !any(vapply(split(data[[v]], key), function(z) length(unique(z)) > 1L, logical(1L)))
  }, logical(1L))
  cols[constant]
}

# ---------------------------------------------------------------------------
# Argument checks
# ---------------------------------------------------------------------------

.check_vars <- function(flow, vars) {
  if (!is.character(vars) || length(vars) == 0L || anyNA(vars) || !all(nzchar(vars))) {
    rlang::abort("`vars` must be a character vector of column names.")
  }
  if (anyDuplicated(vars)) {
    rlang::abort(sprintf(
      "`vars` names %s more than once.", paste0("`", unique(vars[duplicated(vars)]), "`", collapse = ", ")
    ))
  }
  absent <- setdiff(vars, setdiff(names(flow$data), ".cf_row_id"))
  if (length(absent) > 0L) {
    rlang::abort(sprintf(
      "`vars` column(s) not found in the flow data: %s.", paste0("`", absent, "`", collapse = ", ")
    ))
  }
  for (v in vars) {
    x <- flow$data[[v]]
    if (!(is.numeric(x) || is.logical(x) || is.character(x) || is.factor(x))) {
      rlang::abort(sprintf(
        "`vars` column `%s` is <%s>; only numeric, logical, character and factor columns can be summarised.",
        v, paste(class(x), collapse = "/")
      ))
    }
  }
  vars
}

.numeric_stat_levels <- c(mean_sd = "Mean (SD)", median_iqr = "Median [IQR]")

.check_numeric_stats <- function(numeric) {
  choices <- names(.numeric_stat_levels)
  if (!is.character(numeric) || length(numeric) == 0L || anyNA(numeric) || !all(numeric %in% choices)) {
    rlang::abort("`numeric` must be \"mean_sd\", \"median_iqr\", or both.")
  }
  unique(numeric)
}

.check_digits <- function(digits) {
  if (!is.numeric(digits) || length(digits) != 1L || is.na(digits) || digits < 0 || digits %% 1 != 0) {
    rlang::abort("`digits` must be a single non-negative whole number.")
  }
  invisible(digits)
}

.check_string <- function(x, arg) {
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    rlang::abort(sprintf("`%s` must be a single string.", arg))
  }
  invisible(x)
}

# ---------------------------------------------------------------------------
# Per-variable summaries
# ---------------------------------------------------------------------------

.var_kind <- function(x) {
  if (is.logical(x)) return("logical")
  if (is.numeric(x)) return("numeric")
  "categorical"
}

# Row levels for a categorical variable, fixed from the starting data so
# every step column has the same rows.
.var_levels <- function(x) {
  if (is.factor(x)) return(levels(x))
  if (is.character(x)) return(sort(unique(x[!is.na(x)])))
  NULL
}

# Summary rows for one variable in one step column: data frame with
# `level`, `count`, `pct`, `stat`, plus `.row` (display order) and
# `.missing` (is this the missing-values row).
.var_rows <- function(x, kind, lv, numeric, digits, missing_label) {
  n_obs  <- sum(!is.na(x))
  n_miss <- sum(is.na(x))
  rows <- switch(kind,
    numeric = data.frame(
      level = unname(.numeric_stat_levels[numeric]),
      count = NA_integer_,
      pct   = NA_real_,
      stat  = vapply(numeric, function(st) .numeric_stat(x, st, digits), character(1L)),
      stringsAsFactors = FALSE
    ),
    logical = .count_rows(NA_character_, sum(x, na.rm = TRUE), n_obs, digits),
    categorical = .count_rows(
      lv, vapply(lv, function(l) sum(x == l, na.rm = TRUE), integer(1L)), n_obs, digits
    )
  )
  rows <- rbind(rows, .count_rows(missing_label, n_miss, length(x), digits))
  rows$.row     <- seq_len(nrow(rows))
  rows$.missing <- c(rep(FALSE, nrow(rows) - 1L), TRUE)
  rownames(rows) <- NULL
  rows
}

.count_rows <- function(level, count, denom, digits) {
  count <- as.integer(count)
  pct   <- if (denom > 0L) round(100 * count / denom, digits) else rep(NA_real_, length(count))
  stat  <- ifelse(
    is.na(pct), as.character(count),
    sprintf("%d (%s%%)", count, formatC(pct, format = "f", digits = digits))
  )
  data.frame(level = level, count = count, pct = pct, stat = stat, stringsAsFactors = FALSE)
}

.numeric_stat <- function(x, st, digits) {
  x <- x[!is.na(x)]
  if (length(x) == 0L) return(NA_character_)
  f <- function(v) if (is.na(v)) "\u2014" else formatC(v, format = "f", digits = digits)
  if (st == "mean_sd") {
    return(sprintf("%s (%s)", f(mean(x)), f(stats::sd(x))))
  }
  q <- stats::quantile(x, c(0.25, 0.5, 0.75), names = FALSE)
  sprintf("%s [%s, %s]", f(q[2L]), f(q[1L]), f(q[3L]))
}

# ---------------------------------------------------------------------------
# Wide pivot and display
# ---------------------------------------------------------------------------

# One row per (variable, level), one `stat` column per step.
.characteristics_wide <- function(tbl, ks, headings) {
  key  <- paste(tbl$variable, tbl$level, sep = "\r")
  rows <- tbl[!duplicated(key), c("variable", "level"), drop = FALSE]
  row_key <- key[!duplicated(key)]
  for (i in seq_along(ks)) {
    sub <- tbl[tbl$step == ks[i], , drop = FALSE]
    n_i <- if (nrow(sub) > 0L) sub$n[[1L]] else 0L
    col <- sprintf("%s (n = %d)", headings[i], n_i)
    rows[[col]] <- sub$stat[match(row_key, key[tbl$step == ks[i]])]
  }
  tibble::as_tibble(rows)
}

# Display frame for the renderers: a `label` column and one string column
# per step (named s1..sK so the names are always valid), with the row type
# ("variable" or "level") and the header text for each step column. A
# variable whose only row has `level` NA (a logical) shows its statistic on
# the variable row itself; other variables get a heading row and indented
# level rows. NA statistics display as an em dash.
.characteristics_display <- function(tbl, var_labels = NULL) {
  ks       <- unique(tbl$step)
  step_ids <- paste0("s", seq_along(ks))
  headers  <- vapply(ks, function(k) {
    sub <- tbl[tbl$step == k, , drop = FALSE]
    sprintf("%s (n = %d)", sub$label[[1L]], sub$n[[1L]])
  }, character(1L))

  stat_row <- function(sub) {
    vapply(ks, function(k) {
      s <- sub$stat[sub$step == k]
      if (length(s) == 0L || is.na(s[[1L]])) "\u2014" else s[[1L]]
    }, character(1L))
  }

  vars <- unique(tbl$variable)
  out  <- lapply(vars, function(v) {
    sub    <- tbl[tbl$variable == v, , drop = FALSE]
    label  <- if (!is.null(var_labels) && v %in% names(var_labels)) var_labels[[v]] else v
    inline <- sub[is.na(sub$level), , drop = FALSE]
    head_stats <- if (nrow(inline) > 0L) stat_row(inline) else rep("", length(ks))
    lv     <- unique(sub$level[!is.na(sub$level)])
    rows   <- lapply(lv, function(l) c("level", l, stat_row(sub[!is.na(sub$level) & sub$level == l, , drop = FALSE])))
    do.call(rbind, c(list(c("variable", label, head_stats)), rows))
  })
  m  <- do.call(rbind, out)
  df <- as.data.frame(m, stringsAsFactors = FALSE)
  names(df) <- c("row_type", "label", step_ids)
  rownames(df) <- NULL

  list(
    df       = df[c("label", step_ids)],
    row_type = df$row_type,
    step_ids = step_ids,
    headers  = stats::setNames(headers, step_ids)
  )
}

# `var_labels` -> named character vector keyed by column name.
.resolve_var_labels <- function(vars, var_labels) {
  if (is.null(var_labels)) return(NULL)
  if (!is.character(var_labels) || anyNA(var_labels)) {
    rlang::abort("`var_labels` must be a character vector.")
  }
  if (is.null(names(var_labels))) {
    if (length(var_labels) != length(vars)) {
      rlang::abort(sprintf(
        "`var_labels` has %d label(s) but `vars` has %d; name the labels by column or give one per variable.",
        length(var_labels), length(vars)
      ))
    }
    return(stats::setNames(var_labels, vars))
  }
  unknown <- setdiff(names(var_labels), vars)
  if (length(unknown) > 0L) {
    rlang::abort(sprintf(
      "`var_labels` names column(s) not in `vars`: %s.", paste0("`", unknown, "`", collapse = ", ")
    ))
  }
  var_labels
}

# ---------------------------------------------------------------------------
# as_characteristics_table() -- rendered output
# ---------------------------------------------------------------------------

#' Render a step-wise characteristics table
#'
#' Formats [as_characteristics_tibble()] as a publication-ready table in the
#' same APA style and through the same backends as [as_attrition_table()]:
#' a bold heading row per variable, indented summary rows, one column per
#' step headed by the step label and its `n`.
#'
#' @inheritSection as_characteristics_tibble Steps
#' @inheritSection as_characteristics_tibble Summaries
#' @inheritSection as_characteristics_tibble Hierarchy levels
#'
#' @inheritParams as_characteristics_tibble
#' @param backend Character string: `"flextable"` (default), `"gt"`, or
#'   `"huxtable"`.
#' @param variable_col_label Column header for the variable column. Default
#'   `"Characteristic"`.
#' @param var_labels Optional display names for the variables: a character
#'   vector named by column (e.g. `c(age = "Age, years")`), or an unnamed
#'   vector aligned with `vars`. Unlisted variables show their column name.
#' @return A `flextable`, `gt_tbl`, or `huxtable` object.
#' @seealso [as_characteristics_tibble()] for the underlying data layer.
#' @examples
#' \donttest{
#' dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ age >= 18, label = "Adults only") |>
#'   include(~ eligible_screen, label = "Passed screening") |>
#'   exclude(~ withdrew, label = "Withdrew consent")
#' flow <- apply_criteria(dat, crit, id = "participant_id")
#'
#' if (requireNamespace("flextable", quietly = TRUE) &&
#'     requireNamespace("officer", quietly = TRUE)) {
#'   as_characteristics_table(flow, vars = c("age", "sex", "withdrew"),
#'                            var_labels = c(age = "Age, years", sex = "Sex"))
#' }
#' if (requireNamespace("gt", quietly = TRUE)) {
#'   as_characteristics_table(flow, vars = c("age", "sex"), backend = "gt",
#'                            excluded = TRUE)
#' }
#' }
#' @export
as_characteristics_table <- function(flow,
                                     vars,
                                     backend = c("flextable", "gt", "huxtable"),
                                     steps = NULL,
                                     excluded = FALSE,
                                     level = NULL,
                                     numeric = "mean_sd",
                                     missing = c("ifany", "always", "never"),
                                     digits = 1L,
                                     drop_randomise = TRUE,
                                     assessed_label = "Assessed for eligibility",
                                     missing_label = "Missing",
                                     variable_col_label = "Characteristic",
                                     var_labels = NULL) {
  backend <- match.arg(backend)
  .check_string(variable_col_label, "variable_col_label")

  tbl <- as_characteristics_tibble(
    flow, vars,
    steps          = steps,
    excluded       = excluded,
    level          = level,
    numeric        = numeric,
    missing        = missing,
    digits         = digits,
    drop_randomise = drop_randomise,
    assessed_label = assessed_label,
    missing_label  = missing_label
  )
  display <- .characteristics_display(tbl, .resolve_var_labels(unique(tbl$variable), var_labels))

  switch(backend,
    flextable = .characteristics_flextable(display, variable_col_label),
    gt        = .characteristics_gt(display, variable_col_label),
    huxtable  = .characteristics_huxtable(display, variable_col_label)
  )
}

.characteristics_flextable <- function(display, variable_col_label) {
  if (!.has_namespace("flextable")) {
    rlang::abort('The {flextable} package is required. Install it with: install.packages("flextable")')
  }
  if (!.has_namespace("officer")) {
    rlang::abort('The {officer} package is required. Install it with: install.packages("officer")')
  }
  df       <- display$df
  step_ids <- display$step_ids
  var_rows <- which(display$row_type == "variable")
  lvl_rows <- which(display$row_type == "level")

  border_dark <- officer::fp_border(color = "black", width = 1.0)
  border_none <- officer::fp_border(color = "white", width = 0)
  header_values <- c(list(label = variable_col_label), as.list(display$headers))

  ft <- flextable::flextable(df) |>
    flextable::set_header_labels(values = header_values) |>
    flextable::width(j = "label", width = 2.5) |>
    flextable::width(j = step_ids, width = 1.3) |>
    flextable::align(j = step_ids, align = "right", part = "all") |>
    flextable::align(j = "label", align = "left", part = "all") |>
    flextable::bold(part = "header") |>
    flextable::bold(i = var_rows, j = "label") |>
    flextable::hline_top(part = "head", border = border_dark) |>
    flextable::hline_bottom(part = "head", border = border_dark) |>
    flextable::hline_bottom(part = "body", border = border_dark) |>
    flextable::vline(part = "all", border = border_none) |>
    flextable::fontsize(size = 12, part = "all") |>
    flextable::font(fontname = "Times New Roman", part = "all")

  if (length(lvl_rows) > 0L) {
    ft <- flextable::padding(ft, i = lvl_rows, j = "label", padding.left = 12L, part = "body")
  }
  ft
}

.characteristics_gt <- function(display, variable_col_label) {
  if (!.has_namespace("gt")) {
    rlang::abort('The {gt} package is required. Install it with: install.packages("gt")')
  }
  df       <- display$df
  step_ids <- display$step_ids
  var_rows <- which(display$row_type == "variable")
  lvl_rows <- which(display$row_type == "level")
  label_values <- c(list(label = variable_col_label), as.list(display$headers))

  gt_tbl <- gt::gt(df) |>
    # Empty cells (e.g. the header row's removed count, arm columns off the
    # final row) show blank, as in the flextable and huxtable backends.
    gt::sub_missing(missing_text = "") |>
    gt::cols_label(.list = label_values) |>
    gt::cols_align(align = "right", columns = step_ids) |>
    gt::cols_align(align = "left", columns = "label") |>
    gt::cols_width(label ~ gt::px(220)) |>
    gt::tab_style(
      style     = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(rows = var_rows, columns = "label")
    ) |>
    gt::tab_style(
      style     = gt::cell_text(weight = "bold"),
      locations = gt::cells_column_labels()
    ) |>
    gt::tab_options(
      table.font.size        = gt::px(12),
      table.font.names       = "Times New Roman",
      table.border.top.color = "black",
      table.border.top.width = gt::px(1),
      table_body.border.bottom.color    = "black",
      table_body.border.bottom.width    = gt::px(1),
      column_labels.border.bottom.color = "black",
      column_labels.border.bottom.width = gt::px(1),
      data_row.padding       = gt::px(4),
      table_body.vlines.color    = "transparent",
      column_labels.vlines.color = "transparent"
    )

  if (length(lvl_rows) > 0L) {
    gt_tbl <- gt::tab_style(
      gt_tbl,
      style     = gt::cell_text(indent = gt::px(12)),
      locations = gt::cells_body(rows = lvl_rows, columns = "label")
    )
  }
  gt_tbl
}

.characteristics_huxtable <- function(display, variable_col_label) {
  if (!.has_namespace("huxtable")) {
    rlang::abort('The {huxtable} package is required. Install it with: install.packages("huxtable")')
  }
  df       <- display$df
  n_cols   <- ncol(df)
  # Row 1 is the column header, so body rows are offset by one.
  var_rows <- which(display$row_type == "variable") + 1L
  lvl_rows <- which(display$row_type == "level") + 1L

  ht <- huxtable::as_hux(df, add_colnames = TRUE) |>
    huxtable::set_header_rows(1, TRUE) |>
    huxtable::set_contents(1, 1, variable_col_label)
  for (k in seq_along(display$step_ids)) {
    ht <- huxtable::set_contents(ht, 1, 1L + k, unname(display$headers[[k]]))
  }

  ht <- ht |>
    huxtable::set_align(huxtable::everywhere, seq.int(2L, n_cols), "right") |>
    huxtable::set_align(huxtable::everywhere, 1, "left") |>
    huxtable::set_bold(1, huxtable::everywhere, TRUE) |>
    huxtable::set_bold(var_rows, 1, TRUE) |>
    huxtable::set_top_border(1, huxtable::everywhere, 0.8) |>
    huxtable::set_bottom_border(1, huxtable::everywhere, 0.8) |>
    huxtable::set_bottom_border(nrow(df) + 1L, huxtable::everywhere, 0.8) |>
    huxtable::set_left_border(huxtable::everywhere, huxtable::everywhere, 0) |>
    huxtable::set_right_border(huxtable::everywhere, huxtable::everywhere, 0) |>
    huxtable::set_font_size(huxtable::everywhere, huxtable::everywhere, 12) |>
    huxtable::set_font(huxtable::everywhere, huxtable::everywhere, "Times New Roman") |>
    huxtable::set_width(1)

  if (length(lvl_rows) > 0L) {
    ht <- huxtable::set_left_padding(ht, lvl_rows, 1, 12)
  }
  ht
}
