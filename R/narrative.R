# ===========================================================================
# Narrative (methods-section) text
# ===========================================================================

#' Describe a cohort flow in words, for a methods section
#'
#' Writes the attrition cascade as a short paragraph, ready to paste into
#' the participant-flow part of a methods or results section. The numbers
#' come from [as_attrition_tibble()] (and, after a [randomise()] step, from
#' the same per-arm re-application [as_consort_diagram()] uses), so the text
#' always agrees with the table and the diagram.
#'
#' @section Wording:
#' * One sentence per category (or per step with `show_categories = FALSE`,
#'   and for uncategorised steps). Category names group reasons into a
#'   sentence but are not themselves narrated. Steps and categories that
#'   removed nobody are left out.
#' * The first sentence opens "Of N <unit> <assessed_label>, ..."; later ones
#'   open "A further ...". Each gives the number removed and its percentage
#'   of those entering that category or step, then the reason(s): one reason
#'   in brackets, several as a list with their own counts. The last sentence
#'   before randomisation (or before the final sentence) ends ", leaving n".
#' * The removal text for each step is its `reason`. Exclusion steps default
#'   to their label; an inclusion step without a `reason` reads
#'   `not meeting "<label>"`.
#' * A [randomise()] step gives "The remaining n were randomised to A (n = a)
#'   and B (n = b)." Arms are in factor-level order (else sorted); a missing
#'   arm value forms an arm called "Missing", as in the diagram. After it,
#'   each sentence gives per-arm counts, with percentages of the number of
#'   that arm entering the step.
#' * The last sentence gives the final cohort and its percentage of those
#'   assessed, broken down by arm when there are arms.
#' * `count_by` changes what is counted but not the noun: set `unit` to match
#'   (e.g. `count_by = "participant_id", unit = "participants"` for a
#'   crossover trial with one row per participant-period).
#' * Grouped steps read like any other step; units removed only because their
#'   group was removed (`n_consequential`) are not narrated separately.
#'
#' Lists use the serial (Oxford) comma: "a, b, and c". The text is a starting
#' point: read it, and edit it to suit the journal's style.
#'
#' @inheritParams as_attrition_tibble
#' @param assessed_label Text after the starting count in the first
#'   sentence, as in "Of 200 participants *assessed for eligibility*".
#'   Default `"assessed for eligibility"`.
#' @param unit Plural noun for what is counted, used verbatim (it is not
#'   pluralised or inflected). Default `"participants"`.
#' @param count_by Optional hierarchy level to count instead of rows, passed
#'   to [as_attrition_tibble()] (see there). Set `unit` to match.
#' @param big_mark Thousands separator for counts (`"1,234"` with the default
#'   `","`); `""` turns grouping off.
#' @param digits Decimal places for percentages. Default `1`.
#' @param drop_randomise Logical. When `TRUE`, a [randomise()] step is
#'   ignored and everything is reported pooled, as if there were no arms.
#'   Default `FALSE`.
#' @param lowercase_reasons Logical. When `TRUE` (default), the first letter
#'   of each reason is lower-cased so it reads mid-sentence ("Age missing"
#'   becomes "age missing"), unless the first word looks like an acronym
#'   (its second letter is upper case, as in "BMI missing"). Quoted labels
#'   (`not meeting "<label>"`) are never changed.
#' @param style `"prose"` (default) for one paragraph, or `"bullets"` for one
#'   sentence per line, each starting `"- "` (Markdown list items).
#' @param x A `cf_narrative` object.
#' @param ... Ignored.
#'
#' @return A single string with class `c("cf_narrative", "character")`.
#'   Printing wraps it to the console width; in an R Markdown or Quarto chunk
#'   it is inserted as text. Use `as.character()` for the bare string.
#' @seealso [as_attrition_tibble()] and [as_consort_diagram()], which report
#'   the same numbers.
#' @family reporting
#' @export
#'
#' @examples
#' dat  <- mock_parallel_rct(n_participants = 200, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ !is.na(age), label = "Age recorded", reason = "Age missing", category = "Age") |>
#'   include(~ age >= 18, label = "Aged 18 or over", reason = "Under 18", category = "Age") |>
#'   include(~ !is.na(consent_date), label = "Consented", reason = "Did not consent") |>
#'   randomise(by = "participant_id", arms = "arm") |>
#'   exclude(~ withdrew, label = "Withdrew consent")
#' flow <- apply_criteria(dat, crit, id = "participant_id")
#' as_narrative(flow)
#' as_narrative(flow, style = "bullets")
#' as_narrative(flow, drop_randomise = TRUE)
as_narrative <- function(
  flow,
  assessed_label    = "assessed for eligibility",
  unit              = "participants",
  count_by          = NULL,
  big_mark          = ",",
  digits            = 1L,
  show_categories   = TRUE,
  drop_randomise    = FALSE,
  lowercase_reasons = TRUE,
  style             = c("prose", "bullets")
) {
  if (!inherits(flow, "cf_flow")) {
    rlang::abort("`flow` must be a `cf_flow` object.")
  }
  .narr_check_string(assessed_label, "assessed_label")
  .narr_check_string(unit, "unit")
  .narr_check_string(big_mark, "big_mark", allow_empty = TRUE)
  if (!is.numeric(digits) || length(digits) != 1L || is.na(digits) ||
        digits < 0 || digits != round(digits)) {
    rlang::abort("`digits` must be a single non-negative whole number.")
  }
  .narr_check_flag(show_categories, "show_categories")
  .narr_check_flag(drop_randomise, "drop_randomise")
  .narr_check_flag(lowercase_reasons, "lowercase_reasons")
  style  <- match.arg(style)
  digits <- as.integer(digits)

  ctx <- list(
    digits = digits, big_mark = big_mark, lowercase = lowercase_reasons,
    unit = unit, assessed_label = assessed_label
  )

  tbl <- as_attrition_tibble(flow, show_categories = show_categories,
                             digits = digits, count_by = count_by)
  tbl <- .annotate_step_reasons(tbl, flow$steps)
  groups  <- .consort_group_rows(tbl)
  n_group <- length(groups)
  n_start <- groups[[1L]]$row$n
  final   <- groups[[n_group]]$row

  # Split at a randomise() step the same way as_consort_diagram() does: the
  # first group at or after it. No split when it is dropped or no rows reach
  # it (the diagram then draws the plain cascade too).
  rand  <- .find_randomise_step(flow$steps)
  split <- NA_integer_
  if (!drop_randomise && !is.null(rand) && "post_randomisation" %in% names(tbl) &&
        length(.surviving_ids(flow, rand$step)) > 0L) {
    post  <- vapply(groups, function(g) isTRUE(g$row$post_randomisation), logical(1L))
    split <- min(which(post))
  }

  pre_idx <- seq_len(n_group)
  pre_idx <- pre_idx[pre_idx > 1L & pre_idx < (if (is.na(split)) n_group else split)]
  pre_idx <- pre_idx[vapply(groups[pre_idx], .consort_has_exclusions, logical(1L))]

  sentences <- character(0L)
  for (i in seq_along(pre_idx)) {
    leaving <- if (i == length(pre_idx)) {
      g <- groups[[pre_idx[i]]]
      g$row$n - .consort_group_removal(g)$n_removed
    }
    sentences <- c(sentences, .narr_pooled_sentence(
      groups[[pre_idx[i]]], first = i == 1L, leaving = leaving, n_start = n_start, ctx = ctx
    ))
  }

  arms <- NULL
  if (!is.na(split)) {
    arms <- .narr_arm_tables(flow, rand, show_categories, digits, count_by, n_post = n_group - split)
    sentences <- c(sentences, .narr_randomise_sentence(
      groups[[split]]$row$n, arms, all_randomised = length(pre_idx) == 0L,
      n_start = n_start, ctx = ctx
    ))
    first_post <- TRUE
    for (j in seq_len(n_group - split - 1L)) {
      arm_groups <- lapply(arms$groups, `[[`, j)
      s <- .narr_arm_sentence(groups[[split + j]], arm_groups, arms$labels,
                              first = first_post, ctx = ctx)
      if (!is.null(s)) {
        sentences  <- c(sentences, s)
        first_post <- FALSE
      }
    }
  }

  if (length(sentences) == 0L) {
    # Nobody removed and no arms to report: one sentence says it all.
    sentences <- if (n_start == 0L) {
      sprintf("Of 0 %s %s, none were excluded.", unit, assessed_label)
    } else {
      sprintf("Of %s %s %s, none were excluded; the final cohort comprised %s %s.",
              .format_n(n_start, big_mark), unit, assessed_label,
              .format_n(final$n, big_mark), unit)
    }
  } else {
    sentences <- c(sentences, .narr_final_sentence(final, arms, ctx))
  }

  text <- if (style == "bullets") {
    paste0("- ", sentences, collapse = "\n")
  } else {
    paste(sentences, collapse = " ")
  }
  structure(text, class = c("cf_narrative", "character"))
}

