# ===========================================================================
# Attrition table output
# ===========================================================================

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Thin wrapper so tests can mock package availability without patching base.
.has_namespace <- function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
}

# ---------------------------------------------------------------------------
# as_attrition_tibble() -- plain data layer
# ---------------------------------------------------------------------------

#' Build an attrition tibble from a cohort flow object
#'
#' Produces a flat tibble describing the attrition at each step (or category)
#' of a cohort flow pipeline. This is the underlying data layer used by
#' `as_attrition_table()`, and is also useful for custom formatting.
#'
#' @section Row structure:
#' The tibble always starts with an "assessed" header row and ends with a
#' "final cohort" row. When `show_categories = TRUE` (the default), steps
#' that share a `category` are collapsed into a parent row (indent level 1)
#' with individual step sub-rows (indent level 2) nested beneath it.
#' Uncategorised steps appear at indent level 1 without sub-rows. When
#' `show_categories = FALSE`, one row per step is produced at indent level 1.
#'
#' @section Percentage columns:
#' * `pct_removed`: percentage of entering N removed at this row's step (or
#'   category). For the final cohort row this is the percentage *retained*
#'   relative to the initial N (i.e. `n / n_start * 100`).
#' * Percentages are relative to `n_in` -- the number entering that step or,
#'   for a category row, the number entering the first step in that category.
#' * When steps are grouped under a category (`show_categories = TRUE`),
#'   each step sub-row's `pct_removed` is also expressed relative to the
#'   category's total entering N (rather than its own, progressively
#'   smaller, entering N), so that all rows within a category share the same
#'   denominator and sum consistently with the category row's percentage.
#'
#' @section Grouping (`group_x` / `group_y`):
#' When `group_x` and/or `group_y` are supplied, the criteria pipeline
#' stored in `flow` is re-applied independently to each subset of the
#' *original* data defined by the unique values of the grouping column(s)
#' (e.g. trial site, time period). The returned tibble is a flat, "long"
#' stack of one full attrition block per group combination, with additional
#' `group_x` and `group_y` character columns identifying which subset each
#' row belongs to (`NA` for the ungrouped dimension). This long format is
#' the input to the grid layout produced by `as_attrition_table()`; use it
#' directly if you want to build your own custom cross-tabulated output.
#' `branch_by`/`count_by` cannot currently be combined with grouping.
#'
#' Rows where the grouping column itself is `NA` (e.g. missing ethnicity)
#' are **not** silently dropped, and are never folded into every other
#' group's counts. Instead they form their own explicit group, labelled by
#' `group_na_label` (default `"Missing"`), so the grouped totals still sum
#' to the full dataset.
#'
#' @param flow A `cf_flow` object produced by [apply_criteria()].
#' @param show_categories Logical. When `TRUE` (default) steps with the same
#'   `category` are collapsed under a single parent row. When `FALSE` one row
#'   per step is produced.
#' @param assessed_label Character string for the header row. Default
#'   `"Assessed for eligibility"`.
#' @param final_label Character string for the trailing final-cohort row.
#'   Default `"Final cohort"`.
#' @param digits Integer. Number of decimal places for `pct_removed`. Default
#'   `1`.
#' @param branch_by Optional column name (string) for allocation branching.
#'   When `NULL` (default), the table has a single `n` column unless the
#'   pipeline has a [randomise()] step, in which case its `arms` column is
#'   used automatically. When supplied (or defaulted), the surviving cohort
#'   is split by this column and the final row's total is broken out into
#'   one additional column per branch value (named after the branch value,
#'   e.g. `Control`, `Intervention`), each populated only on the final row.
#'   Use `final_label = "Randomised"` when appropriate. Cannot be combined
#'   with `group_x`/`group_y`.
#' @param count_by Optional column name (string) for distinct counts. When
#'   supplied, counts are computed as `n_distinct(count_by)` rather than
#'   `nrow()`. Essential for crossover data where one participant has several
#'   event rows.
#' @param group_x Optional column name (string), present in `flow$data`, used
#'   to repeat the attrition table across the "column" direction (e.g. trial
#'   site). See the Grouping section.
#' @param group_y Optional column name (string), present in `flow$data`, used
#'   to repeat the attrition table across the "row" direction (e.g. time
#'   period). See the Grouping section.
#' @param group_na_label Character string used to label the group formed by
#'   `NA` values in `group_x`/`group_y` (see the Grouping section). Default
#'   `"Missing"`. Ignored when the corresponding grouping column has no `NA`
#'   values.
#' @param levels Optional; requires `flow` to have been built with
#'   `apply_criteria(hierarchy = ...)`. When the default `character(0)`, this
#'   argument is ignored and the row-count behaviour above is unchanged. When
#'   `NULL`, one stacked block per hierarchy level is returned (finest to
#'   coarsest), each with a `level` column and an additional `n_consequential`
#'   column (see [apply_criteria()]'s `hierarchy` argument for the counting
#'   rule). When a character vector of level name(s), only those levels are
#'   returned, in the order given. Cannot be combined with `group_x`/`group_y`,
#'   `branch_by`, or `count_by`.
#'
#' @return A [tibble::tibble()] with columns:
#' \describe{
#'   \item{`row_type`}{`"header"`, `"category"`, `"step"`, or `"final"`}
#'   \item{`label`}{Display text for the row}
#'   \item{`indent_level`}{`0` = header/final, `1` = category or top-level
#'     step, `2` = sub-step under a category}
#'   \item{`n`}{Number of participants at this point (N entering for
#'     category/step rows; N surviving for the final row)}
#'   \item{`n_removed`}{Number removed at this step (`NA` for header/final)}
#'   \item{`pct_removed`}{Percentage removed relative to entering N (`NA` for
#'     header; for final row: percentage retained of original N)}
#'   \item{`branch`}{Always `NA`; retained for backward compatibility}
#' }
#' When `branch_by` is supplied, one additional column per unique branch
#' value is appended (named after the branch value), populated only on the
#' final row with that branch's surviving count. When `group_x`/`group_y`
#' are supplied, `group_x` and `group_y` character columns are appended (see
#' the Grouping section) and the tibble contains one stacked block per group
#' combination rather than a single block. When the pipeline has a
#' [randomise()] step, a `post_randomisation` logical column is appended
#' (`TRUE` for header/final/step/category rows at or after that step,
#' `FALSE` before it); this column is omitted entirely when there is no
#' `randomise()` step, so existing pipelines see no schema change.
#' @seealso [as_attrition_table()] for formatted table output.
#' @export
#'
#' @examples
#' dat  <- mock_cohortflow(n_participants = 200, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ !is.na(age),        label = "Age recorded",       category = "Valid age") |>
#'   include(~ age >= 18,          label = "Adults only",         category = "Valid age") |>
#'   include(~ eligible_screen,    label = "Passed screening",    category = "Eligible at screening") |>
#'   include(~ !is.na(consent_date), label = "Consent recorded",  category = "Consent") |>
#'   exclude(~ withdrew,           label = "Withdrew consent", category = "Consent")
#' flow <- apply_criteria(dat, crit)
#' as_attrition_tibble(flow)
as_attrition_tibble <- function(
  flow,
  show_categories = TRUE,
  assessed_label  = "Assessed for eligibility",
  final_label     = "Final cohort",
  digits          = 1L,
  branch_by       = NULL,
  count_by        = NULL,
  group_x         = NULL,
  group_y         = NULL,
  group_na_label  = "Missing",
  levels          = character(0)
) {
  if (!inherits(flow, "cf_flow")) {
    rlang::abort("`flow` must be a `cf_flow` object.")
  }

  # -- Hierarchy-level path ---------------------------------------------------
  if (!identical(levels, character(0))) {
    if (!is.null(group_x) || !is.null(group_y) || !is.null(branch_by) || !is.null(count_by)) {
      rlang::abort("`levels` cannot be combined with `group_x`/`group_y`/`branch_by`/`count_by`.")
    }
    return(.attrition_tibble_by_level(
      flow, levels, show_categories, assessed_label, final_label, digits
    ))
  }

  # -- Grouped path ----------------------------------------------------------
  if (!is.null(group_x) || !is.null(group_y)) {
    if (!is.null(branch_by) || !is.null(count_by)) {
      rlang::abort("`branch_by`/`count_by` cannot be combined with `group_x`/`group_y`.")
    }
    return(.attrition_tibble_grouped(
      flow, group_x, group_y, show_categories, assessed_label, final_label,
      digits, group_na_label
    ))
  }

  # -- Validate branching parameters ----------------------------------------
  # A `randomise()` step (if present) supplies default `branch_by` (from its
  # `arms` column) so callers don't have to repeat it at render time.
  randomise_step <- .find_randomise_step(flow$steps)
  if (is.null(branch_by) && !is.null(randomise_step)) {
    branch_by <- randomise_step$arms
  }

  if (!is.null(branch_by)) {
    cohort_data <- cohort(flow)
    if (!branch_by %in% names(cohort_data)) {
      rlang::abort(sprintf("Column `%s` not found in surviving cohort.", branch_by))
    }
  }
  if (!is.null(count_by) && is.null(branch_by)) {
    rlang::abort("`count_by` requires `branch_by` to be specified.")
  }

  .attrition_tibble_core(
    flow, show_categories, assessed_label, final_label, digits,
    branch_by, count_by
  )
}

