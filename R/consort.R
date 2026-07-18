# ===========================================================================
# CONSORT flow diagram output
# ===========================================================================

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Group the attrition tibble rows into main-flow rows (indent_level 0/1),
# each carrying its nested indent_level-2 sub-rows (if any).
.consort_group_rows <- function(tbl) {
  groups <- list()
  current <- NULL
  for (i in seq_len(nrow(tbl))) {
    r <- tbl[i, ]
    if (r$indent_level %in% c(0L, 1L)) {
      if (!is.null(current)) groups[[length(groups) + 1L]] <- current
      current <- list(row = r, children = list())
    } else {
      current$children[[length(current$children) + 1L]] <- r
    }
  }
  if (!is.null(current)) groups[[length(groups) + 1L]] <- current
  groups
}

# Format a count for display, inserting a thousands-separator (`big_mark`)
# so large numbers are easier to scan (e.g. "1,234" rather than "1234").
# Pass `big_mark = ""` to disable grouping altogether. This is the single
# place all box labels route their counts through, so the separator (and
# any future formatting behaviour) stays consistent everywhere "n=..."
# text is rendered.
.format_n <- function(n, big_mark = ",") {
  formatC(n, format = "d", big.mark = big_mark)
}

# Derive the effective n_removed/pct_removed for a main-flow group -- uses
# the parent row's values when available, falling back to summing child
# rows for singleton categories (where the parent row's n_removed is NA to
# avoid duplicating the child's count in tabular output). `n_removed` is
# always a non-NA integer (0L when the group has no exclusions at all),
# so callers can use it directly in arithmetic (e.g. to compute survivor
# counts) without an extra NA check. Shared by `.consort_has_exclusions()`,
# `.consort_excl_lines()`, and the main-box survivor-count calculation so
# the derivation logic lives in exactly one place.
.consort_group_removal <- function(group) {
  r <- group$row
  has_children <- length(group$children) > 0L

  n_removed   <- r$n_removed
  pct_removed <- r$pct_removed

  if (is.na(n_removed) && has_children) {
    # Singleton category: derive from child rows
    n_removed <- sum(vapply(group$children, `[[`, integer(1L), "n_removed"))
    # For singleton, pct_removed comes from the single child
    pct_removed <- group$children[[1L]]$pct_removed
  }

  if (is.na(n_removed)) n_removed <- 0L

  list(n_removed = n_removed, pct_removed = pct_removed)
}

# Build the exclusion-box label lines for a main-flow group. Returns a
# character vector -- one element per line (header, then one per reason) --
# so that each item can be wrapped independently and always starts on its
# own new line in the rendered box, rather than being merged into a single
# re-flowed paragraph.
.consort_excl_lines <- function(group, digits, big_mark = ",") {
  has_children <- length(group$children) > 0L
  removal      <- .consort_group_removal(group)

  pct <- if (!is.na(removal$pct_removed)) {
    sprintf(", %.*f%%", digits, removal$pct_removed)
  } else {
    ""
  }
  # Only add colon if there are child reason lines below
  header <- sprintf("Excluded (n=%s%s)%s", .format_n(removal$n_removed, big_mark), pct,
                    if (has_children) ":" else "")

  if (!has_children) return(header)

  reason_lines <- vapply(group$children, function(cr) {
    cr_pct <- if (!is.na(cr$pct_removed)) sprintf(", %.*f%%", digits, cr$pct_removed) else ""
    sprintf("\u2022 %s (n=%s%s)", cr$label, .format_n(cr$n_removed, big_mark), cr_pct)
  }, character(1L))

  c(header, reason_lines)
}

# Determine whether a main-flow group should have an exclusion box drawn.
# Returns TRUE if the group has any exclusions (either from the parent row
# or from child rows for singleton categories).
.consort_has_exclusions <- function(group) {
  .consort_group_removal(group)$n_removed > 0L
}