#' @rdname as_narrative
#' @export
print.cf_narrative <- function(x, ...) {
  lines <- strsplit(unclass(x), "\n", fixed = TRUE)[[1L]]
  out <- unlist(lapply(lines, function(l) {
    strwrap(l, width = getOption("width"), exdent = if (startsWith(l, "- ")) 2L else 0L)
  }))
  cat(out, sep = "\n")
  invisible(x)
}

#' @exportS3Method knitr::knit_print
#' @noRd
knit_print.cf_narrative <- function(x, ...) {
  knitr::asis_output(paste0("\n\n", unclass(x), "\n\n"))
}

# ---------------------------------------------------------------------------
# Per-arm attrition, as as_consort_diagram() computes it
# ---------------------------------------------------------------------------

# Re-applies the criteria after the randomise() step to each arm's entering
# rows, exactly as as_consort_diagram() does for its arm cascades (see the
# split-trunk block there), so the narrative's arm numbers match the
# diagram's. Returns the arm labels, each arm's entering count, and each
# arm's attrition groups (header dropped, final row last), which line up by
# position with the pooled groups after the split.
.narr_arm_tables <- function(flow, rand, show_categories, digits, count_by, n_post) {
  count_cols <- if (!is.null(count_by)) .resolve_count_level(flow, count_by)$cols
  count_fn   <- .count_fn(count_cols)
  arms_col   <- rand$arms

  entered_ids  <- .consort_entered_at_step(flow, rand$step)
  entered_data <- flow$data[flow$data$.cf_row_id %in% entered_ids, , drop = FALSE]
  values <- .cf_group_values(entered_data[[arms_col]])
  labels <- vapply(values, .cf_group_label, character(1L), na_label = "Missing", USE.NAMES = FALSE)

  n_criteria <- length(flow$criteria)
  remaining  <- flow$criteria[seq_len(n_criteria)[seq_len(n_criteria) > rand$step]]

  entered_n <- integer(length(values))
  groups    <- vector("list", length(values))
  for (b in seq_along(values)) {
    arm_data <- entered_data[.cf_group_match(entered_data[[arms_col]], values[b]), , drop = FALSE]
    entered_n[b] <- count_fn(arm_data)
    arm_flow <- apply_criteria(arm_data, remaining, id = ".cf_row_id",
                               hierarchy = if (!is.null(count_by)) flow$hierarchy)
    arm_tbl  <- .attrition_tibble_core(arm_flow, show_categories, "", "", digits,
                                       branch_by = NULL, count_by = count_by)
    arm_tbl  <- .annotate_step_reasons(arm_tbl, arm_flow$steps)
    arm_tbl  <- arm_tbl[arm_tbl$row_type != "header", , drop = FALSE]
    groups[[b]] <- .consort_group_rows(arm_tbl)
    if (length(groups[[b]]) != n_post) {
      rlang::abort("Internal error: arm cascade row count does not match the pooled cascade.")
    }
  }
  list(labels = labels, entered_n = entered_n, groups = groups)
}