# Core row-building logic shared by the top-level `as_attrition_tibble()`
# (after it has resolved `branch_by`'s `randomise()`-step default) and
# `.attrition_tibble_grouped()` (which always calls this directly with
# `branch_by = NULL, count_by = NULL`, bypassing randomise-step
# auto-detection -- branching is not supported alongside `group_x`/`group_y`).
.attrition_tibble_core <- function(flow, show_categories, assessed_label,
                                   final_label, digits, branch_by, count_by) {
  randomise_step <- .find_randomise_step(flow$steps)

  digits  <- as.integer(digits)
  steps   <- flow$steps
  n_start <- nrow(flow$data)
  n_end   <- n_start - sum(vapply(steps, `[[`, integer(1L), "n_fail"))
  randomise_step_num <- if (!is.null(randomise_step)) randomise_step$step else NA_integer_

  rows <- list()

  # -- Header row -----------------------------------------------------------
  rows <- c(rows, list(tibble::tibble(
    row_type     = "header",
    label        = assessed_label,
    indent_level = 0L,
    n            = n_start,
    n_removed    = NA_integer_,
    pct_removed  = NA_real_,
    branch       = NA_character_,
    post_randomisation = if (is.na(randomise_step_num)) NA else FALSE
  )))

  # -- Step / category rows -------------------------------------------------
  if (show_categories) {
    rows <- c(rows, .attrition_rows_categorised(steps, digits, randomise_step_num))
  } else {
    rows <- c(rows, .attrition_rows_flat(steps, digits, randomise_step_num))
  }

  # -- Final cohort row -----------------------------------------------------
  rows <- c(rows, list(tibble::tibble(
    row_type     = "final",
    label        = final_label,
    indent_level = 0L,
    n            = n_end,
    n_removed    = NA_integer_,
    pct_removed  = round(100 * n_end / n_start, digits),
    branch       = NA_character_,
    post_randomisation = if (is.na(randomise_step_num)) NA else TRUE
  )))

  out <- do.call(rbind, rows)

  # `post_randomisation` is only meaningful (and only added) when the
  # pipeline actually has a `randomise()` step -- otherwise the column is
  # dropped so the default schema is unchanged (backward compatible).
  if (is.null(randomise_step)) {
    out$post_randomisation <- NULL
  }

  # -- Branch columns ---------------------------------------------------------
  if (!is.null(branch_by)) {
    out <- .attrition_add_branch_columns(out, flow, branch_by, count_by)
  }

  out
}


# Build rows with category grouping
.attrition_rows_categorised <- function(steps, digits, randomise_step_num = NA_integer_) {
  rows <- list()
  i    <- 1L

  while (i <= length(steps)) {
    s   <- steps[[i]]
    cat <- s$category

    if (is.null(cat) || is.na(cat)) {
      # Uncategorised step -- emit a single step row at level 1
      rows <- c(rows, list(.make_step_row(
        s, indent_level = 1L, digits = digits, randomise_step_num = randomise_step_num
      )))
      i <- i + 1L
    } else {
      # Collect all consecutive steps sharing this category
      j <- i
      while (j <= length(steps) &&
               !is.null(steps[[j]]$category) &&
               !is.na(steps[[j]]$category) &&
               steps[[j]]$category == cat) {
        j <- j + 1L
      }
      cat_steps <- steps[seq(i, j - 1L)]

      # Category summary row
      n_in_cat    <- cat_steps[[1L]]$n_in
      n_fail_cat  <- sum(vapply(cat_steps, `[[`, integer(1L), "n_fail"))
      pct_removed <- if (n_in_cat > 0L) round(100 * n_fail_cat / n_in_cat, digits) else NA_real_

      # When a category has only one sub-step, suppress the exclusion count on
      # the category heading row to avoid duplicating the value shown on the
      # child row. The entering N is retained on the category row.
      is_singleton <- length(cat_steps) == 1L

      rows <- c(rows, list(tibble::tibble(
        row_type     = "category",
        label        = cat,
        indent_level = 1L,
        n            = n_in_cat,
        n_removed    = if (is_singleton) NA_integer_ else n_fail_cat,
        pct_removed  = if (is_singleton) NA_real_    else pct_removed,
        branch       = NA_character_,
        post_randomisation = if (is.na(randomise_step_num)) {
          NA
        } else {
          cat_steps[[1L]]$step >= randomise_step_num
        }
      )))

      # Sub-rows for each step in category -- percentages are relative to
      # the total entering the category (n_in_cat), not each step's own
      # (progressively smaller) entering N, so that all rows within a
      # category are expressed as a percentage of the same denominator.
      for (cs in cat_steps) {
        rows <- c(rows, list(.make_step_row(
          cs, indent_level = 2L, digits = digits, pct_denom = n_in_cat,
          randomise_step_num = randomise_step_num
        )))
      }

      i <- j
    }
  }
  rows
}

# Build flat rows (one per step, no category grouping)
.attrition_rows_flat <- function(steps, digits, randomise_step_num = NA_integer_) {
  lapply(steps, .make_step_row, indent_level = 1L, digits = digits,
         randomise_step_num = randomise_step_num)
}

# Add one column per unique branch value to the attrition tibble, populated
# only on the final row with that branch's surviving count. Column names are
# the branch values themselves (e.g. "Control", "Intervention"), so the N
# column is effectively split into per-branch columns on the final row
# rather than adding extra rows below it.
.attrition_add_branch_columns <- function(tbl, flow, branch_by, count_by) {
  cohort_data <- cohort(flow)

  # Count function: distinct count_by or nrow
  count_fn <- if (!is.null(count_by)) {
    if (!count_by %in% names(cohort_data)) {
      rlang::abort(sprintf("Column `%s` not found in surviving cohort.", count_by))
    }
    function(d) dplyr::n_distinct(d[[count_by]])
  } else {
    nrow
  }

  # Split cohort by branch_by
  branch_values <- sort(unique(cohort_data[[branch_by]]))
  final_idx     <- which(tbl$row_type == "final")

  for (branch_val in branch_values) {
    branch_data <- cohort_data[cohort_data[[branch_by]] == branch_val, ]
    branch_n    <- count_fn(branch_data)

    col_name <- as.character(branch_val)
    tbl[[col_name]] <- NA_integer_
    tbl[[col_name]][final_idx] <- branch_n
  }

  tbl
}

# Build one step row. `pct_denom` is the denominator used for `pct_removed`
# (defaults to the step's own entering N); pass a different value (e.g. the
# category's entering N) to express the percentage relative to a shared
# denominator across grouped steps. `randomise_step_num`, when not `NA`, adds
# a `post_randomisation` column (`TRUE` for steps at or after that step
# number).
.make_step_row <- function(s, indent_level, digits, pct_denom = s$n_in,
                          randomise_step_num = NA_integer_) {
  pct <- if (pct_denom > 0L) round(100 * s$n_fail / pct_denom, digits) else NA_real_
  tibble::tibble(
    row_type     = "step",
    label        = s$label,
    indent_level = indent_level,
    n            = s$n_in,
    n_removed    = s$n_fail,
    pct_removed  = pct,
    branch       = NA_character_,
    post_randomisation = if (is.na(randomise_step_num)) NA else s$step >= randomise_step_num
  )
}

# Finds the first step of type "randomise" in a step-records list (each
# element as recorded by `.run_criteria_steps()`), returning `NULL` if none
# exists. Used to default `branch_by` and to compute `post_randomisation` in
# `as_attrition_tibble()`, and to default `branch_by` in `as_consort_diagram()`.
.find_randomise_step <- function(steps) {
  for (s in steps) {
    if (identical(s$type, "randomise")) return(s)
  }
  NULL
}

# ---------------------------------------------------------------------------
# Grouped data layer -- group_x / group_y
# ---------------------------------------------------------------------------