# Build an empty placeholder data frame with the given column names, used
# when a particular geom layer (e.g. exclusion boxes) has no rows to draw.
# `cols` may be a plain character vector (all columns default to character),
# or a named list mapping column name to an empty vector of the desired
# type (e.g. list(id = character(0L), x = numeric(0L))) so that downstream
# arithmetic on numeric columns (e.g. `w / 2`) doesn't error even when the
# data frame has zero rows.
.consort_empty_df <- function(cols) {
  if (is.list(cols) && !is.null(names(cols))) {
    return(as.data.frame(cols))
  }
  as.data.frame(stats::setNames(rep(list(character(0L)), length(cols)), cols))
}

# Wrap a single line of text to a maximum character width. Returns a
# character vector of wrapped lines. Uses a simple word-boundary approach:
# splits on spaces, then greedily packs words onto lines without exceeding
# `width` characters. If a single word exceeds `width`, it is kept intact
# on its own line (never broken mid-word).
.wrap_text_line <- function(line, width) {
  if (nchar(line) <= width) return(line)
  words <- strsplit(line, " ", fixed = TRUE)[[1L]]
  lines <- character(0L)
  current <- ""
  for (w in words) {
    if (nchar(current) == 0L) {
      current <- w
    } else if (nchar(current) + 1L + nchar(w) <= width) {
      current <- paste(current, w)
    } else {
      lines <- c(lines, current)
      current <- w
    }
  }
  if (nchar(current) > 0L) lines <- c(lines, current)
  lines
}

# Wrap all lines in a label (split on "\n") to a maximum character width.
# Returns the wrapped label as a single string with "\n" separators.
# If `wrap_width` is NULL, returns the label unchanged.
.wrap_label <- function(label, wrap_width) {
  if (is.null(wrap_width)) return(label)
  lines <- strsplit(label, "\n", fixed = TRUE)[[1L]]
  wrapped <- unlist(lapply(lines, .wrap_text_line, width = wrap_width))
  paste(wrapped, collapse = "\n")
}

# Estimate a box's width/height (in npc-like plot coordinates) from its
# label text, so that each box is sized to fit its own content rather than
# every box sharing one large fixed size. When `wrap_width` is NULL, each
# line in `label` (split on "\n") is measured as-is and the box grows to
# fit the longest line and the number of lines. When `wrap_width` is a
# positive integer, lines are first wrapped to that character width before
# measurement. This is a character-count heuristic (not exact text
# measurement), tuned to look reasonable at the default text size across
# typical device sizes. The surrounding plot's x/y scale limits are
# computed dynamically from the resulting box extents, so there is no
# fixed maximum box size here.
.consort_box_dims <- function(
  label,
  wrap_width = NULL,
  min_w  = 0.14,
  min_h  = 0.045,
  char_w = 0.0105,
  line_h = 0.038,
  pad_w  = 0.03,
  pad_h  = 0.018
) {
  label <- .wrap_label(label, wrap_width)
  lines     <- strsplit(label, "\n", fixed = TRUE)[[1L]]
  n_lines   <- max(length(lines), 1L)
  max_chars <- max(nchar(lines), 1L)

  list(
    w = max(min_w, max_chars * char_w + pad_w),
    h = max(min_h, n_lines * line_h + pad_h),
    label = label
  )
}


# ---------------------------------------------------------------------------
# as_consort_diagram() -- build the diagram
# ---------------------------------------------------------------------------

