#' Apply a criteria pipeline to a data frame
#'
#' Evaluates each step in a `cf_criteria` pipeline cumulatively against a data
#' frame, recording which rows are removed at each step. Returns a `cf_flow`
#' object from which the surviving cohort ([cohort()]) and excluded rows
#' ([excluded()]) can be extracted.
#'
#' @section Row identity:
#' `apply_criteria()` needs a stable row identifier to track exclusions. By
#' default it looks for a `.cf_row_id` column in `data`. If one is not found
#' and `id` is `NULL`, a sequential integer identifier is added automatically
#' (with a message). Supply `id` to use an existing column as the identifier.
#'
#' @section Step types:
#' | Type | Predicate | Effect |
#' |---|---|---|
#' | `include` | Row-wise logical vector | Keep `TRUE` rows |
#' | `exclude` | Row-wise logical vector | Drop `TRUE` rows |
#' | `group_include` | Per-group scalar (summarise context) | Keep rows in groups where result is `TRUE` |
#' | `group_exclude` | Per-group scalar (summarise context) | Drop rows in groups where result is `TRUE` |
#' | `select_within` | Per-group logical vector | Keep `TRUE` rows within each group |
#' | `randomise` | None (`predicate = NULL`) | Records the randomisation unit and arm column for downstream reporting |
#'
#' @param data A data frame.
#' @param criteria A `cf_criteria` object.
#' @param id One or more column names (character vector) to use as the row
#'   identifier; supply more than one for a composite (multi-column) key. If
#'   `NULL` (default), the function looks for `.cf_row_id` in `data`; if not
#'   found, a sequential integer is added.
#' @param expected Optional data frame (typically built with [cf_expected()])
#'   listing every observational unit that is expected to exist, e.g. one row
#'   per participant. When supplied, `data` is right-joined onto `expected`
#'   (by `by`) *before* any steps are evaluated, so units with no matching row
#'   in `data` are added as all-`NA` (except for the `by` column(s)) and are
#'   counted correctly as failing the first step that requires non-missing
#'   data. Requires `by`.
#' @param by Column name(s) shared by `data` and `expected` used to join them.
#'   Required, and only used, when `expected` is supplied.
#' @param hierarchy Optional `cf_hierarchy` describing how rows nest into
#'   coarser units (e.g. participants within clusters). When supplied, every
#'   hierarchy column is validated against `data`, and each step record
#'   additionally stores the number of distinct units at risk/passing/failing
#'   at every level (see [as_attrition_tibble()]'s `levels` argument).
#'
#' @return A `cf_flow` object.
#' @export
#'
#' @examples
#' dat  <- mock_cohortflow(n_participants = 200, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ eligible_screen, label = "Passed screening") |>
#'   include(~ !is.na(consent_date), label = "Consent recorded", category = "Consent") |>
#'   exclude(~ withdrew, label = "Withdrew consent", category = "Consent") |>
#'   group_include(by = "cluster_id", ~ n() >= 5,
#'                 label = "Cluster size >= 5")
#'
#' flow <- apply_criteria(dat, crit)
#' flow
#' cohort(flow)
#' excluded(flow)
apply_criteria <- function(data, criteria, id = NULL, expected = NULL, by = NULL,
                           hierarchy = NULL) {
  if (!is.data.frame(data)) rlang::abort("`data` must be a data frame.")
  if (!inherits(criteria, "cf_criteria")) {
    rlang::abort("`criteria` must be a `cf_criteria` object.")
  }

  if (!is.null(expected)) {
    data <- .join_expected(data, expected, by)
  } else if (!is.null(by)) {
    rlang::abort("`by` is only used together with `expected`.")
  }

  if (!is.null(hierarchy)) {
    if (!inherits(hierarchy, "cf_hierarchy")) {
      rlang::abort("`hierarchy` must be a `cf_hierarchy` object.")
    }
    validate_hierarchy(hierarchy, data)
  }

  # -- Row identity ----------------------------------------------------------
  data <- .ensure_row_id(data, id)

  # Store original (with .cf_row_id) for later retrieval
  original <- data

  # -- Apply steps -----------------------------------------------------------
  result <- .run_criteria_steps(data, criteria$steps, hierarchy = hierarchy)

  new_cf_flow(data = original, criteria = criteria, steps = result$step_records,
              hierarchy = hierarchy)
}

# ---------------------------------------------------------------------------
# Internal: shared step-execution loop (used by apply_criteria() and
# continue_criteria())