# Re-applies `flow$criteria` independently to each subset of `flow$data`
# defined by the unique values of `group_x`/`group_y`, and stacks the
# resulting attrition blocks into one long tibble with `group_x`/`group_y`
# identifier columns. The row structure (row_type/label/indent_level) is
# identical across every block -- it depends only on the criteria pipeline,
# never on the data -- so the blocks can later be pivoted into a grid.
.attrition_tibble_grouped <- function(flow, group_x, group_y, show_categories,
                                      assessed_label, final_label, digits,
                                      group_na_label = "Missing") {
  data <- flow$data

  if (!is.null(group_x) && !group_x %in% names(data)) {
    rlang::abort(sprintf("Column `%s` not found in data.", group_x))
  }
  if (!is.null(group_y) && !group_y %in% names(data)) {
    rlang::abort(sprintf("Column `%s` not found in data.", group_y))
  }

  # Unique non-NA values, plus a sentinel `NA` appended at the end whenever
  # the column actually contains missing values -- this makes "Missing" its
  # own explicit group instead of either being silently dropped or (the
  # original bug) leaking into every other group via `== ` producing NA
  # matches under base R's `[` subsetting.
  x_vals <- if (!is.null(group_x)) .attrition_group_values(data[[group_x]]) else NA
  y_vals <- if (!is.null(group_y)) .attrition_group_values(data[[group_y]]) else NA

  blocks <- list()
  for (y in y_vals) {
    for (x in x_vals) {
      sub_data <- data
      if (!is.null(group_x)) {
        sub_data <- sub_data[.attrition_group_match(sub_data[[group_x]], x), , drop = FALSE]
      }
      if (!is.null(group_y)) {
        sub_data <- sub_data[.attrition_group_match(sub_data[[group_y]], y), , drop = FALSE]
      }

      sub_flow <- apply_criteria(sub_data, flow$criteria, id = ".cf_row_id")

      # Calls the core builder directly (not `as_attrition_tibble()`) so a
      # `randomise()` step in `flow$criteria` never triggers branch-column
      # auto-detection here -- branching is not supported alongside
      # `group_x`/`group_y`.
      block <- .attrition_tibble_core(
        sub_flow, show_categories, assessed_label, final_label, digits,
        branch_by = NULL, count_by = NULL
      )
      block$group_x <- if (!is.null(group_x)) .attrition_group_label(x, group_na_label) else NA_character_
      block$group_y <- if (!is.null(group_y)) .attrition_group_label(y, group_na_label) else NA_character_

      blocks <- c(blocks, list(block))
    }
  }

  do.call(rbind, blocks)
}

# Returns the sorted unique non-NA values of `x`, with a single `NA`
# sentinel appended at the end if `x` contains any missing values. This
# sentinel becomes its own explicit "Missing" group rather than being
# dropped or (incorrectly) folded into every other group.
.attrition_group_values <- function(x) {
  vals <- sort(unique(x), na.last = NA)
  if (anyNA(x)) vals <- c(vals, NA)
  vals
}

# Row-match helper used for grouped subsetting: matches non-NA `value`
# against `x` using `%in%` (never returns NA), and matches a `NA` sentinel
# `value` against `is.na(x)`. This ensures every row -- including those
# with a missing grouping value -- belongs to exactly one group.
.attrition_group_match <- function(x, value) {
  if (is.na(value)) is.na(x) else x %in% value
}

# Converts a group value (possibly the NA sentinel) to its display label.
.attrition_group_label <- function(value, na_label) {
  if (is.na(value)) na_label else as.character(value)
}

# ---------------------------------------------------------------------------
# Hierarchy-level data layer -- levels
# ---------------------------------------------------------------------------

# Builds one stacked attrition block per requested hierarchy level, each with
# its own `level` column and an `n_consequential` column sourced from each
# step's `hierarchy_counts` (see `.hierarchy_step_counts()` in R/hierarchy.R).
.attrition_tibble_by_level <- function(flow, levels, show_categories,
                                       assessed_label, final_label, digits) {
  hierarchy <- flow$hierarchy
  if (is.null(hierarchy)) {
    rlang::abort(paste(
      "`levels` requires `flow` to have a hierarchy;",
      "pass `hierarchy = ` to `apply_criteria()`."
    ))
  }

  level_names <- if (is.null(levels)) names(hierarchy) else levels
  unknown <- setdiff(level_names, names(hierarchy))
  if (length(unknown) > 0L) {
    rlang::abort(sprintf("Unknown hierarchy level(s): %s.", paste(unknown, collapse = ", ")))
  }

  steps <- flow$steps
  if (length(steps) > 0L && is.null(steps[[1L]]$hierarchy_counts)) {
    rlang::abort(paste(
      "`flow` has no per-level attrition counts;",
      "re-run `apply_criteria()` with `hierarchy = ` to use `levels`."
    ))
  }

  digits <- as.integer(digits)
  blocks <- lapply(level_names, function(lvl) {
    .attrition_tibble_one_level(flow, lvl, show_categories, assessed_label, final_label, digits)
  })

  do.call(rbind, blocks)
}

# Builds a single level's attrition block (header + step/category rows +
# final row), sourcing entering/passing/failing counts from each step's
# `hierarchy_counts` instead of `n_in`/`n_pass`/`n_fail`.
.attrition_tibble_one_level <- function(flow, level_name, show_categories,
                                        assessed_label, final_label, digits) {
  hierarchy  <- flow$hierarchy
  level_cols <- hierarchy[[level_name]]
  steps      <- flow$steps
  n_start    <- length(unique(.composite_key(flow$data, level_cols)))

  level_steps <- lapply(steps, function(s) {
    hc  <- s$hierarchy_counts
    row <- hc[hc$level == level_name, , drop = FALSE]
    list(
      label           = s$label,
      category        = s$category,
      n_in            = row$n_risk[[1L]],
      n_pass          = row$n_pass[[1L]],
      n_fail          = row$n_fail[[1L]],
      n_consequential = row$n_consequential[[1L]]
    )
  })

  n_end <- if (length(level_steps) > 0L) {
    level_steps[[length(level_steps)]]$n_pass
  } else {
    n_start
  }

  rows <- list(tibble::tibble(
    row_type        = "header",
    label           = assessed_label,
    indent_level    = 0L,
    n               = n_start,
    n_removed       = NA_integer_,
    n_consequential = NA_integer_,
    pct_removed     = NA_real_,
    branch          = NA_character_
  ))

  if (show_categories) {
    rows <- c(rows, .attrition_level_rows_categorised(level_steps, digits))
  } else {
    rows <- c(rows, lapply(level_steps, .make_level_step_row, digits = digits))
  }

  rows <- c(rows, list(tibble::tibble(
    row_type        = "final",
    label           = final_label,
    indent_level    = 0L,
    n               = n_end,
    n_removed       = NA_integer_,
    n_consequential = NA_integer_,
    pct_removed     = if (n_start > 0L) round(100 * n_end / n_start, digits) else NA_real_,
    branch          = NA_character_
  )))

  out <- do.call(rbind, rows)
  out$level <- level_name
  out
}

# Build one level-step row. `pct_denom` is the denominator used for
# `pct_removed` (defaults to the step's own entering N for this level); pass
# a different value (e.g. the category's entering N) to express the
# percentage relative to a shared denominator across grouped steps.
.make_level_step_row <- function(s, digits, pct_denom = s$n_in) {
  pct <- if (pct_denom > 0L) round(100 * s$n_fail / pct_denom, digits) else NA_real_
  tibble::tibble(
    row_type        = "step",
    label           = s$label,
    indent_level    = 1L,
    n               = s$n_in,
    n_removed       = s$n_fail,
    n_consequential = s$n_consequential,
    pct_removed     = pct,
    branch          = NA_character_
  )
}

