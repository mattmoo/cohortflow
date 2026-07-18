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
#'   When `NULL` (default), the table is linear. When supplied, the surviving
#'   cohort is split by this column and branch rows are appended below the
#'   final common-flow row. Use `final_label = "Randomised"` when appropriate.
#' @param count_by Optional column name (string) for distinct counts. When
#'   supplied, counts are computed as `n_distinct(count_by)` rather than
#'   `nrow()`. Essential for crossover data where one participant has several
#'   event rows.
#'
#' @return A [tibble::tibble()] with columns:
#' \describe{
#'   \item{`row_type`}{`"header"`, `"category"`, `"step"`, `"final"`, or
#'     `"branch"`}
#'   \item{`label`}{Display text for the row}
#'   \item{`indent_level`}{`0` = header/final, `1` = category or top-level step,
#'     `2` = sub-step under a category, `1` = branch row}
#'   \item{`n`}{Number of participants at this point (N entering for
#'     category/step rows; N surviving for the final row; N in branch for
#'     branch rows)}
#'   \item{`n_removed`}{Number removed at this step (`NA` for header/final/branch)}
#'   \item{`pct_removed`}{Percentage removed relative to entering N (`NA` for
#'     header/branch; for final row: percentage retained of original N)}
#'   \item{`branch`}{Branch value for branch rows (`NA` for all other rows)}
#' }
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
#'   exclude(~ withdrew,           label = "Withdrew consent",    category = "Consent")
#' flow <- apply_criteria(dat, crit)
#' as_attrition_tibble(flow)
as_attrition_tibble <- function(
  flow,
  show_categories = TRUE,
  assessed_label  = "Assessed for eligibility",
  final_label     = "Final cohort",
  digits          = 1L,
  branch_by       = NULL,
  count_by        = NULL
) {
  if (!inherits(flow, "cf_flow")) {
    rlang::abort("`flow` must be a `cf_flow` object.")
  }

  # -- Validate branching parameters ----------------------------------------
  if (!is.null(branch_by)) {
    cohort_data <- cohort(flow)
    if (!branch_by %in% names(cohort_data)) {
      rlang::abort(sprintf("Column `%s` not found in surviving cohort.", branch_by))
    }
  }
  if (!is.null(count_by) && is.null(branch_by)) {
    rlang::abort("`count_by` requires `branch_by` to be specified.")
  }

  digits  <- as.integer(digits)
  steps   <- flow$steps
  n_start <- nrow(flow$data)
  n_end   <- n_start - sum(vapply(steps, `[[`, integer(1L), "n_fail"))

  rows <- list()

  # -- Header row -----------------------------------------------------------
  rows <- c(rows, list(tibble::tibble(
    row_type     = "header",
    label        = assessed_label,
    indent_level = 0L,
    n            = n_start,
    n_removed    = NA_integer_,
    pct_removed  = NA_real_,
    branch       = NA_character_
  )))

  # -- Step / category rows -------------------------------------------------
  if (show_categories) {
    rows <- c(rows, .attrition_rows_categorised(steps, digits))
  } else {
    rows <- c(rows, .attrition_rows_flat(steps, digits))
  }

  # -- Final cohort row -----------------------------------------------------
  rows <- c(rows, list(tibble::tibble(
    row_type     = "final",
    label        = final_label,
    indent_level = 0L,
    n            = n_end,
    n_removed    = NA_integer_,
    pct_removed  = round(100 * n_end / n_start, digits),
    branch       = NA_character_
  )))

  # -- Branch rows ----------------------------------------------------------
  if (!is.null(branch_by)) {
    rows <- c(rows, .attrition_rows_branches(flow, branch_by, count_by))
  }

  do.call(rbind, rows)
}

# Build rows with category grouping
.attrition_rows_categorised <- function(steps, digits) {
  rows <- list()
  i    <- 1L

  while (i <= length(steps)) {
    s   <- steps[[i]]
    cat <- s$category

    if (is.null(cat) || is.na(cat)) {
      # Uncategorised step -- emit a single step row at level 1
      rows <- c(rows, list(.make_step_row(s, indent_level = 1L, digits = digits)))
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
        branch       = NA_character_
      )))

      # Sub-rows for each step in category -- percentages are relative to
      # the total entering the category (n_in_cat), not each step's own
      # (progressively smaller) entering N, so that all rows within a
      # category are expressed as a percentage of the same denominator.
      for (cs in cat_steps) {
        rows <- c(rows, list(.make_step_row(
          cs, indent_level = 2L, digits = digits, pct_denom = n_in_cat
        )))
      }

      i <- j
    }
  }
  rows
}