# Evaluates `steps` cumulatively against `current`, returning the final
# surviving rows and one step record per step. `step_offset` shifts the
# recorded `step` number so continue_criteria() can append records after an
# existing flow's steps without renumbering them. `hierarchy`, when supplied,
# adds a `hierarchy_counts` element (see `.hierarchy_step_counts()`) to every
# step record.
.run_criteria_steps <- function(current, steps, step_offset = 0L, hierarchy = NULL) {
  step_records <- vector("list", length(steps))

  for (i in seq_along(steps)) {
    s      <- steps[[i]]
    before <- current   # snapshot pre-step rows, needed for hierarchy counting
    n_in   <- nrow(current)

    keep <- switch(s$type,
      include = {
        result <- eval_criterion(s, current)
        result & !is.na(result)
      },
      exclude = {
        result <- eval_criterion(s, current)
        !(result & !is.na(result))
      },
      group_include = {
        result <- eval_group_criterion(s, current)
        result & !is.na(result)
      },
      group_exclude = {
        result <- eval_group_criterion(s, current)
        !(result & !is.na(result))
      },
      select_within = {
        result <- eval_select_criterion(s, current)
        result & !is.na(result)
      },
      randomise = rep(TRUE, nrow(current)),
      rlang::abort(sprintf("Unknown criterion type: %s", s$type))
    )

    excluded_rows <- current[!keep, , drop = FALSE]
    current       <- current[keep, , drop = FALSE]

    step_records[[i]] <- list(
      step         = step_offset + i,
      label        = s$label,
      type         = s$type,
      by           = s$by,
      category     = s$category,
      arms         = s$arms,
      n_in         = n_in,
      n_pass       = nrow(current),
      n_fail       = nrow(excluded_rows),
      excluded_ids = excluded_rows$.cf_row_id,
      hierarchy_counts = if (!is.null(hierarchy)) {
        .hierarchy_step_counts(before, current, hierarchy, s$type, s$by)
      } else {
        NULL
      }
    )
  }

  list(current = current, step_records = step_records)
}

# ---------------------------------------------------------------------------
# Internal: row ID management

.ensure_row_id <- function(data, id) {
  if (!is.null(id)) {
    # User supplied one or more column names (composite key when length > 1)
    missing_id <- setdiff(id, names(data))
    if (length(missing_id) > 0L) {
      rlang::abort(sprintf(
        "Column(s) supplied as `id` not found in data: %s.",
        paste(missing_id, collapse = ", ")
      ))
    }
    key <- .composite_key(data, id)
    if (any(duplicated(key))) {
      rlang::warn(sprintf(
        "Column(s) `%s` contain duplicate values; they may not uniquely identify rows.",
        paste(id, collapse = ", ")
      ))
    }
    data$.cf_row_id <- key
    return(data)
  }

  if (".cf_row_id" %in% names(data)) {
    # Already has an ID column -- use it
    return(data)
  }

  # Auto-generate
  message("No `id` supplied and no `.cf_row_id` column found. ",
          "Adding a sequential `.cf_row_id`.")
  data$.cf_row_id <- seq_len(nrow(data))
  data
}

# Build a single grouping/identifier key from one or more columns. A single
# column is returned unchanged (preserving its original type); more than one
# column is pasted into one character key. Shared by row `id=` handling above
# and by composite `by=` grouping in R/criterion.R.
.composite_key <- function(data, cols) {
  if (length(cols) == 1L) return(data[[cols]])
  do.call(paste, c(unname(as.list(data[cols])), sep = "\r"))
}

# ---------------------------------------------------------------------------
# Internal: expected-unit denominators

# Right-joins `data` onto `expected` by `by`, so every row of `expected` is
# retained (with `NA` for any `data`-only columns when there is no match).
# Unlike `.ensure_row_id()`'s duplicate check (warn-only), a duplicated key in
# `expected` is destructive (silently fans out matching `data` rows) and so
# is a hard error.
.join_expected <- function(data, expected, by) {
  if (!is.data.frame(expected)) rlang::abort("`expected` must be a data frame.")
  if (is.null(by)) {
    rlang::abort("`by` must be supplied when `expected` is used.")
  }

  missing_in_expected <- setdiff(by, names(expected))
  if (length(missing_in_expected) > 0L) {
    rlang::abort(sprintf(
      "`by` column(s) not found in `expected`: %s.",
      paste(missing_in_expected, collapse = ", ")
    ))
  }
  missing_in_data <- setdiff(by, names(data))
  if (length(missing_in_data) > 0L) {
    rlang::abort(sprintf(
      "`by` column(s) not found in `data`: %s.",
      paste(missing_in_data, collapse = ", ")
    ))
  }

  colliding <- intersect(setdiff(names(expected), by), names(data))
  if (length(colliding) > 0L) {
    rlang::abort(sprintf(
      "`expected` column(s) also present in `data` (other than `by`): %s.",
      paste(colliding, collapse = ", ")
    ))
  }

  .assert_no_join_fanout(expected, by)

  n_missing <- sum(!.composite_key(expected, by) %in% .composite_key(data, by))
  if (n_missing > 0L) {
    message(sprintf(
      "%d expected unit(s) had no matching record in `data`; %s added as empty row(s).",
      n_missing, n_missing
    ))
  }

  dplyr::right_join(data, expected, by = by)
}

# Aborts (rather than warns) if `by` does not uniquely identify rows of `df`,
# naming the offending duplicate value(s). Used wherever a join would
# silently fan out rows if the key were not unique (expected-unit joins,
# continue_criteria() joins) -- deliberately stricter than `.ensure_row_id()`.
.assert_no_join_fanout <- function(df, by) {
  key <- .composite_key(df, by)
  dup <- unique(key[duplicated(key)])
  if (length(dup) > 0L) {
    rlang::abort(sprintf(
      "`%s` must uniquely identify rows, but found duplicate value(s): %s.",
      paste(by, collapse = ", "),
      paste(utils::head(dup, 10L), collapse = ", ")
    ))
  }
  invisible(NULL)
}