# Build rows with category grouping for a single hierarchy level -- mirrors
# `.attrition_rows_categorised()`, summing both `n_fail` and
# `n_consequential` across the steps sharing a category.
.attrition_level_rows_categorised <- function(level_steps, digits) {
  rows <- list()
  i    <- 1L

  while (i <= length(level_steps)) {
    s   <- level_steps[[i]]
    cat <- s$category

    if (is.null(cat) || is.na(cat)) {
      rows <- c(rows, list(.make_level_step_row(s, digits = digits)))
      i <- i + 1L
    } else {
      j <- i
      while (j <= length(level_steps) &&
               !is.null(level_steps[[j]]$category) &&
               !is.na(level_steps[[j]]$category) &&
               level_steps[[j]]$category == cat) {
        j <- j + 1L
      }
      cat_steps <- level_steps[seq(i, j - 1L)]

      n_in_cat     <- cat_steps[[1L]]$n_in
      n_fail_cat   <- sum(vapply(cat_steps, `[[`, integer(1L), "n_fail"))
      n_conseq_cat <- sum(vapply(cat_steps, `[[`, integer(1L), "n_consequential"))
      pct_removed  <- if (n_in_cat > 0L) round(100 * n_fail_cat / n_in_cat, digits) else NA_real_
      is_singleton <- length(cat_steps) == 1L

      rows <- c(rows, list(tibble::tibble(
        row_type        = "category",
        label           = cat,
        indent_level    = 1L,
        n               = n_in_cat,
        n_removed       = if (is_singleton) NA_integer_ else n_fail_cat,
        n_consequential = if (is_singleton) NA_integer_ else n_conseq_cat,
        pct_removed     = if (is_singleton) NA_real_    else pct_removed,
        branch          = NA_character_
      )))

      for (cs in cat_steps) {
        rows <- c(rows, list(.make_level_step_row(
          cs, digits = digits, pct_denom = n_in_cat
        )))
      }

      i <- j
    }
  }
  rows
}

# ---------------------------------------------------------------------------
# as_attrition_table() -- formatted table
# ---------------------------------------------------------------------------

#' Format an attrition table from a cohort flow object
#'
#' Produces a formatted attrition table from a `cf_flow` object. Three output
#' backends are supported: `"flextable"` (best for Word), `"gt"` (best for
#' HTML and LaTeX), and `"huxtable"`. The underlying data is built by
#' [as_attrition_tibble()], which you can call directly for custom formatting.
#'
#' @section Output formats:
#' * **`"flextable"`** -- uses the \pkg{flextable} and \pkg{officer} packages.
#'   Renders natively to Word (`.docx`) via `officer::read_docx()`, to PDF
#'   via `flextable::save_as_image()`, and to HTML. Best choice when Word is
#'   the primary target.
#' * **`"gt"`** -- uses the \pkg{gt} package. Renders to HTML
#'   (`gt::gtsave(..., "table.html")`), LaTeX
#'   (`gt::as_latex()`), and Word (via `gt::gtsave(..., "table.docx")`
#'   requires the \pkg{webshot2} package). Best choice when LaTeX or HTML
#'   is the primary target.
#' * **`"huxtable"`** -- uses the \pkg{huxtable} package. Supports Word, LaTeX,
#'   and HTML output.
#'
#' @section Grouping (`group_x` / `group_y`):
#' Supplying `group_x` and/or `group_y` repeats the whole attrition table
#' across a grid: `group_x` values become repeated column blocks (N /
#' Removed / % removed, headed by a spanning column group), and `group_y`
#' values become repeated row blocks (each preceded by a bold group-heading
#' row), so the criterion rows appear once but attrition counts are shown
#' per group combination. This is useful, for example, for showing a
#' stepped-wedge trial's attrition by site (`group_x`) and period
#' (`group_y`). `branch_by` cannot be combined with grouping.
#'
#' @section Shading:
#' Cells can be shaded to highlight high-attrition rows/cells:
#' * `shade = "pct_removed"` or `"n_removed"` applies an automatic colour
#'   gradient (`shade_palette`, default white to red) scaled across the
#'   values present in step/category rows.
#' * `shade_fn` gives full control: supply a function that takes the
#'   attrition tibble (as returned by [as_attrition_tibble()], including
#'   `group_x`/`group_y` columns when grouped) and returns a character
#'   vector of colours (or `NA`) the same length as the tibble, one colour
#'   per row. `shade_fn` takes precedence over `shade` if both are supplied.
#'
#' @inheritParams as_attrition_tibble
#' @param backend Character string: `"flextable"` (default), `"gt"`, or
#'   `"huxtable"`.
#' @param criterion_col_label Column header for the criterion/label column.
#'   Default `"Criterion"`.
#' @param n_col_label Column header for the N column. Default `"N"`.
#' @param removed_col_label Column header for the removed column.
#'   Default `"Removed"`.
#' @param pct_col_label Column header for the percentage column.
#'   Default `"% removed"`.
#' @param group_x_label Optional prefix label for `group_x` column headings
#'   (e.g. `"Site"` to show `"Site: A"`). Default `NULL` (show the group
#'   value alone).
#' @param group_y_label Optional prefix label for `group_y` row headings
#'   (e.g. `"Period"` to show `"Period: 1"`). Default `NULL` (show the group
#'   value alone).
#' @param shade Optional character string: `"pct_removed"` or `"n_removed"`.
#'   When supplied, shades the N/Removed/% cells of step and category rows
#'   with an automatic colour gradient based on that column's value. Default
#'   `NULL` (no shading).
#' @param shade_fn Optional function for custom cell shading; see the
#'   Shading section. Default `NULL`.
#' @param shade_palette Character vector of >= 2 colours defining the
#'   gradient used by `shade`. Default `c("#FFFFFF", "#F8696B")` (white to
#'   red).
#'
#' @return A `flextable`, `gt_tbl`, or `huxtable` object, ready to print or
#'   include in a document. When `branch_by` is supplied, one additional
#'   column per branch value is added after the percentage column, headed
#'   with the branch value itself and populated only on the final row. When
#'   `group_x`/`group_y` are supplied, the table is a repeated grid as
#'   described in the Grouping section.
#' @seealso [as_attrition_tibble()] for the underlying plain-tibble data layer.
#' @export
#'
#' @examples
#' \dontrun{
#' dat  <- mock_cohortflow(n_participants = 200, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ !is.na(age),     label = "Age recorded",    category = "Valid age") |>
#'   include(~ age >= 18,       label = "Adults only",      category = "Valid age") |>
#'   include(~ eligible_screen, label = "Passed screening") |>
#'   include(~ !is.na(consent_date), label = "Consent recorded", category = "Consent") |>
#'   exclude(~ withdrew,        label = "Withdrew consent", category = "Consent")
#' flow <- apply_criteria(dat, crit)
#'
#' as_attrition_table(flow)                       # flextable (Word-ready)
#' as_attrition_table(flow, backend = "gt")       # gt (LaTeX/HTML-ready)
#' as_attrition_table(flow, backend = "huxtable") # huxtable
#'
#' # Shade cells by percentage removed
#' as_attrition_table(flow, shade = "pct_removed")
#'
#' # Grid: sites as columns, periods as rows (stepped-wedge design)
#' sw   <- mock_stepped_wedge(n_participants = 400, n_periods = 4, seed = 1)
#' flow_sw <- apply_criteria(sw, crit, id = "event_id")
#' as_attrition_table(flow_sw, group_x = "site_id", group_y = "period")
#'
#' # Save to Word
#' ft <- as_attrition_table(flow)
#' flextable::save_as_docx(ft, path = "attrition.docx")
#' }
as_attrition_table <- function(
  flow,
  backend             = c("flextable", "gt", "huxtable"),
  show_categories     = TRUE,
  assessed_label      = "Assessed for eligibility",
  final_label         = "Final cohort",
  digits              = 1L,
  criterion_col_label = "Criterion",
  n_col_label         = "N",
  removed_col_label   = "Removed",
  pct_col_label       = "% removed",
  branch_by           = NULL,
  count_by            = NULL,
  group_x             = NULL,
  group_y             = NULL,
  group_x_label       = NULL,
  group_y_label       = NULL,
  shade               = NULL,
  shade_fn            = NULL,
  shade_palette       = c("#FFFFFF", "#F8696B")
) {
  backend <- match.arg(backend)

  # -- Grouped grid path -------------------------------------------------
  if (!is.null(group_x) || !is.null(group_y)) {
    if (!is.null(branch_by) || !is.null(count_by)) {
      rlang::abort("`branch_by`/`count_by` cannot be combined with `group_x`/`group_y`.")
    }

    tbl <- as_attrition_tibble(
      flow,
      show_categories = show_categories,
      assessed_label  = assessed_label,
      final_label     = final_label,
      digits          = digits,
      group_x         = group_x,
      group_y         = group_y
    )

    shade_colours <- .attrition_shade_colours(tbl, shade, shade_fn, shade_palette)
    grid <- .attrition_build_grid(tbl, group_x, group_y, shade_colours)

    return(switch(backend,
      flextable = .attrition_flextable_grouped(grid, criterion_col_label,
                                               n_col_label, removed_col_label,
                                               pct_col_label, group_x_label,
                                               group_y_label),
      gt        = .attrition_gt_grouped(grid, criterion_col_label,
                                        n_col_label, removed_col_label,
                                        pct_col_label, group_x_label,
                                        group_y_label),
      huxtable  = .attrition_huxtable_grouped(grid, criterion_col_label,
                                              n_col_label, removed_col_label,
                                              pct_col_label, group_x_label,
                                              group_y_label)
    ))
  }

  # -- Plain (ungrouped) path -------------------------------------------------
  tbl <- as_attrition_tibble(
    flow,
    show_categories = show_categories,
    assessed_label  = assessed_label,
    final_label     = final_label,
    digits          = digits,
    branch_by       = branch_by,
    count_by        = count_by
  )

  shade_colours <- .attrition_shade_colours(tbl, shade, shade_fn, shade_palette)

  switch(backend,
    flextable = .attrition_flextable(tbl, criterion_col_label,
                                     n_col_label, removed_col_label,
                                     pct_col_label, shade_colours),
    gt        = .attrition_gt(tbl, criterion_col_label,
                              n_col_label, removed_col_label,
                              pct_col_label, shade_colours),
    huxtable  = .attrition_huxtable(tbl, criterion_col_label,
                                    n_col_label, removed_col_label,
                                    pct_col_label, shade_colours)
  )
}


