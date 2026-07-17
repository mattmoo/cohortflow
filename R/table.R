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
#'
#' @return A [tibble::tibble()] with columns:
#' \describe{
#'   \item{`row_type`}{`"header"`, `"category"`, `"step"`, or `"final"`}
#'   \item{`label`}{Display text for the row}
#'   \item{`indent_level`}{`0` = header/final, `1` = category or top-level step,
#'     `2` = sub-step under a category}
#'   \item{`n`}{Number of participants at this point (N entering for
#'     category/step rows; N surviving for the final row)}
#'   \item{`n_removed`}{Number removed at this step (`NA` for header/final)}
#'   \item{`pct_removed`}{Percentage removed relative to entering N (`NA` for
#'     header; for final row: percentage retained of original N)}
#' }
#' @seealso [as_attrition_table()] for formatted table output.
#' @export
#'
#' @examples
#' dat  <- mock_cohortflow(n_participants = 200, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ !is.na(age),        label = "Age recorded",       category = "Age") |>
#'   include(~ age >= 18,          label = "Adults only",         category = "Age") |>
#'   include(~ eligible_screen,    label = "Passed screening",    category = "Screening") |>
#'   exclude(~ withdrew,           label = "Withdrew consent")
#' flow <- apply_criteria(dat, crit)
#' as_attrition_tibble(flow)
as_attrition_tibble <- function(
  flow,
  show_categories = TRUE,
  assessed_label  = "Assessed for eligibility",
  final_label     = "Final cohort",
  digits          = 1L
) {
  if (!inherits(flow, "cf_flow")) {
    rlang::abort("`flow` must be a `cf_flow` object.")
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
    pct_removed  = NA_real_
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
    pct_removed  = round(100 * n_end / n_start, digits)
  )))

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

      rows <- c(rows, list(tibble::tibble(
        row_type     = "category",
        label        = cat,
        indent_level = 1L,
        n            = n_in_cat,
        n_removed    = n_fail_cat,
        pct_removed  = pct_removed
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
    pct_removed  = pct
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
#'   include(~ !is.na(age),     label = "Age recorded",    category = "Age") |>
#'   include(~ age >= 18,       label = "Adults only",      category = "Age") |>
#'   include(~ eligible_screen, label = "Passed screening") |>
#'   exclude(~ withdrew,        label = "Withdrew consent")
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
  pct_col_label       = "% removed"
) {
  backend <- match.arg(backend)

  tbl <- as_attrition_tibble(
    flow,
    show_categories = show_categories,
    assessed_label  = assessed_label,
    final_label     = final_label,
    digits          = digits
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
    is.na(tbl$pct_removed) | tbl$pct_removed == 0 ~ "\u2014",
    TRUE                                   ~ paste0(tbl$pct_removed, "%")
  )

  n_removed_str <- dplyr::case_when(
    tbl$row_type %in% c("header", "final") ~ NA_character_,
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
  header_rows <- which(tbl$row_type == "header")
  final_rows  <- which(tbl$row_type == "final")
  cat_rows    <- which(tbl$row_type == "category")
  step1_rows  <- which(tbl$row_type == "step" & tbl$indent_level == 1L)
  step2_rows  <- which(tbl$row_type == "step" & tbl$indent_level == 2L)

  border_dark  <- officer::fp_border(color = "#555555", width = 1.0)
  border_light <- officer::fp_border(color = "#BBBBBB", width = 0.5)

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
    # Column header row
    flextable::bold(part = "header") |>
    flextable::bg(bg = "#E8E8E8", part = "header") |>
    # Header / final data rows: bold, light blue tint
    flextable::bold(i = c(header_rows, final_rows)) |>
    flextable::bg(i = c(header_rows, final_rows), bg = "#DDEEFF") |>
    # Category rows: bold label, light grey tint
    flextable::bold(i = cat_rows, j = "label") |>
    flextable::bg(i = cat_rows, bg = "#F5F5F5") |>
    # Indentation via left cell padding (pts)
    flextable::padding(i = step1_rows, j = "label", padding.left = 12L,
                       part = "body") |>
    flextable::padding(i = step2_rows, j = "label", padding.left = 24L,
                       part = "body") |>
    # Borders
    flextable::border_outer(part = "all",  border = border_dark) |>
    flextable::border_outer(part = "head", border = border_dark) |>
    flextable::hline_bottom(part = "head", border = border_dark) |>
    flextable::hline(part = "body", border = border_light) |>
    # Final row: top rule to separate from steps
    flextable::hline(i = min(final_rows) - 1L, part = "body",
                     border = border_dark) |>
    # Typography
    flextable::fontsize(size = 10, part = "all") |>
    flextable::font(fontname = "Arial", part = "all")

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
  header_rows <- which(tbl$row_type == "header")
  final_rows  <- which(tbl$row_type == "final")
  cat_rows    <- which(tbl$row_type == "category")
  step1_rows  <- which(tbl$row_type == "step" & tbl$indent_level == 1L)
  step2_rows  <- which(tbl$row_type == "step" & tbl$indent_level == 2L)

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
    # Header / final rows: bold + light blue background
    gt::tab_style(
      style     = list(gt::cell_fill(color = "#DDEEFF"),
                       gt::cell_text(weight = "bold")),
      locations = gt::cells_body(rows = c(header_rows, final_rows))
    ) |>
    # Category rows: bold label + light grey background
    gt::tab_style(
      style     = list(gt::cell_fill(color = "#F5F5F5"),
                       gt::cell_text(weight = "bold")),
      locations = gt::cells_body(rows = cat_rows, columns = "label")
    ) |>
    gt::tab_style(
      style     = gt::cell_fill(color = "#F5F5F5"),
      locations = gt::cells_body(rows = cat_rows)
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
                                   color = "#555555", weight = gt::px(2)),
      locations = gt::cells_body(rows = min(final_rows))
    ) |>
    # Column header style
    gt::tab_style(
      style     = list(gt::cell_fill(color = "#E8E8E8"),
                       gt::cell_text(weight = "bold")),
      locations = gt::cells_column_labels()
    ) |>
    # Table-level options
    gt::tab_options(
      table.font.size        = gt::px(10),
      table.font.names       = "Arial",
      table.border.top.color = "#555555",
      table.border.top.width = gt::px(1),
      table_body.border.bottom.color = "#555555",
      column_labels.border.bottom.color = "#555555",
      column_labels.border.bottom.width = gt::px(1),
      data_row.padding       = gt::px(4)
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
  header_rows <- which(tbl$row_type == "header")   + 1L
  final_rows  <- which(tbl$row_type == "final")    + 1L
  cat_rows    <- which(tbl$row_type == "category") + 1L
  step1_rows  <- which(tbl$row_type == "step" & tbl$indent_level == 1L) + 1L
  step2_rows  <- which(tbl$row_type == "step" & tbl$indent_level == 2L) + 1L

  ht <- huxtable::as_hux(df, add_colnames = TRUE) |>
    huxtable::set_header_rows(1, TRUE) |>
    huxtable::set_contents(1, 1, criterion_col_label) |>
    huxtable::set_contents(1, 2, n_col_label) |>
    huxtable::set_contents(1, 3, removed_col_label) |>
    huxtable::set_contents(1, 4, pct_col_label) |>
    # Alignment
    huxtable::set_align(huxtable::everywhere, 2:4, "right") |>
    huxtable::set_align(huxtable::everywhere, 1,   "left") |>
    # Column header row
    huxtable::set_bold(1, huxtable::everywhere, TRUE) |>
    huxtable::set_background_color(1, huxtable::everywhere, "#E8E8E8") |>
    # Header / final data rows
    huxtable::set_bold(c(header_rows, final_rows), huxtable::everywhere, TRUE) |>
    huxtable::set_background_color(c(header_rows, final_rows),
                                   huxtable::everywhere, "#DDEEFF") |>
    # Category rows
    huxtable::set_bold(cat_rows, 1, TRUE) |>
    huxtable::set_background_color(cat_rows, huxtable::everywhere, "#F5F5F5") |>
    # Indentation via left padding (pts)
    huxtable::set_left_padding(step1_rows, 1, 12) |>
    huxtable::set_left_padding(step2_rows, 1, 24) |>
    # Borders
    huxtable::set_outer_borders(0.8) |>
    huxtable::set_bottom_border(huxtable::everywhere, huxtable::everywhere, 0.3) |>
    huxtable::set_bottom_border(1, huxtable::everywhere, 0.8) |>
    # Separator above final row
    huxtable::set_top_border(min(final_rows), huxtable::everywhere, 0.8) |>
    # Typography
    huxtable::set_font_size(huxtable::everywhere, huxtable::everywhere, 10) |>
    huxtable::set_width(1)

  ht
}