# ---------------------------------------------------------------------------
# Sentence builders
# ---------------------------------------------------------------------------

# "Of N <unit> <assessed>, k (p%) were excluded (<reason>), leaving n." for
# the first sentence, "A further k (p%) ..." after it. `leaving` is the
# number remaining after the group, or NULL to leave the clause off.
.narr_pooled_sentence <- function(group, first, leaving, n_start, ctx) {
  removal <- .consort_group_removal(group)
  rows    <- .narr_removal_rows(group)
  rows    <- rows[vapply(rows, function(r) isTRUE(r$n_removed > 0L), logical(1L))]
  reasons <- vapply(rows, .narr_reason, character(1L), lowercase = ctx$lowercase)

  opening <- if (first) {
    sprintf("Of %s %s %s, ", .format_n(n_start, ctx$big_mark), ctx$unit, ctx$assessed_label)
  } else {
    "A further "
  }
  verb <- if (removal$n_removed == 1L) "was" else "were"
  reason_text <- if (length(reasons) == 1L) {
    sprintf(" (%s)", reasons)
  } else {
    counts <- vapply(rows, function(r) .format_n(r$n_removed, ctx$big_mark), character(1L))
    paste0(": ", .oxford_join(sprintf("%s (n = %s)", reasons, counts)))
  }
  tail <- if (is.null(leaving)) "" else sprintf(", leaving %s", .format_n(leaving, ctx$big_mark))

  sprintf("%s%s %s excluded%s%s.",
          opening, .narr_count(removal$n_removed, removal$pct_removed, ctx), verb,
          reason_text, tail)
}

# "The remaining n were randomised to A (n = a) and B (n = b).", or "All N
# <unit> <assessed> were randomised to ..." when nobody was removed before.
.narr_randomise_sentence <- function(n, arms, all_randomised, n_start, ctx) {
  arm_text <- .oxford_join(sprintf("%s (n = %s)", arms$labels,
                                   .format_n(arms$entered_n, ctx$big_mark)))
  if (all_randomised) {
    sprintf("All %s %s %s were randomised to %s.",
            .format_n(n_start, ctx$big_mark), ctx$unit, ctx$assessed_label, arm_text)
  } else {
    sprintf("The remaining %s were randomised to %s.", .format_n(n, ctx$big_mark), arm_text)
  }
}