# ---------------------------------------------------------------------------
# Shading helper
# ---------------------------------------------------------------------------

# Computes a per-row colour vector (aligned with `tbl`, one entry per row,
# NA meaning "no shading") from either a custom `shade_fn(tbl)` or a
# built-in gradient over `shade` ("pct_removed"/"n_removed"). Only
# step/category rows are shaded by the built-in gradient; header/final rows
# (and NA values) are left unshaded.
.attrition_shade_colours <- function(tbl, shade, shade_fn, shade_palette) {
  if (!is.null(shade_fn)) {
    cols <- shade_fn(tbl)
    if (length(cols) != nrow(tbl)) {
      rlang::abort(
        "`shade_fn` must return a colour vector the same length as the attrition data (nrow(tbl))."
      )
    }
    return(as.character(cols))
  }

  if (is.null(shade)) {
    return(rep(NA_character_, nrow(tbl)))
  }
  if (!shade %in% c("pct_removed", "n_removed")) {
    rlang::abort('`shade` must be "pct_removed", "n_removed", or NULL.')
  }

  values    <- tbl[[shade]]
  shadeable <- tbl$row_type %in% c("step", "category") & !is.na(values)
  cols      <- rep(NA_character_, nrow(tbl))

  if (!any(shadeable)) return(cols)

  rng    <- range(values[shadeable])
  scaled <- if (diff(rng) == 0) {
    rep(0, sum(shadeable))
  } else {
    (values[shadeable] - rng[1]) / diff(rng)
  }

  ramp    <- grDevices::colorRamp(shade_palette)
  rgb_mat <- ramp(scaled)
  cols[shadeable] <- grDevices::rgb(
    rgb_mat[, 1], rgb_mat[, 2], rgb_mat[, 3], maxColorValue = 255
  )
  cols
}


# ---------------------------------------------------------------------------
# Shared display helper -- formats the tibble for display
# ---------------------------------------------------------------------------

# Converts the raw attrition tibble to a display data frame and returns
# recommended column widths for flextable (inches). Any column beyond the
# standard set (row_type, label, indent_level, n, n_removed, pct_removed,
# branch) is treated as a per-branch N column -- these are added to the
# display data frame as-is (character, blank/NA except on the final row).
.attrition_display <- function(tbl, criterion_col_label,
                               n_col_label, removed_col_label,
                               pct_col_label) {

  # The final row's percentage is the percentage *retained*/*included*, not
  # removed, so it is labelled explicitly (e.g. "83.5% included") to avoid
  # reading as if it shared the "% removed" semantics of the column header
  # above it.
  pct_str <- dplyr::case_when(
    tbl$row_type == "header"               ~ NA_character_,
    tbl$row_type == "final"                ~ paste0(tbl$pct_removed, "% included"),
    is.na(tbl$pct_removed) | tbl$pct_removed == 0 ~ "\u2014",
    TRUE                                   ~ paste0(tbl$pct_removed, "%")
  )

  n_removed_str <- dplyr::case_when(
    tbl$row_type %in% c("header", "final") ~ NA_character_,
    is.na(tbl$n_removed)                   ~ NA_character_,
    tbl$n_removed == 0L                    ~ "\u2014",
    TRUE                                   ~ as.character(tbl$n_removed)
  )

  df <- tibble::tibble(
    label       = tbl$label,
    n           = as.character(tbl$n),
    n_removed   = n_removed_str,
    pct_removed = pct_str
  )

  # Branch columns -- any column beyond the standard set is a per-branch N
  # column, populated only on the final row (NA elsewhere).
  standard_cols <- c("row_type", "label", "indent_level", "n",
                     "n_removed", "pct_removed", "branch")
  branch_cols <- setdiff(names(tbl), standard_cols)

  for (col in branch_cols) {
    df[[col]] <- ifelse(is.na(tbl[[col]]), NA_character_, as.character(tbl[[col]]))
  }

  list(
    df          = df,
    col_widths  = c(label = 3.5, n = 0.6, n_removed = 0.9, pct_removed = 1.0),
    branch_cols = branch_cols
  )
}


# ---------------------------------------------------------------------------
# flextable backend
# ---------------------------------------------------------------------------

.attrition_flextable <- function(tbl, criterion_col_label,
                                 n_col_label, removed_col_label,
                                 pct_col_label, shade_colours = NULL) {

  if (!.has_namespace("flextable")) {
    rlang::abort(
      'The {flextable} package is required. Install it with: install.packages("flextable")'
    )
  }
  if (!.has_namespace("officer")) {
    rlang::abort(
      'The {officer} package is required. Install it with: install.packages("officer")'
    )
  }

  display <- .attrition_display(tbl, criterion_col_label,
                                n_col_label, removed_col_label,
                                pct_col_label)
  df          <- display$df
  col_w       <- display$col_widths
  branch_cols <- display$branch_cols

  if (is.null(shade_colours)) shade_colours <- rep(NA_character_, nrow(tbl))

  # Row indices -- flextable body i= is 1-based into the body rows only,
  # no offset needed.
  header_rows  <- which(tbl$row_type == "header")
  final_rows   <- which(tbl$row_type == "final")
  cat_rows     <- which(tbl$row_type == "category")
  step1_rows   <- which(tbl$row_type == "step" & tbl$indent_level == 1L)
  step2_rows   <- which(tbl$row_type == "step" & tbl$indent_level == 2L)

  border_dark  <- officer::fp_border(color = "black", width = 1.0)
  border_none  <- officer::fp_border(color = "white", width = 0)

  # Header labels: base columns plus one per branch column (headed with the
  # branch value itself).
  header_values <- stats::setNames(
    as.list(c(criterion_col_label, n_col_label, removed_col_label, pct_col_label,
              branch_cols)),
    c("label", "n", "n_removed", "pct_removed", branch_cols)
  )

  ft <- flextable::flextable(df) |>
    # Column headers
    flextable::set_header_labels(values = header_values) |>
    # Column widths (inches)
    flextable::width(j = "label",       width = col_w[["label"]]) |>
    flextable::width(j = "n",           width = col_w[["n"]]) |>
    flextable::width(j = "n_removed",   width = col_w[["n_removed"]]) |>
    flextable::width(j = "pct_removed", width = col_w[["pct_removed"]]) |>
    # Alignment
    flextable::align(j = c("n", "n_removed", "pct_removed", branch_cols),
                     align = "right", part = "all") |>
    flextable::align(j = "label", align = "left", part = "all") |>
    # Column header row: bold, no background
    flextable::bold(part = "header") |>
    # Header / final data rows: bold, no background
    flextable::bold(i = c(header_rows, final_rows)) |>
    # Category rows: bold label, no background
    flextable::bold(i = cat_rows, j = "label") |>
    # Indentation via left cell padding (pts)
    flextable::padding(i = step1_rows, j = "label", padding.left = 12L,
                       part = "body") |>
    flextable::padding(i = step2_rows, j = "label", padding.left = 24L,
                       part = "body") |>
    # APA-style borders: no outer box, no vertical borders
    # Top rule above header
    flextable::hline_top(part = "head", border = border_dark) |>
    # Rule below header
    flextable::hline_bottom(part = "head", border = border_dark) |>
    # Rule above final row
    flextable::hline(i = min(final_rows) - 1L, part = "body",
                     border = border_dark) |>
    # Bottom rule below last row
    flextable::hline_bottom(part = "body", border = border_dark) |>
    # Remove all vertical borders
    flextable::vline(part = "all", border = border_none) |>
    # Typography: Times New Roman for APA
    flextable::fontsize(size = 12, part = "all") |>
    flextable::font(fontname = "Times New Roman", part = "all")

  if (length(branch_cols) > 0L) {
    ft <- flextable::width(ft, j = branch_cols, width = 0.9)
  }

  # -- Shading ----------------------------------------------------------------
  for (i in seq_along(shade_colours)) {
    if (!is.na(shade_colours[[i]])) {
      ft <- flextable::bg(ft, i = i, j = c("n", "n_removed", "pct_removed"),
                          bg = shade_colours[[i]])
    }
  }

  ft
}