#' Build a CONSORT flow diagram from a cohort flow object
#'
#' Produces a CONSORT-style flow diagram (as used in clinical trial and
#' cohort study reporting) summarising participant flow through a `cf_flow`
#' pipeline. The main vertical flow shows the number of participants
#' entering the study and surviving each step (or category, when
#' `show_categories = TRUE`), while exclusions at each step branch off to
#' the side as a box giving the count, percentage, and (for categorised
#' steps) the individual exclusion reasons.
#'
#' This uses the same underlying data layer as [as_attrition_table()] --
#' [as_attrition_tibble()] -- so the row structure (header, category, step,
#' final) is identical across all three output types.
#'
#' The returned object is a [ggplot2::ggplot()] plot (with an additional
#' `consort_diagram` class), so it can be drawn with `print()`, combined
#' with `+` and further `ggplot2` layers/themes, or exported with
#' [ggplot2::ggsave()] or by opening an appropriate graphics device (e.g.
#' [grDevices::png()]) before drawing.
#'
#' @inheritParams as_attrition_tibble
#' @param main_fill Fill colour for main-flow boxes. Default `NA` (no
#'   fill / transparent), keeping the diagram colourless unless a fill is
#'   explicitly supplied.
#' @param excl_fill Fill colour for exclusion (side) boxes. Default `NA`
#'   (no fill / transparent).
#' @param border_colour Border colour for all boxes and arrows. Default
#'   `"#000000"` (black).
#' @param border_linewidth Line width for all box borders and arrows,
#'   passed on to [ggplot2::geom_rect()] / [ggplot2::geom_segment()].
#'   Default `0.5` (the `ggplot2` default line width).
#' @param text_size Font size (points) for box text. Default `9`.
#' @param text_colour Colour for all box text (and the title, unless
#'   `title_colour` is supplied). Default `"#222222"`.
#' @param font_family Font family for all box text and the title. Default
#'   `""` (the device's default font family).
#' @param title Optional plot title drawn above the diagram. Default `NULL`
#'   (no title).
#' @param title_colour Colour for the title text. Default `text_colour`.
#' @param wrap_width Optional integer. Maximum character width for wrapping
#'   text in boxes. When `NULL` (default), text is not wrapped. When a
#'   positive integer, each line in a box label is wrapped to at most that
#'   many characters using word-boundary wrapping.
#' @param big_mark Character string used as the thousands-separator when
#'   formatting counts in box labels (e.g. `"1,234"` with the default
#'   `","`). Pass `""` to disable grouping (e.g. `"1234"`).
#' @param branch_by Optional column name (string) for allocation branching.
#'   When `NULL` (default), the diagram is linear. When supplied, the
#'   surviving cohort is split by this column and branches are drawn below
#'   the final common-flow box, connected via a right-angle "elbow"
#'   connector (a trunk dropping from the final box, a horizontal crossbar,
#'   then a vertical arrow into each branch box). Use
#'   `final_label = "Randomised"` when appropriate.
#' @param stage_by Optional column name (string) for ordered stages within
#'   each branch (e.g. crossover `period`). When `NULL` (default), no
#'   stage-specific nodes are drawn.
#' @param stage_label_by Optional column name (string) providing labels for
#'   each stage (e.g. crossover `arm`). Ignored when `stage_by` is `NULL`.
#' @param count_by Optional column name (string) for distinct counts. When
#'   supplied, counts are computed as `n_distinct(count_by)` rather than
#'   `nrow()`. Essential for crossover data where one participant has
#'   several event rows.
#'