# Build flat rows (one per step, no category grouping)
.attrition_rows_flat <- function(steps, digits) {
  lapply(steps, .make_step_row, indent_level = 1L, digits = digits)
}

# Build branch rows from the surviving cohort, split by branch_by.
# Returns a list of tibbles, one per branch value.
.attrition_rows_branches <- function(flow, branch_by, count_by) {
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

  lapply(branch_values, function(branch_val) {
    branch_data <- cohort_data[cohort_data[[branch_by]] == branch_val, ]
    branch_n <- count_fn(branch_data)

    tibble::tibble(
      row_type     = "branch",
      label        = as.character(branch_val),
      indent_level = 1L,
      n            = branch_n,
      n_removed    = NA_integer_,
      pct_removed  = NA_real_,
      branch       = as.character(branch_val)
    )
  })
}

# Build one step row. `pct_denom` is the denominator used for `pct_removed`
# (defaults to the step's own entering N); pass a different value (e.g. the
# category's entering N) to express the percentage relative to a shared
# denominator across grouped steps.
.make_step_row <- function(s, indent_level, digits, pct_denom = s$n_in) {
  pct <- if (pct_denom > 0L) round(100 * s$n_fail / pct_denom, digits) else NA_real_
  tibble::tibble(
    row_type     = "step",
    label        = s$label,
    indent_level = indent_level,
    n            = s$n_in,
    n_removed    = s$n_fail,
    pct_removed  = pct,
    branch       = NA_character_
  )
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
#'
#' @return A `flextable`, `gt_tbl`, or `huxtable` object, ready to print or
#'   include in a document.
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
#' # Save to Word
#' ft <- as_attrition_table(flow)
#' flextable::save_as_docx(ft, path = "attrition.docx")
#'
#' # Save to Word via gt
#' gt_tbl <- as_attrition_table(flow, backend = "gt")
#' gt::gtsave(gt_tbl, "attrition.docx")
#'
#' # LaTeX snippet via gt
#' gt::as_latex(gt_tbl)
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
  count_by            = NULL
) {
  backend <- match.arg(backend)

  tbl <- as_attrition_tibble(
    flow,
    show_categories = show_categories,
    assessed_label  = assessed_label,
    final_label     = final_label,
    digits          = digits,
    branch_by       = branch_by,
    count_by        = count_by
  )

  switch(backend,
    flextable = .attrition_flextable(tbl, criterion_col_label,
                                     n_col_label, removed_col_label,
                                     pct_col_label),
    gt        = .attrition_gt(tbl, criterion_col_label,
                              n_col_label, removed_col_label,
                              pct_col_label),
    huxtable  = .attrition_huxtable(tbl, criterion_col_label,
                                    n_col_label, removed_col_label,
                                    pct_col_label)
  )
}


# ---------------------------------------------------------------------------
# Shared display helper -- formats the tibble for display
# ---------------------------------------------------------------------------