# ---------------------------------------------------------------------------
# gt backend
# ---------------------------------------------------------------------------

.attrition_gt <- function(tbl, criterion_col_label,
                          n_col_label, removed_col_label,
                          pct_col_label, shade_colours = NULL) {

  if (!.has_namespace("gt")) {
    rlang::abort(
      'The {gt} package is required. Install it with: install.packages("gt")'
    )
  }

  display <- .attrition_display(tbl, criterion_col_label,
                                n_col_label, removed_col_label,
                                pct_col_label)
  df          <- display$df
  branch_cols <- display$branch_cols

  if (is.null(shade_colours)) shade_colours <- rep(NA_character_, nrow(tbl))

  # Row indices
  header_rows  <- which(tbl$row_type == "header")
  final_rows   <- which(tbl$row_type == "final")
  cat_rows     <- which(tbl$row_type == "category")
  step1_rows   <- which(tbl$row_type == "step" & tbl$indent_level == 1L)
  step2_rows   <- which(tbl$row_type == "step" & tbl$indent_level == 2L)

  # gt needs a numeric row selector -- add a row index
  df$.row <- seq_len(nrow(df))

  # Column labels: base columns plus one per branch column (headed with the
  # branch value itself).
  label_values <- stats::setNames(
    as.list(c(criterion_col_label, n_col_label, removed_col_label, pct_col_label,
              branch_cols)),
    c("label", "n", "n_removed", "pct_removed", branch_cols)
  )

  gt_tbl <- gt::gt(df) |>
    # Hide the helper column
    gt::cols_hide(".row") |>
    # Column labels
    gt::cols_label(.list = label_values) |>
    # Alignment
    gt::cols_align(align = "right",
                   columns = c("n", "n_removed", "pct_removed", branch_cols)) |>
    gt::cols_align(align = "left",   columns = "label") |>
    # Column widths (px; gt uses px for HTML, approximately scales for other formats)
    gt::cols_width(
      label       ~ gt::px(280),
      n           ~ gt::px(60),
      n_removed   ~ gt::px(75),
      pct_removed ~ gt::px(85)
    ) |>
    # Header / final rows: bold, no background
    gt::tab_style(
      style     = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(rows = c(header_rows, final_rows))
    ) |>
    # Category rows: bold label, no background
    gt::tab_style(
      style     = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(rows = cat_rows, columns = "label")
    ) |>
    # Indentation: uncategorised step rows (level 1)
    gt::tab_style(
      style     = gt::cell_text(indent = gt::px(12)),
      locations = gt::cells_body(rows = step1_rows, columns = "label")
    ) |>
    # Indentation: sub-step rows (level 2)
    gt::tab_style(
      style     = gt::cell_text(indent = gt::px(24)),
      locations = gt::cells_body(rows = step2_rows, columns = "label")
    ) |>
    # Separator line above final row
    gt::tab_style(
      style     = gt::cell_borders(sides = "top",
                                   color = "black", weight = gt::px(1)),
      locations = gt::cells_body(rows = min(final_rows))
    ) |>
    # Column header style: bold, no background
    gt::tab_style(
      style     = gt::cell_text(weight = "bold"),
      locations = gt::cells_column_labels()
    ) |>
    # Table-level options: APA style
    gt::tab_options(
      table.font.size        = gt::px(12),
      table.font.names       = "Times New Roman",
      table.border.top.color = "black",
      table.border.top.width = gt::px(1),
      table_body.border.bottom.color = "black",
      table_body.border.bottom.width = gt::px(1),
      column_labels.border.bottom.color = "black",
      column_labels.border.bottom.width = gt::px(1),
      data_row.padding       = gt::px(4),
      # Remove vertical borders
      table_body.vlines.color = "transparent",
      column_labels.vlines.color = "transparent"
    )

  # -- Shading ----------------------------------------------------------------
  for (i in seq_along(shade_colours)) {
    if (!is.na(shade_colours[[i]])) {
      gt_tbl <- gt::tab_style(
        gt_tbl,
        style     = gt::cell_fill(color = shade_colours[[i]]),
        locations = gt::cells_body(rows = i, columns = c("n", "n_removed", "pct_removed"))
      )
    }
  }

  gt_tbl
}


# ---------------------------------------------------------------------------
# huxtable backend
# ---------------------------------------------------------------------------

.attrition_huxtable <- function(tbl, criterion_col_label,
                                n_col_label, removed_col_label,
                                pct_col_label, shade_colours = NULL) {

  if (!.has_namespace("huxtable")) {
    rlang::abort(
      'The {huxtable} package is required. Install it with: install.packages("huxtable")'
    )
  }

  display <- .attrition_display(tbl, criterion_col_label,
                                n_col_label, removed_col_label,
                                pct_col_label)
  df          <- display$df
  branch_cols <- display$branch_cols
  n_cols      <- ncol(df)

  if (is.null(shade_colours)) shade_colours <- rep(NA_character_, nrow(tbl))

  # Row indices: huxtable row 1 = column header (added by add_colnames = TRUE),
  # so data rows are offset by +1.
  header_rows  <- which(tbl$row_type == "header")   + 1L
  final_rows   <- which(tbl$row_type == "final")    + 1L
  cat_rows     <- which(tbl$row_type == "category") + 1L
  step1_rows   <- which(tbl$row_type == "step" & tbl$indent_level == 1L) + 1L
  step2_rows   <- which(tbl$row_type == "step" & tbl$indent_level == 2L) + 1L

  ht <- huxtable::as_hux(df, add_colnames = TRUE) |>
    huxtable::set_header_rows(1, TRUE) |>
    huxtable::set_contents(1, 1, criterion_col_label) |>
    huxtable::set_contents(1, 2, n_col_label) |>
    huxtable::set_contents(1, 3, removed_col_label) |>
    huxtable::set_contents(1, 4, pct_col_label)

  # Branch column headers: headed with the branch value itself
  for (k in seq_along(branch_cols)) {
    ht <- huxtable::set_contents(ht, 1, 4L + k, branch_cols[k])
  }

  ht <- ht |>
    # Alignment
    huxtable::set_align(huxtable::everywhere, 2:n_cols, "right") |>
    huxtable::set_align(huxtable::everywhere, 1,   "left") |>
    # Column header row: bold, no background
    huxtable::set_bold(1, huxtable::everywhere, TRUE) |>
    # Header / final data rows: bold, no background
    huxtable::set_bold(c(header_rows, final_rows), huxtable::everywhere, TRUE) |>
    # Category rows: bold label, no background
    huxtable::set_bold(cat_rows, 1, TRUE) |>
    # Indentation via left padding (pts)
    huxtable::set_left_padding(step1_rows, 1, 12) |>
    huxtable::set_left_padding(step2_rows, 1, 24) |>
    # APA-style borders: no outer box, no vertical borders
    # Top rule above header
    huxtable::set_top_border(1, huxtable::everywhere, 0.8) |>
    # Rule below header
    huxtable::set_bottom_border(1, huxtable::everywhere, 0.8) |>
    # Rule above final row
    huxtable::set_top_border(min(final_rows), huxtable::everywhere, 0.8) |>
    # Bottom rule below last row
    huxtable::set_bottom_border(nrow(df) + 1L, huxtable::everywhere, 0.8) |>
    # Remove all other borders (no outer box, no vertical borders, no row separators)
    huxtable::set_left_border(huxtable::everywhere, huxtable::everywhere, 0) |>
    huxtable::set_right_border(huxtable::everywhere, huxtable::everywhere, 0) |>
    # Typography: Times New Roman for APA
    huxtable::set_font_size(huxtable::everywhere, huxtable::everywhere, 12) |>
    huxtable::set_font(huxtable::everywhere, huxtable::everywhere, "Times New Roman") |>
    huxtable::set_width(1)

  # -- Shading ----------------------------------------------------------------
  for (i in seq_along(shade_colours)) {
    if (!is.na(shade_colours[[i]])) {
      ht <- huxtable::set_background_color(ht, i + 1L, 2:4, shade_colours[[i]])
    }
  }

  ht
}


# ---------------------------------------------------------------------------
# Grid construction -- pivots the long group_x/group_y tibble into a grid
# ---------------------------------------------------------------------------