#' @return A `consort_diagram` object (a `ggplot2` `ggplot`), drawable via
#'   `print()`. The underlying box/arrow layout data frames are available
#'   via `attr(x, "consort_layout")` for introspection or custom rendering.
#' @seealso [as_attrition_tibble()] for the underlying plain-tibble data
#'   layer, [as_attrition_table()] for formatted table output.
#' @export
#'
#' @examples
#' dat  <- mock_cohortflow(n_participants = 200, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ !is.na(age),          label = "Age recorded",    category = "Valid age") |>
#'   include(~ age >= 18,            label = "Adults only",     category = "Valid age") |>
#'   include(~ !is.na(consent_date), label = "Consent recorded", category = "Consent") |>
#'   exclude(~ withdrew,             label = "Withdrew consent", category = "Consent")
#' flow <- apply_criteria(dat, crit)
#' as_consort_diagram(flow)
as_consort_diagram <- function(
  flow,
  show_categories = TRUE,
  assessed_label  = "Assessed for eligibility",
  final_label     = "Final cohort",
  digits          = 1L,
  main_fill        = NA,
  excl_fill        = NA,
  border_colour    = "black",
  border_linewidth = 0.5,
  text_size        = 9,
  text_colour      = "#222222",
  font_family      = "",
  title            = NULL,
  title_colour     = text_colour,
  wrap_width       = NULL,
  big_mark         = ",",
  branch_by        = NULL,
  stage_by         = NULL,
  stage_label_by   = NULL,
  count_by         = NULL
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
  if (!is.null(stage_by) && is.null(branch_by)) {
    rlang::abort("`stage_by` requires `branch_by` to be specified.")
  }
  if (!is.null(stage_label_by) && is.null(stage_by)) {
    rlang::abort("`stage_label_by` requires `stage_by` to be specified.")
  }

  tbl <- as_attrition_tibble(
    flow,
    show_categories = show_categories,
    assessed_label  = assessed_label,
    final_label     = final_label,
    digits          = digits
  )

  groups <- .consort_group_rows(tbl)
  n_main <- length(groups)

  top      <- 0.94
  bottom   <- 0.06
  main_y   <- if (n_main > 1L) seq(top, bottom, length.out = n_main) else 0.5
  main_x   <- 0.24
  gap_x    <- 0.08
  text_pad <- 0.015

  # -- Pass 1: main boxes -- positions are known up-front (fixed x, main_y[i])
  # Each box displays the *surviving* count after that row's own exclusions
  # are removed (r$n - n_removed), not the entering count, so that a box's
  # exclusions are always shown branching off *before* the box in the main
  # flow (matching standard CONSORT convention) rather than appearing to
  # have already happened without being drawn.
  main_rows <- vector("list", n_main)
  for (i in seq_len(n_main)) {
    r <- groups[[i]]$row
    n_removed <- .consort_group_removal(groups[[i]])$n_removed
    n_survive <- r$n - n_removed
    label <- sprintf("%s\n(n=%s)", r$label, .format_n(n_survive, big_mark))
    dims  <- .consort_box_dims(label, wrap_width = wrap_width)
    main_rows[[i]] <- data.frame(
      id = paste0("main_box_", i), x = main_x, y = main_y[i],
      w = dims$w, h = dims$h, label = dims$label,
      stringsAsFactors = FALSE
    )
  }
  main_df <- do.call(rbind, main_rows)

  main_arrow_rows <- list()
  for (i in seq_len(n_main)) {
    if (i > 1L) {
      main_arrow_rows[[length(main_arrow_rows) + 1L]] <- data.frame(
        id = paste0("main_arrow_", i), x = main_x,
        y0 = main_df$y[i - 1L] - main_df$h[i - 1L] / 2,
        y1 = main_df$y[i] + main_df$h[i] / 2
      )
    }
  }
  main_arrow_df <- if (length(main_arrow_rows)) {
    do.call(rbind, main_arrow_rows)
  } else {
    .consort_empty_df(c("id", "x", "y0", "y1"))
  }

  # -- Pass 2: exclusion box label/dims (position depends on max width) -----
  # Computing dims for every exclusion box before positioning lets us place
  # the whole column of exclusion boxes just far enough right of the widest
  # main-flow box (`gap_x` clearance), rather than at a fixed x -- this is
  # what keeps the diagram from leaving excess whitespace on the right when
  # box content is narrow.
  excl_info <- vector("list", n_main)
  for (i in seq_len(n_main)) {
    g <- groups[[i]]
    if (.consort_has_exclusions(g)) {
      excl_label <- paste(.consort_excl_lines(g, digits, big_mark), collapse = "\n")
      excl_info[[i]] <- .consort_box_dims(excl_label, wrap_width = wrap_width)
    }
  }

  has_excl_idx <- !vapply(excl_info, is.null, logical(1L))
  excl_x <- NA_real_
  if (any(has_excl_idx)) {
    excl_widths <- vapply(excl_info[has_excl_idx], `[[`, numeric(1L), "w")
    main_right_edge <- max(main_df$x + main_df$w / 2)
    excl_x <- main_right_edge + gap_x + max(excl_widths) / 2
  }

  excl_rows       <- list()
  excl_arrow_rows <- list()
  for (i in seq_len(n_main)) {
    if (!is.null(excl_info[[i]])) {
      excl_dims <- excl_info[[i]]

      # Branch the exclusion arrow off the main vertical connector at the
      # midpoint between the *previous* main box and this one, so it
      # visibly comes out *before* the box whose survivor count already
      # reflects the exclusion (classic CONSORT style: exclusions are
      # shown leaving the flow before the box that represents what's left
      # after them), meeting the vertical trunk at a right angle. For the
      # first main box (no "previous" box above it -- not expected in
      # practice since the header row never has exclusions), fall back to
      # branching level with the box itself.
      branch_y <- if (i > 1L) mean(c(main_y[i - 1L], main_y[i])) else main_y[i]

      excl_arrow_rows[[length(excl_arrow_rows) + 1L]] <- data.frame(
        id = paste0("excl_arrow_", i),
        x0 = main_x, x1 = excl_x - excl_dims$w / 2, y = branch_y
      )

      excl_rows[[length(excl_rows) + 1L]] <- data.frame(
        id = paste0("excl_box_", i), x = excl_x, y = branch_y,
        w = excl_dims$w, h = excl_dims$h, label = excl_dims$label,
        stringsAsFactors = FALSE
      )
    }
  }

  excl_df <- if (length(excl_rows)) {
    do.call(rbind, excl_rows)
  } else {
    .consort_empty_df(list(
      id = character(0L), x = numeric(0L), y = numeric(0L),
      w = numeric(0L), h = numeric(0L), label = character(0L)
    ))
  }
  excl_arrow_df <- if (length(excl_arrow_rows)) {
    do.call(rbind, excl_arrow_rows)
  } else {
    .consort_empty_df(c("id", "x0", "x1", "y"))
  }

  # -- Branching logic ------------------------------------------------------
  branch_df <- .consort_empty_df(list(
    id = character(0L), x = numeric(0L), y = numeric(0L),
    w = numeric(0L), h = numeric(0L), label = character(0L),
    branch = character(0L)
  ))
  branch_arrow_df <- .consort_empty_df(c("id", "x", "y0", "y1"))
  branch_connector_df <- .consort_empty_df(c("id", "x0", "x1", "y0", "y1"))
  stage_df <- .consort_empty_df(list(
    id = character(0L), x = numeric(0L), y = numeric(0L),
    w = numeric(0L), h = numeric(0L), label = character(0L),
    branch = character(0L), stage = character(0L)
  ))
  stage_arrow_df <- .consort_empty_df(c("id", "x", "y0", "y1"))

  if (!is.null(branch_by)) {
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
    n_branches <- length(branch_values)

    final_box <- main_df[nrow(main_df), ]
    trunk_y0  <- final_box$y - final_box$h / 2

    # Spread branches horizontally
    branch_spacing <- 0.25
    branch_x_start <- main_x - (n_branches - 1) * branch_spacing / 2
    branch_xs <- seq(branch_x_start,
                     branch_x_start + (n_branches - 1) * branch_spacing,
                     length.out = n_branches)

    # First compute each branch box's label/dims (position comes next)
    branch_dims_list <- vector("list", n_branches)
    for (b in seq_len(n_branches)) {
      branch_val  <- branch_values[b]
      branch_data <- cohort_data[cohort_data[[branch_by]] == branch_val, ]
      branch_n    <- count_fn(branch_data)
      label <- sprintf("%s\n(n=%s)", branch_val, .format_n(branch_n, big_mark))
      branch_dims_list[[b]] <- .consort_box_dims(label, wrap_width = wrap_width)
    }

    max_branch_h <- max(vapply(branch_dims_list, `[[`, numeric(1L), "h"))

    # Right-angle "elbow" connector: a trunk drops straight down from the
    # final box, a horizontal crossbar spans the branch x-positions, and a
    # vertical arrow drops from the crossbar into each branch box -- so
    # every segment meets its neighbour at a right angle (classic CONSORT
    # split styling) instead of a single diagonal line per branch.
    gap_total  <- 0.08
    gutter_y   <- trunk_y0 - gap_total / 2
    branch_top <- gutter_y - gap_total / 2
    branch_y   <- branch_top - max_branch_h / 2

    branch_rows <- list()
    branch_arrow_rows <- list()

    for (b in seq_len(n_branches)) {
      branch_val <- branch_values[b]
      dims <- branch_dims_list[[b]]

      branch_rows[[b]] <- data.frame(
        id = paste0("branch_box_", b),
        x = branch_xs[b],
        y = branch_y,
        w = dims$w,
        h = dims$h,
        label = dims$label,
        branch = as.character(branch_val),
        stringsAsFactors = FALSE
      )

      # Vertical arrow from the shared crossbar into this branch box
      branch_arrow_rows[[b]] <- data.frame(
        id = paste0("branch_arrow_", b),
        x = branch_xs[b],
        y0 = gutter_y,
        y1 = branch_y + dims$h / 2,
        stringsAsFactors = FALSE
      )
    }

    branch_df <- do.call(rbind, branch_rows)
    branch_arrow_df <- do.call(rbind, branch_arrow_rows)

    branch_connector_df <- if (n_branches > 1L) {
      rbind(
        data.frame(id = "branch_trunk", x0 = final_box$x, x1 = final_box$x,
                   y0 = trunk_y0, y1 = gutter_y, stringsAsFactors = FALSE),
        data.frame(id = "branch_crossbar", x0 = min(branch_xs), x1 = max(branch_xs),
                   y0 = gutter_y, y1 = gutter_y, stringsAsFactors = FALSE)
      )
    } else {
      data.frame(id = "branch_trunk", x0 = final_box$x, x1 = final_box$x,
                y0 = trunk_y0, y1 = gutter_y, stringsAsFactors = FALSE)
    }

    # -- Stage nodes (for crossover designs) --------------------------------
    if (!is.null(stage_by)) {
      if (!stage_by %in% names(cohort_data)) {
        rlang::abort(sprintf("Column `%s` not found in surviving cohort.", stage_by))
      }
      if (!is.null(stage_label_by) && !stage_label_by %in% names(cohort_data)) {
        rlang::abort(sprintf("Column `%s` not found in surviving cohort.", stage_label_by))
      }

      stage_rows <- list()
      stage_arrow_rows <- list()
      row_idx <- 1L

      for (b in seq_len(n_branches)) {
        branch_val <- branch_values[b]
        branch_data <- cohort_data[cohort_data[[branch_by]] == branch_val, ]

        # Get unique stages in order
        stages <- sort(unique(branch_data[[stage_by]]))
        n_stages <- length(stages)

        stage_y_start <- branch_y - branch_df$h[b] / 2 - 0.06
        stage_spacing <- 0.08

        for (s in seq_len(n_stages)) {
          stage_val <- stages[s]
          stage_data <- branch_data[branch_data[[stage_by]] == stage_val, ]

          # Label: use stage_label_by if provided, otherwise stage value
          if (!is.null(stage_label_by)) {
            # Get the most common label for this stage
            labels <- stage_data[[stage_label_by]]
            stage_label <- names(sort(table(labels), decreasing = TRUE))[1]
          } else {
            stage_label <- as.character(stage_val)
          }

          stage_n <- count_fn(stage_data)
          label <- sprintf("%s\n(n=%s)", stage_label, .format_n(stage_n, big_mark))
          dims <- .consort_box_dims(label, wrap_width = wrap_width)

          stage_y <- stage_y_start - (s - 1) * stage_spacing

          stage_rows[[row_idx]] <- data.frame(
            id = paste0("stage_box_", b, "_", s),
            x = branch_xs[b],
            y = stage_y,
            w = dims$w,
            h = dims$h,
            label = dims$label,
            branch = as.character(branch_val),
            stage = as.character(stage_val),
            stringsAsFactors = FALSE
          )

          # Arrow from branch box to first stage, or from previous stage
          if (s == 1L) {
            arrow_y0 <- branch_y - branch_df$h[b] / 2
          } else {
            prev_stage <- stage_rows[[row_idx - 1L]]
            arrow_y0 <- prev_stage$y - prev_stage$h / 2
          }

          stage_arrow_rows[[row_idx]] <- data.frame(
            id = paste0("stage_arrow_", b, "_", s),
            x = branch_xs[b],
            y0 = arrow_y0,
            y1 = stage_y + dims$h / 2,
            stringsAsFactors = FALSE
          )

          row_idx <- row_idx + 1L
        }
      }

      if (length(stage_rows) > 0L) {
        stage_df <- do.call(rbind, stage_rows)
        stage_arrow_df <- do.call(rbind, stage_arrow_rows)
      }
    }
  }

  # Compute the actual left/right/top/bottom extents across all boxes and
  # pad the plot's coordinate limits accordingly, so nothing is clipped and
  # the diagram remains centred/proportioned around the boxes. Use only the
  # actual box extents (not a fixed [0, 1] range) to avoid unnecessary
  # whitespace on the right side of the diagram.
  all_x_left   <- c(main_df$x - main_df$w / 2, excl_df$x - excl_df$w / 2,
                    branch_df$x - branch_df$w / 2, stage_df$x - stage_df$w / 2)
  all_x_right  <- c(main_df$x + main_df$w / 2, excl_df$x + excl_df$w / 2,
                    branch_df$x + branch_df$w / 2, stage_df$x + stage_df$w / 2)
  all_y_bottom <- c(main_df$y - main_df$h / 2, excl_df$y - excl_df$h / 2,
                    branch_df$y - branch_df$h / 2, stage_df$y - stage_df$h / 2)
  all_y_top    <- c(main_df$y + main_df$h / 2, excl_df$y + excl_df$h / 2,
                    branch_df$y + branch_df$h / 2, stage_df$y + stage_df$h / 2)

  x_pad <- 0.02
  y_pad <- 0.02
  xlim  <- c(min(all_x_left) - x_pad, max(all_x_right) + x_pad)
  ylim  <- c(min(all_y_bottom) - y_pad, max(all_y_top) + y_pad)

  gg <- ggplot2::ggplot()

  if (nrow(main_arrow_df) > 0L) {
    gg <- gg + ggplot2::geom_segment(
      data = main_arrow_df,
      mapping = ggplot2::aes(x = .data$x, xend = .data$x, y = .data$y0, yend = .data$y1),
      colour = border_colour, linewidth = border_linewidth,
      arrow = grid::arrow(length = grid::unit(0.1, "inches"), type = "closed")
    )
  }

  if (nrow(excl_arrow_df) > 0L) {
    gg <- gg + ggplot2::geom_segment(
      data = excl_arrow_df,
      mapping = ggplot2::aes(x = .data$x0, xend = .data$x1, y = .data$y, yend = .data$y),
      colour = border_colour, linewidth = border_linewidth,
      arrow = grid::arrow(length = grid::unit(0.1, "inches"), type = "closed")
    )
  }

  gg <- gg +
    ggplot2::geom_rect(
      data = main_df,
      mapping = ggplot2::aes(
        xmin = .data$x - .data$w / 2, xmax = .data$x + .data$w / 2,
        ymin = .data$y - .data$h / 2, ymax = .data$y + .data$h / 2
      ),
      fill = main_fill, colour = border_colour, linewidth = border_linewidth
    ) +
    ggplot2::geom_text(
      data = main_df,
      mapping = ggplot2::aes(x = .data$x, y = .data$y, label = .data$label),
      size = text_size / ggplot2::.pt, colour = text_colour,
      family = font_family, lineheight = 0.9, hjust = 0.5
    )

  if (nrow(excl_df) > 0L) {
    gg <- gg +
      ggplot2::geom_rect(
        data = excl_df,
        mapping = ggplot2::aes(
          xmin = .data$x - .data$w / 2, xmax = .data$x + .data$w / 2,
          ymin = .data$y - .data$h / 2, ymax = .data$y + .data$h / 2
        ),
        fill = excl_fill, colour = border_colour, linewidth = border_linewidth
      ) +
      ggplot2::geom_text(
        data = excl_df,
        mapping = ggplot2::aes(x = .data$x - .data$w / 2 + text_pad, y = .data$y, label = .data$label),
        size = (text_size * 0.9) / ggplot2::.pt, colour = text_colour,
        family = font_family, lineheight = 0.9, hjust = 0
      )
  }

  # -- Render branch connector (trunk + crossbar, no arrowhead) -------------
  if (nrow(branch_connector_df) > 0L) {
    gg <- gg + ggplot2::geom_segment(
      data = branch_connector_df,
      mapping = ggplot2::aes(x = .data$x0, xend = .data$x1, y = .data$y0, yend = .data$y1),
      colour = border_colour, linewidth = border_linewidth
    )
  }

  # -- Render branch boxes and arrows ---------------------------------------
  if (nrow(branch_arrow_df) > 0L) {
    gg <- gg + ggplot2::geom_segment(
      data = branch_arrow_df,
      mapping = ggplot2::aes(x = .data$x, xend = .data$x, y = .data$y0, yend = .data$y1),
      colour = border_colour, linewidth = border_linewidth,
      arrow = grid::arrow(length = grid::unit(0.1, "inches"), type = "closed")
    )
  }

  if (nrow(branch_df) > 0L) {
    gg <- gg +
      ggplot2::geom_rect(
        data = branch_df,
        mapping = ggplot2::aes(
          xmin = .data$x - .data$w / 2, xmax = .data$x + .data$w / 2,
          ymin = .data$y - .data$h / 2, ymax = .data$y + .data$h / 2
        ),
        fill = main_fill, colour = border_colour, linewidth = border_linewidth
      ) +
      ggplot2::geom_text(
        data = branch_df,
        mapping = ggplot2::aes(x = .data$x, y = .data$y, label = .data$label),
        size = text_size / ggplot2::.pt, colour = text_colour,
        family = font_family, lineheight = 0.9, hjust = 0.5
      )
  }

  # -- Render stage boxes and arrows ----------------------------------------
  if (nrow(stage_arrow_df) > 0L) {
    gg <- gg + ggplot2::geom_segment(
      data = stage_arrow_df,
      mapping = ggplot2::aes(x = .data$x, xend = .data$x, y = .data$y0, yend = .data$y1),
      colour = border_colour, linewidth = border_linewidth,
      arrow = grid::arrow(length = grid::unit(0.1, "inches"), type = "closed")
    )
  }

  if (nrow(stage_df) > 0L) {
    gg <- gg +
      ggplot2::geom_rect(
        data = stage_df,
        mapping = ggplot2::aes(
          xmin = .data$x - .data$w / 2, xmax = .data$x + .data$w / 2,
          ymin = .data$y - .data$h / 2, ymax = .data$y + .data$h / 2
        ),
        fill = main_fill, colour = border_colour, linewidth = border_linewidth
      ) +
      ggplot2::geom_text(
        data = stage_df,
        mapping = ggplot2::aes(x = .data$x, y = .data$y, label = .data$label),
        size = text_size / ggplot2::.pt, colour = text_colour,
        family = font_family, lineheight = 0.9, hjust = 0.5
      )
  }

  gg <- gg +
    ggplot2::scale_x_continuous(limits = xlim, expand = c(0, 0)) +
    ggplot2::scale_y_continuous(limits = ylim, expand = c(0, 0)) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::theme_void()

  if (!is.null(title)) {
    gg <- gg +
      ggplot2::labs(title = title) +
      ggplot2::theme(
        plot.title = ggplot2::element_text(
          colour = title_colour, size = text_size + 3, face = "bold",
          family = font_family, hjust = 0.5
        )
      )
  }

  attr(gg, "consort_layout") <- list(
    main_boxes         = main_df,
    excl_boxes         = excl_df,
    main_arrows        = main_arrow_df,
    excl_arrows        = excl_arrow_df,
    branch_boxes       = branch_df,
    branch_arrows      = branch_arrow_df,
    branch_connectors  = branch_connector_df,
    stage_boxes        = stage_df,
    stage_arrows       = stage_arrow_df,
    has_title          = !is.null(title)
  )

  class(gg) <- c("consort_diagram", class(gg))
  gg
}


# ---------------------------------------------------------------------------
# S3 methods
# ---------------------------------------------------------------------------

#' Print method for `consort_diagram` objects
#'
#' Draws a `consort_diagram` (produced by [as_consort_diagram()]) on the
#' current graphics device via the standard `ggplot2` print method (which
#' opens a new page before drawing).
#'
#' @param x A `consort_diagram` object.
#' @param ... Additional arguments passed on to [ggplot2::print.ggplot()].
#' @return `x`, invisibly.
#' @export
print.consort_diagram <- function(x, ...) {
  NextMethod()
  invisible(x)
}

#' Plot method for `cf_flow` objects
#'
#' A thin wrapper around [as_consort_diagram()] so that `plot(flow)` draws a
#' CONSORT flow diagram directly from a `cf_flow` object.
#'
#' @param x A `cf_flow` object produced by [apply_criteria()].
#' @param ... Additional arguments passed on to [as_consort_diagram()].
#' @return A `consort_diagram` object, invisibly printed.
#' @export
plot.cf_flow <- function(x, ...) {
  d <- as_consort_diagram(x, ...)
  print(d)
  invisible(d)
}