# Converts the raw attrition tibble to a display data frame (4 cols) and
# returns recommended column widths for flextable (inches).
.attrition_display <- function(tbl, criterion_col_label,
                               n_col_label, removed_col_label,
                               pct_col_label) {

  pct_str <- dplyr::case_when(
    tbl$row_type == "header"               ~ NA_character_,
    tbl$row_type == "final"                ~ paste0(tbl$pct_removed, "%"),
    tbl$row_type == "branch"               ~ NA_character_,
    is.na(tbl$pct_removed) | tbl$pct_removed == 0 ~ "\u2014",
    TRUE                                   ~ paste0(tbl$pct_removed, "%")
  )

  n_removed_str <- dplyr::case_when(
    tbl$row_type %in% c("header", "final", "branch") ~ NA_character_,
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

  list(
    df         = df,
    col_widths = c(label = 3.5, n = 0.6, n_removed = 0.9, pct_removed = 1.0)
  )
}


# ---------------------------------------------------------------------------
# flextable backend
# ---------------------------------------------------------------------------

.attrition_flextable <- function(tbl, criterion_col_label,
                                 n_col_label, removed_col_label,
                                 pct_col_label) {

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
  df    <- display$df
  col_w <- display$col_widths

  # Row indices -- flextable body i= is 1-based into the body rows only,
  # no offset needed.
  header_rows  <- which(tbl$row_type == "header")
  final_rows   <- which(tbl$row_type == "final")
  branch_rows  <- which(tbl$row_type == "branch")
  cat_rows     <- which(tbl$row_type == "category")
  step1_rows   <- which(tbl$row_type == "step" & tbl$indent_level == 1L)
  step2_rows   <- which(tbl$row_type == "step" & tbl$indent_level == 2L)

  border_dark  <- officer::fp_border(color = "black", width = 1.0)
  border_none  <- officer::fp_border(color = "white", width = 0)

  ft <- flextable::flextable(df) |>
    # Column headers
    flextable::set_header_labels(
      label       = criterion_col_label,
      n           = n_col_label,
      n_removed   = removed_col_label,
      pct_removed = pct_col_label
    ) |>
    # Column widths (inches)
    flextable::width(j = "label",       width = col_w[["label"]]) |>
    flextable::width(j = "n",           width = col_w[["n"]]) |>
    flextable::width(j = "n_removed",   width = col_w[["n_removed"]]) |>
    flextable::width(j = "pct_removed", width = col_w[["pct_removed"]]) |>
    # Alignment
    flextable::align(j = c("n", "n_removed", "pct_removed"),
                     align = "right", part = "all") |>
    flextable::align(j = "label", align = "left", part = "all") |>
    # Column header row: bold, no background
    flextable::bold(part = "header") |>
    # Header / final data rows: bold, no background
    flextable::bold(i = c(header_rows, final_rows)) |>
    # Category rows: bold label, no background
    flextable::bold(i = cat_rows, j = "label") |>
    # Branch rows: bold label, no background
    flextable::bold(i = branch_rows, j = "label") |>
    # Indentation via left cell padding (pts)
    flextable::padding(i = step1_rows, j = "label", padding.left = 12L,
                       part = "body") |>
    flextable::padding(i = step2_rows, j = "label", padding.left = 24L,
                       part = "body") |>
    flextable::padding(i = branch_rows, j = "label", padding.left = 12L,
                       part = "body") |>
    # APA-style borders: no outer box, no vertical borders
    # Top rule above header
    flextable::hline_top(part = "head", border = border_dark) |>
    # Rule below header
    flextable::hline_bottom(part = "head", border = border_dark) |>
    # Rule above final row
    flextable::hline(i = min(final_rows) - 1L, part = "body",
                     border = border_dark) |>
    # Bottom rule below last row (branch rows if present, else final row)
    flextable::hline_bottom(part = "body", border = border_dark) |>
    # Remove all vertical borders
    flextable::vline(part = "all", border = border_none) |>
    # Typography: Times New Roman for APA
    flextable::fontsize(size = 12, part = "all") |>
    flextable::font(fontname = "Times New Roman", part = "all")

  ft
}


# ---------------------------------------------------------------------------
# gt backend
# ---------------------------------------------------------------------------

.attrition_gt <- function(tbl, criterion_col_label,
                          n_col_label, removed_col_label,
                          pct_col_label) {

  if (!.has_namespace("gt")) {
    rlang::abort(
      'The {gt} package is required. Install it with: install.packages("gt")'
    )
  }

  display <- .attrition_display(tbl, criterion_col_label,
                                n_col_label, removed_col_label,
                                pct_col_label)
  df <- display$df

  # Row indices
  header_rows  <- which(tbl$row_type == "header")
  final_rows   <- which(tbl$row_type == "final")
  branch_rows  <- which(tbl$row_type == "branch")
  cat_rows     <- which(tbl$row_type == "category")
  step1_rows   <- which(tbl$row_type == "step" & tbl$indent_level == 1L)
  step2_rows   <- which(tbl$row_type == "step" & tbl$indent_level == 2L)

  # gt needs a numeric row selector -- add a row index
  df$.row <- seq_len(nrow(df))

  gt_tbl <- gt::gt(df) |>
    # Hide the helper column
    gt::cols_hide(".row") |>
    # Column labels
    gt::cols_label(
      label       = criterion_col_label,
      n           = n_col_label,
      n_removed   = removed_col_label,
      pct_removed = pct_col_label
    ) |>
    # Alignment
    gt::cols_align(align = "right",  columns = c("n", "n_removed", "pct_removed")) |>
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
    # Branch rows: bold label, no background
    gt::tab_style(
      style     = gt::cell_text(weight = "bold"),
      locations = gt::cells_body(rows = branch_rows, columns = "label")
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
    # Indentation: branch rows (level 1)
    gt::tab_style(
      style     = gt::cell_text(indent = gt::px(12)),
      locations = gt::cells_body(rows = branch_rows, columns = "label")
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

  gt_tbl
}


# ---------------------------------------------------------------------------
# huxtable backend
# ---------------------------------------------------------------------------

.attrition_huxtable <- function(tbl, criterion_col_label,
                                n_col_label, removed_col_label,
                                pct_col_label) {

  if (!.has_namespace("huxtable")) {
    rlang::abort(
      'The {huxtable} package is required. Install it with: install.packages("huxtable")'
    )
  }

  display <- .attrition_display(tbl, criterion_col_label,
                                n_col_label, removed_col_label,
                                pct_col_label)
  df <- display$df

  # Row indices: huxtable row 1 = column header (added by add_colnames = TRUE),
  # so data rows are offset by +1.
  header_rows  <- which(tbl$row_type == "header")   + 1L
  final_rows   <- which(tbl$row_type == "final")    + 1L
  branch_rows  <- which(tbl$row_type == "branch")   + 1L
  cat_rows     <- which(tbl$row_type == "category") + 1L
  step1_rows   <- which(tbl$row_type == "step" & tbl$indent_level == 1L) + 1L
  step2_rows   <- which(tbl$row_type == "step" & tbl$indent_level == 2L) + 1L

  ht <- huxtable::as_hux(df, add_colnames = TRUE) |>
    huxtable::set_header_rows(1, TRUE) |>
    huxtable::set_contents(1, 1, criterion_col_label) |>
    huxtable::set_contents(1, 2, n_col_label) |>
    huxtable::set_contents(1, 3, removed_col_label) |>
    huxtable::set_contents(1, 4, pct_col_label) |>
    # Alignment
    huxtable::set_align(huxtable::everywhere, 2:4, "right") |>
    huxtable::set_align(huxtable::everywhere, 1,   "left") |>
    # Column header row: bold, no background
    huxtable::set_bold(1, huxtable::everywhere, TRUE) |>
    # Header / final data rows: bold, no background
    huxtable::set_bold(c(header_rows, final_rows), huxtable::everywhere, TRUE) |>
    # Category rows: bold label, no background
    huxtable::set_bold(cat_rows, 1, TRUE) |>
    # Branch rows: bold label, no background
    huxtable::set_bold(branch_rows, 1, TRUE) |>
    # Indentation via left padding (pts)
    huxtable::set_left_padding(step1_rows, 1, 12) |>
    huxtable::set_left_padding(step2_rows, 1, 24) |>
    huxtable::set_left_padding(branch_rows, 1, 12) |>
    # APA-style borders: no outer box, no vertical borders
    # Top rule above header
    huxtable::set_top_border(1, huxtable::everywhere, 0.8) |>
    # Rule below header
    huxtable::set_bottom_border(1, huxtable::everywhere, 0.8) |>
    # Rule above final row
    huxtable::set_top_border(min(final_rows), huxtable::everywhere, 0.8) |>
    # Bottom rule below last row (branch rows if present, else final row)
    huxtable::set_bottom_border(nrow(df) + 1L, huxtable::everywhere, 0.8) |>
    # Remove all other borders (no outer box, no vertical borders, no row separators)
    huxtable::set_left_border(huxtable::everywhere, huxtable::everywhere, 0) |>
    huxtable::set_right_border(huxtable::everywhere, huxtable::everywhere, 0) |>
    # Typography: Times New Roman for APA
    huxtable::set_font_size(huxtable::everywhere, huxtable::everywhere, 12) |>
    huxtable::set_font(huxtable::everywhere, huxtable::everywhere, "Times New Roman") |>
    huxtable::set_width(1)

  ht
}