# Builds a "grid" structure from the long-format grouped tibble: a list of
# per-group_y blocks, each a data frame with the (identical, criteria-driven)
# row skeleton plus one {n, n_removed, pct_removed, shade} column set per
# group_x value (prefixed x1__, x2__, ...). This is consumed by the three
# backend-specific *_grouped() renderers below.
.attrition_build_grid <- function(tbl, group_x, group_y, shade_colours) {
  has_x <- !is.null(group_x)
  has_y <- !is.null(group_y)

  x_vals <- if (has_x) unique(tbl$group_x) else NA_character_
  y_vals <- if (has_y) unique(tbl$group_y) else NA_character_

  first_mask <- rep(TRUE, nrow(tbl))
  if (has_x) first_mask <- first_mask & (tbl$group_x == x_vals[[1]])
  if (has_y) first_mask <- first_mask & (tbl$group_y == y_vals[[1]])
  skeleton <- tbl[first_mask, c("row_type", "label", "indent_level")]
  n_skel   <- nrow(skeleton)

  blocks   <- list()
  y_labels <- character(0)

  for (yi in seq_along(y_vals)) {
    y <- y_vals[[yi]]
    block <- skeleton

    for (xi in seq_along(x_vals)) {
      x <- x_vals[[xi]]
      mask <- rep(TRUE, nrow(tbl))
      if (has_x) mask <- mask & (tbl$group_x == x)
      if (has_y) mask <- mask & (tbl$group_y == y)

      sub <- tbl[mask, ]
      pfx <- paste0("x", xi, "__")
      block[[paste0(pfx, "n")]]           <- sub$n
      block[[paste0(pfx, "n_removed")]]   <- sub$n_removed
      block[[paste0(pfx, "pct_removed")]] <- sub$pct_removed
      block[[paste0(pfx, "shade")]]       <- shade_colours[mask]
    }

    blocks[[yi]]   <- block
    y_labels[[yi]] <- if (has_y) y else NA_character_
  }

  list(
    blocks   = blocks,
    y_labels = y_labels,
    x_labels = if (has_x) x_vals else NULL,
    n_x      = max(length(x_vals), 1L),
    n_skel   = n_skel,
    has_x    = has_x,
    has_y    = has_y
  )
}

# Assembles the grid into (a) a raw data frame `df_full` (row_type,
# indent_level, label, and one {n, n_removed, pct_removed, shade} set per
# x value, plus synthetic "y_heading" rows inserted before each y block when
# `has_y`), and (b) a character `display` data frame ready for the
# backend-specific renderers. Shared across all three backends so styling
# logic (row-type indices, header labels) is written once.
.attrition_grid_assemble <- function(grid, group_x_label, group_y_label) {
  n_x <- grid$n_x

  body_rows <- list()
  cursor    <- 0L

  for (bi in seq_along(grid$blocks)) {
    block <- grid$blocks[[bi]]

    if (grid$has_y) {
      heading <- block[1, , drop = FALSE]
      value_cols <- setdiff(names(heading), c("row_type", "label", "indent_level"))
      heading[1, value_cols] <- NA
      heading$row_type     <- "y_heading"
      heading$indent_level <- 0L
      heading$label <- if (!is.null(group_y_label)) {
        paste0(group_y_label, ": ", grid$y_labels[[bi]])
      } else {
        grid$y_labels[[bi]]
      }
      body_rows[[length(body_rows) + 1L]] <- heading
      cursor <- cursor + 1L
    }

    body_rows[[length(body_rows) + 1L]] <- block
    cursor <- cursor + nrow(block)
  }

  df_full <- do.call(rbind, body_rows)

  display <- tibble::tibble(label = df_full$label)
  for (xi in seq_len(n_x)) {
    pfx     <- paste0("x", xi, "__")
    n_col   <- df_full[[paste0(pfx, "n")]]
    nr_col  <- df_full[[paste0(pfx, "n_removed")]]
    pct_col <- df_full[[paste0(pfx, "pct_removed")]]

    display[[paste0(pfx, "n")]] <- ifelse(is.na(n_col), "", as.character(n_col))
    display[[paste0(pfx, "n_removed")]] <- dplyr::case_when(
      is.na(nr_col) ~ "",
      nr_col == 0L  ~ "\u2014",
      TRUE          ~ as.character(nr_col)
    )
    # The final row's percentage is the percentage *retained*/*included*, not
    # removed, so it is labelled explicitly (e.g. "83.5% included") to avoid
    # reading as if it shared the "% removed" semantics of the column header.
    display[[paste0(pfx, "pct_removed")]] <- dplyr::case_when(
      is.na(pct_col)                    ~ "",
      df_full$row_type == "final"       ~ paste0(pct_col, "% included"),
      TRUE                               ~ paste0(pct_col, "%")
    )
  }

  x_headings <- if (grid$has_x) {
    if (!is.null(group_x_label)) {
      paste0(group_x_label, ": ", grid$x_labels)
    } else {
      grid$x_labels
    }
  } else {
    character(0)
  }

  list(
    df_full     = df_full,
    display     = display,
    n_x         = n_x,
    has_x       = grid$has_x,
    x_headings  = x_headings,
    header_rows = which(df_full$row_type == "header"),
    final_rows  = which(df_full$row_type == "final"),
    cat_rows    = which(df_full$row_type == "category"),
    step1_rows  = which(df_full$row_type == "step" & df_full$indent_level == 1L),
    step2_rows  = which(df_full$row_type == "step" & df_full$indent_level == 2L),
    yhead_rows  = which(df_full$row_type == "y_heading")
  )
}


# ---------------------------------------------------------------------------
# Grouped grid renderers
# ---------------------------------------------------------------------------

.attrition_flextable_grouped <- function(grid, criterion_col_label,
                                         n_col_label, removed_col_label,
                                         pct_col_label, group_x_label, group_y_label) {
  if (!.has_namespace("flextable")) {
    rlang::abort(
      'The {flextable} package is required. Install it with: install.packages("flextable")'
    )
  }
  if (!.has_namespace("officer")) {
    rlang::abort(
      'The {officer} package is required. Install it with: install.packages("officer")'
    )
  }

  a   <- .attrition_grid_assemble(grid, group_x_label, group_y_label)
  n_x <- a$n_x

  header_values <- list(label = criterion_col_label)
  for (xi in seq_len(n_x)) {
    pfx <- paste0("x", xi, "__")
    header_values[[paste0(pfx, "n")]]           <- n_col_label
    header_values[[paste0(pfx, "n_removed")]]   <- removed_col_label
    header_values[[paste0(pfx, "pct_removed")]] <- pct_col_label
  }

  border_dark <- officer::fp_border(color = "black", width = 1.0)
  border_none <- officer::fp_border(color = "white", width = 0)

  ft <- flextable::flextable(a$display) |>
    flextable::set_header_labels(values = header_values)

  if (a$has_x) {
    top_values <- c("", unlist(lapply(a$x_headings, function(h) c(h, "", ""))))
    ft <- flextable::add_header_row(ft, top = TRUE, values = top_values)
    for (xi in seq_len(n_x)) {
      cols <- c(paste0("x", xi, "__n"), paste0("x", xi, "__n_removed"),
                paste0("x", xi, "__pct_removed"))
      ft <- flextable::merge_at(ft, i = 1, j = cols, part = "header")
    }
    ft <- flextable::align(ft, i = 1, align = "center", part = "header")
    ft <- flextable::bold(ft, i = 1, part = "header")
  }

  value_cols <- unlist(lapply(seq_len(n_x), function(xi) {
    pfx <- paste0("x", xi, "__")
    c(paste0(pfx, "n"), paste0(pfx, "n_removed"), paste0(pfx, "pct_removed"))
  }))

  ft <- ft |>
    flextable::align(j = value_cols, align = "right", part = "all") |>
    flextable::align(j = "label", align = "left", part = "all") |>
    flextable::bold(part = "header") |>
    flextable::bold(i = c(a$header_rows, a$final_rows)) |>
    flextable::bold(i = a$cat_rows, j = "label") |>
    flextable::bold(i = a$yhead_rows, j = "label") |>
    flextable::padding(i = a$step1_rows, j = "label", padding.left = 12L, part = "body") |>
    flextable::padding(i = a$step2_rows, j = "label", padding.left = 24L, part = "body") |>
    flextable::hline_top(part = "head", border = border_dark) |>
    flextable::hline_bottom(part = "head", border = border_dark) |>
    flextable::hline_bottom(part = "body", border = border_dark) |>
    flextable::vline(part = "all", border = border_none) |>
    flextable::fontsize(size = 12, part = "all") |>
    flextable::font(fontname = "Times New Roman", part = "all")

  rule_rows <- sort(unique(c(a$final_rows - 1L, a$yhead_rows[a$yhead_rows > 1L] - 1L)))
  rule_rows <- rule_rows[rule_rows >= 1L]
  for (r in rule_rows) {
    ft <- flextable::hline(ft, i = r, part = "body", border = border_dark)
  }

  for (xi in seq_len(n_x)) {
    pfx       <- paste0("x", xi, "__")
    shade_col <- a$df_full[[paste0(pfx, "shade")]]
    cols      <- c(paste0(pfx, "n"), paste0(pfx, "n_removed"), paste0(pfx, "pct_removed"))
    for (i in seq_along(shade_col)) {
      if (!is.na(shade_col[[i]])) {
        ft <- flextable::bg(ft, i = i, j = cols, bg = shade_col[[i]])
      }
    }
  }

  ft
}


