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

# Build the exclusion-box label lines for a main-flow group. Returns a
# character vector -- one element per line (header, then one per reason) --
# so that each item can be wrapped independently and always starts on its
# own new line in the rendered box, rather than being merged into a single
# re-flowed paragraph.
.consort_excl_lines <- function(group, digits) {
  r   <- group$row
  pct <- if (!is.na(r$pct_removed)) sprintf(", %.*f%%", digits, r$pct_removed) else ""
  header <- sprintf("Excluded (n = %d%s):", r$n_removed, pct)

  if (length(group$children) == 0L) return(header)

  reason_lines <- vapply(group$children, function(cr) {
    cr_pct <- if (!is.na(cr$pct_removed)) sprintf(" (%.*f%%)", digits, cr$pct_removed) else ""
    sprintf("\u2022 %s: n = %d%s", cr$label, cr$n_removed, cr_pct)
  }, character(1L))

  c(header, reason_lines)
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

# Estimate a box's width/height (in npc-like plot coordinates) from its
# label text, so that each box is sized to fit its own content rather than
# every box sharing one large fixed size. Labels are never reflowed/wrapped
# here -- each line in `label` (split on "\n") is measured as-is and the
# box grows to fit the longest line and the number of lines. This is a
# character-count heuristic (not exact text measurement), tuned to look
# reasonable at the default text size across typical device sizes. The
# surrounding plot's x/y scale limits are computed dynamically from the
# resulting box extents, so there is no fixed maximum box size here.
.consort_box_dims <- function(
  label,
  min_w  = 0.14,
  min_h  = 0.045,
  char_w = 0.0105,
  line_h = 0.038,
  pad_w  = 0.03,
  pad_h  = 0.018
) {
  lines     <- strsplit(label, "\n", fixed = TRUE)[[1L]]
  n_lines   <- max(length(lines), 1L)
  max_chars <- max(nchar(lines), 1L)

  list(
    w = max(min_w, max_chars * char_w + pad_w),
    h = max(min_h, n_lines * line_h + pad_h)
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
#'   include(~ !is.na(age),     label = "Age recorded",    category = "Age") |>
#'   include(~ age >= 18,       label = "Adults only",     category = "Age") |>
#'   exclude(~ withdrew,        label = "Withdrew consent")
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
  title_colour     = text_colour
) {
  if (!inherits(flow, "cf_flow")) {
    rlang::abort("`flow` must be a `cf_flow` object.")
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
  main_x   <- 0.30
  excl_x   <- 0.78
  text_pad <- 0.015

  main_rows        <- vector("list", n_main)
  main_arrow_rows  <- list()
  excl_rows        <- list()
  excl_arrow_rows  <- list()

  for (i in seq_len(n_main)) {
    g <- groups[[i]]
    r <- g$row

    label <- sprintf("%s\n(n = %d)", r$label, r$n)
    dims  <- .consort_box_dims(label)
    main_rows[[i]] <- data.frame(
      id = paste0("main_box_", i), x = main_x, y = main_y[i],
      w = dims$w, h = dims$h, label = label,
      stringsAsFactors = FALSE
    )

    if (i > 1L) {
      main_arrow_rows[[length(main_arrow_rows) + 1L]] <- data.frame(
        id = paste0("main_arrow_", i), x = main_x,
        y0 = main_y[i - 1L] - main_rows[[i - 1L]]$h / 2,
        y1 = main_y[i] + main_rows[[i]]$h / 2
      )
    }

    if (!is.na(r$n_removed) && r$n_removed > 0L) {
      excl_label <- paste(.consort_excl_lines(g, digits), collapse = "\n")
      excl_dims  <- .consort_box_dims(excl_label)

      # Branch the exclusion arrow off the main vertical connector at the
      # midpoint between this main box and the next one, so it visibly
      # comes out *in between* the two main-flow boxes (classic CONSORT
      # style) rather than from the side of a box. For the last main box
      # (no "next" box below it), fall back to branching level with the
      # box itself.
      branch_y <- if (i < n_main) mean(c(main_y[i], main_y[i + 1L])) else main_y[i]

      excl_arrow_rows[[length(excl_arrow_rows) + 1L]] <- data.frame(
        id = paste0("excl_arrow_", i),
        x0 = main_x, x1 = excl_x - excl_dims$w / 2, y = branch_y
      )

      excl_rows[[length(excl_rows) + 1L]] <- data.frame(
        id = paste0("excl_box_", i), x = excl_x, y = branch_y,
        w = excl_dims$w, h = excl_dims$h, label = excl_label,
        stringsAsFactors = FALSE
      )
    }
  }

  main_df    <- do.call(rbind, main_rows)
  main_arrow_df <- if (length(main_arrow_rows)) {
    do.call(rbind, main_arrow_rows)
  } else {
    .consort_empty_df(c("id", "x", "y0", "y1"))
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

  # Since box sizes now grow to fit their (unwrapped) label text, they can
  # extend beyond the nominal [0, 1] layout space used to position box
  # centres. Compute the actual left/right/top/bottom extents across all
  # boxes and pad the plot's coordinate limits accordingly, so nothing is
  # clipped and the diagram remains centred/proportioned around the boxes.
  x_left   <- c(main_df$x - main_df$w / 2, excl_df$x - excl_df$w / 2)
  x_right  <- c(main_df$x + main_df$w / 2, excl_df$x + excl_df$w / 2)
  y_bottom <- c(main_df$y - main_df$h / 2, excl_df$y - excl_df$h / 2)
  y_top    <- c(main_df$y + main_df$h / 2, excl_df$y + excl_df$h / 2)

  x_pad <- 0.02
  y_pad <- 0.02
  xlim  <- c(min(c(0, x_left)) - x_pad, max(c(1, x_right)) + x_pad)
  ylim  <- c(min(c(0, y_bottom)) - y_pad, max(c(1, y_top)) + y_pad)

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
    main_boxes   = main_df,
    excl_boxes   = excl_df,
    main_arrows  = main_arrow_df,
    excl_arrows  = excl_arrow_df,
    has_title    = !is.null(title)
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