# One sentence for a group after randomisation, with per-arm counts:
# e.g. After randomisation, 3 (3.1%) in A and 4 (4.5%) in B were excluded (r).
# Returns NULL when no arm lost anyone at this group.
.narr_arm_sentence <- function(pooled_group, arm_groups, labels, first, ctx) {
  removals <- lapply(arm_groups, .consort_group_removal)
  totals   <- vapply(removals, `[[`, numeric(1L), "n_removed")
  if (!any(totals > 0)) return(NULL)

  # Rows within a group line up across arms (same steps, same categories).
  pooled_rows <- .narr_removal_rows(pooled_group)
  arm_rows    <- lapply(arm_groups, .narr_removal_rows)
  keep <- vapply(seq_along(pooled_rows), function(k) {
    any(vapply(arm_rows, function(rows) isTRUE(rows[[k]]$n_removed > 0L), logical(1L)))
  }, logical(1L))
  reasons <- vapply(pooled_rows[keep], .narr_reason, character(1L), lowercase = ctx$lowercase)

  per_arm <- vapply(seq_along(labels), function(b) {
    sprintf("%s in %s", .narr_count(removals[[b]]$n_removed, removals[[b]]$pct_removed, ctx),
            labels[b])
  }, character(1L))

  reason_text <- if (length(reasons) == 1L) {
    sprintf(" (%s)", reasons)
  } else {
    by_reason <- vapply(which(keep), function(k) {
      paste(sprintf("%s %s", labels,
                    vapply(arm_rows, function(rows) .format_n(rows[[k]]$n_removed, ctx$big_mark),
                           character(1L))),
            collapse = ", ")
    }, character(1L))
    paste0(": ", .oxford_join(sprintf("%s (%s)", reasons, by_reason)))
  }

  sprintf("%s%s were excluded%s.",
          if (first) "After randomisation, " else "A further ",
          .oxford_join(per_arm), reason_text)
}

# "The final cohort comprised n <unit> (p% of those assessed): a in A and b
# in B."
.narr_final_sentence <- function(final, arms, ctx) {
  out <- sprintf("The final cohort comprised %s %s", .format_n(final$n, ctx$big_mark), ctx$unit)
  if (!is.na(final$pct_removed)) {
    out <- sprintf("%s (%s%% of those assessed)", out, .format_pct(final$pct_removed, ctx$digits))
  }
  if (!is.null(arms)) {
    arm_n <- vapply(arms$groups, function(g) g[[length(g)]]$row$n, numeric(1L))
    out <- sprintf("%s: %s", out,
                   .oxford_join(sprintf("%s in %s", .format_n(arm_n, ctx$big_mark), arms$labels)))
  }
  paste0(out, ".")
}

# ---------------------------------------------------------------------------
# Small helpers
# ---------------------------------------------------------------------------

# The step rows a group's removals are listed from: its child steps for a
# category, else the step row itself.
.narr_removal_rows <- function(group) {
  if (length(group$children) > 0L) group$children else list(group$row)
}

# A step row's removal text: its `reason` (see .step_reason()), else
# `not meeting "<label>"` for an inclusion step without one.
.narr_reason <- function(row, lowercase) {
  if (is.na(row$reason)) return(sprintf("not meeting \"%s\"", row$label))
  if (lowercase) .narr_lower_first(row$reason) else row$reason
}

# Lower-cases the first letter unless the first word looks like an acronym
# (second character upper case: "BMI missing").
.narr_lower_first <- function(x) {
  if (!nzchar(x) || grepl("^.[[:upper:]]", x)) return(x)
  paste0(tolower(substr(x, 1L, 1L)), substring(x, 2L))
}

# "k (p%)", or "k" when there is no percentage (nobody entering).
.narr_count <- function(n, pct, ctx) {
  n_text <- .format_n(n, ctx$big_mark)
  if (is.na(pct)) n_text else sprintf("%s (%s%%)", n_text, .format_pct(pct, ctx$digits))
}

# "a", "a and b", "a, b, and c" (serial comma).
.oxford_join <- function(x) {
  n <- length(x)
  if (n <= 1L) return(paste(x, collapse = ""))
  if (n == 2L) return(paste(x, collapse = " and "))
  paste0(paste(x[-n], collapse = ", "), ", and ", x[n])
}

.narr_check_string <- function(x, arg, allow_empty = FALSE) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || (!allow_empty && !nzchar(x))) {
    rlang::abort(sprintf("`%s` must be a single %sstring.", arg, if (allow_empty) "" else "non-empty "))
  }
  invisible(NULL)
}

.narr_check_flag <- function(x, arg) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    rlang::abort(sprintf("`%s` must be TRUE or FALSE.", arg))
  }
  invisible(NULL)
}