.attrition_gt_grouped <- function(grid, criterion_col_label,
                                  n_col_label, removed_col_label,
                                  pct_col_label, group_x_label, group_y_label) {
  if (!.has_namespace("gt")) {
    rlang::abort(
      'The {gt} package is required. Install it with: install.packages("gt")'
    )
  }

  a   <- .attrition_grid_assemble(grid, group_x_label, group_y_label)
  n_x <- a$n_x
  df  <- a$display
  df$.row <- seq_len(nrow(df))

  label_values <- list(label = criterion_col_label)
  for (xi in seq_len(n_x)) {
    pfx <- paste0("x", xi, "__")
    label_values[[paste0(pfx, "n")]]           <- n_col_label
    label_values[[paste0(pfx, "n_removed")]]   <- removed_col_label
    label_values[[paste0(pfx, "pct_removed")]] <- pct_col_label
  }

  value_cols <- unlist(lapply(seq_len(n_x), function(xi) {
    pfx <- paste0("x", xi, "__")
    c(paste0(pfx, "n"), paste0(pfx, "n_removed"), paste0(pfx, "pct_removed"))
  }))

  gt_tbl <- gt::gt(df) |>
    gt::cols_hide(".row") |>
    gt::cols_label(.list = label_values) |>
    gt::cols_align(align = "right", columns = value_cols) |>
    gt::cols_align(align = "left", columns = "label") |>
    gt::tab_style(
      style     = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(rows = c(a$header_rows, a$final_rows, a$yhead_rows))
    ) |>
    gt::tab_style(
      style     = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(rows = a$cat_rows, columns = "label")
    ) |>
    gt::tab_style(
      style     = gt::cell_text(indent = gt::px(12)),
      locations = gt::cells_body(rows = a$step1_rows, columns = "label")
    ) |>
    gt::tab_style(
      style     = gt::cell_text(indent = gt::px(24)),
      locations = gt::cells_body(rows = a$step2_rows, columns = "label")
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
      table_body.border.bottom.color = "black",
      table_body.border.bottom.width = gt::px(1),
      column_labels.border.bottom.color = "black",
      column_labels.border.bottom.width = gt::px(1),
      data_row.padding       = gt::px(4),
      table_body.vlines.color = "transparent",
      column_labels.vlines.color = "transparent"
    )

  if (a$has_x) {
    for (xi in seq_len(n_x)) {
      pfx  <- paste0("x", xi, "__")
      cols <- c(paste0(pfx, "n"), paste0(pfx, "n_removed"), paste0(pfx, "pct_removed"))
      gt_tbl <- gt::tab_spanner(gt_tbl, label = a$x_headings[[xi]], columns = cols)
    }
  }

  rule_rows <- sort(unique(c(a$final_rows, a$yhead_rows[a$yhead_rows > 1L])))
  for (r in rule_rows) {
    gt_tbl <- gt::tab_style(
      gt_tbl,
      style     = gt::cell_borders(sides = "top", color = "black", weight = gt::px(1)),
      locations = gt::cells_body(rows = r)
    )
  }

  for (xi in seq_len(n_x)) {
    pfx       <- paste0("x", xi, "__")
    shade_col <- a$df_full[[paste0(pfx, "shade")]]
    cols      <- c(paste0(pfx, "n"), paste0(pfx, "n_removed"), paste0(pfx, "pct_removed"))
    for (i in seq_along(shade_col)) {
      if (!is.na(shade_col[[i]])) {
        gt_tbl <- gt::tab_style(
          gt_tbl,
          style     = gt::cell_fill(color = shade_col[[i]]),
          locations = gt::cells_body(rows = i, columns = cols)
        )
      }
    }
  }

  gt_tbl
}


.attrition_huxtable_grouped <- function(grid, criterion_col_label,
                                        n_col_label, removed_col_label,
                                        pct_col_label, group_x_label, group_y_label) {
  if (!.has_namespace("huxtable")) {
    rlang::abort(
      'The {huxtable} package is required. Install it with: install.packages("huxtable")'
    )
  }

  a      <- .attrition_grid_assemble(grid, group_x_label, group_y_label)
  n_x    <- a$n_x
  df     <- a$display
  n_cols <- ncol(df)

  ht <- huxtable::as_hux(df, add_colnames = TRUE)
  ht <- huxtable::set_contents(ht, 1, 1, criterion_col_label)
  col <- 2L
  for (xi in seq_len(n_x)) {
    ht <- huxtable::set_contents(ht, 1, col,       n_col_label)
    ht <- huxtable::set_contents(ht, 1, col + 1L,  removed_col_label)
    ht <- huxtable::set_contents(ht, 1, col + 2L,  pct_col_label)
    col <- col + 3L
  }

  header_offset <- 1L
  if (a$has_x) {
    spanner_row <- c("", unlist(lapply(a$x_headings, function(h) c(h, "", ""))))
    ht <- do.call(huxtable::insert_row, c(list(ht), as.list(spanner_row), list(after = 0)))
    col <- 2L
    for (xi in seq_len(n_x)) {
      ht <- huxtable::merge_cells(ht, 1, col:(col + 2L))
      col <- col + 3L
    }
    ht <- huxtable::set_align(ht, 1, huxtable::everywhere, "center")
    ht <- huxtable::set_bold(ht, 1, huxtable::everywhere, TRUE)
    header_offset <- 2L
  }

  ht <- huxtable::set_header_rows(ht, seq_len(header_offset), TRUE)

  header_rows <- a$header_rows + header_offset
  final_rows  <- a$final_rows  + header_offset
  cat_rows    <- a$cat_rows    + header_offset
  step1_rows  <- a$step1_rows  + header_offset
  step2_rows  <- a$step2_rows  + header_offset
  yhead_rows  <- a$yhead_rows  + header_offset

  ht <- ht |>
    huxtable::set_align(huxtable::everywhere, 2:n_cols, "right") |>
    huxtable::set_align(huxtable::everywhere, 1, "left") |>
    huxtable::set_bold(header_offset, huxtable::everywhere, TRUE) |>
    huxtable::set_bold(c(header_rows, final_rows, yhead_rows), huxtable::everywhere, TRUE) |>
    huxtable::set_bold(cat_rows, 1, TRUE) |>
    huxtable::set_left_padding(step1_rows, 1, 12) |>
    huxtable::set_left_padding(step2_rows, 1, 24) |>
    huxtable::set_top_border(1, huxtable::everywhere, 0.8) |>
    huxtable::set_bottom_border(header_offset, huxtable::everywhere, 0.8) |>
    huxtable::set_bottom_border(nrow(df) + header_offset, huxtable::everywhere, 0.8) |>
    huxtable::set_left_border(huxtable::everywhere, huxtable::everywhere, 0) |>
    huxtable::set_right_border(huxtable::everywhere, huxtable::everywhere, 0) |>
    huxtable::set_font_size(huxtable::everywhere, huxtable::everywhere, 12) |>
    huxtable::set_font(huxtable::everywhere, huxtable::everywhere, "Times New Roman") |>
    huxtable::set_width(1)

  rule_rows <- sort(unique(c(final_rows, yhead_rows[a$yhead_rows > 1L])))
  for (r in rule_rows) {
    ht <- huxtable::set_top_border(ht, r, huxtable::everywhere, 0.8)
  }

  col <- 2L
  for (xi in seq_len(n_x)) {
    shade_col <- a$df_full[[paste0("x", xi, "__shade")]]
    cols      <- col:(col + 2L)
    for (i in seq_along(shade_col)) {
      if (!is.na(shade_col[[i]])) {
        ht <- huxtable::set_background_color(ht, i + header_offset, cols, shade_col[[i]])
      }
    }
    col <- col + 3L
  }

  ht
}
