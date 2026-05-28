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
#'
#' @param data A data frame.
#' @param criteria A `cf_criteria` object.
#' @param id A single column name (string) to use as the row identifier. If
#'   `NULL` (default), the function looks for `.cf_row_id` in `data`; if not
#'   found, a sequential integer is added.
#'
#' @return A `cf_flow` object.
#' @export
#'
#' @examples
#' dat  <- mock_cohortflow(n_participants = 200, seed = 1)
#' crit <- cf_criteria() |>
#'   include(~ eligible_screen, label = "Passed screening") |>
#'   include(~ !is.na(consent_date), label = "Consent recorded") |>
#'   exclude(~ withdrew, label = "Withdrew consent") |>
#'   group_include(by = "cluster_id", ~ n() >= 5,
#'                 label = "Cluster size >= 5")
#'
#' flow <- apply_criteria(dat, crit)
#' flow
#' cohort(flow)
#' excluded(flow)
apply_criteria <- function(data, criteria, id = NULL) {
  if (!is.data.frame(data)) rlang::abort("`data` must be a data frame.")
  if (!inherits(criteria, "cf_criteria")) {
    rlang::abort("`criteria` must be a `cf_criteria` object.")
  }

  # -- Row identity ----------------------------------------------------------
  data <- .ensure_row_id(data, id)

  # Store original (with .cf_row_id) for later retrieval
  original <- data

  # -- Apply steps -----------------------------------------------------------
  current  <- data   # rows surviving so far
  step_records <- vector("list", length(criteria$steps))

  for (i in seq_along(criteria$steps)) {
    s      <- criteria$steps[[i]]
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
      rlang::abort(sprintf("Unknown criterion type: %s", s$type))
    )

    excluded_rows <- current[!keep, , drop = FALSE]
    current       <- current[keep, , drop = FALSE]

    step_records[[i]] <- list(
      step         = i,
      label        = s$label,
      type         = s$type,
      by           = s$by,
      category     = s$category,
      n_in         = n_in,
      n_pass       = nrow(current),
      n_fail       = nrow(excluded_rows),
      excluded_ids = excluded_rows$.cf_row_id
    )
  }

  new_cf_flow(data = original, criteria = criteria, steps = step_records)
}

# ---------------------------------------------------------------------------
# Internal: row ID management

.ensure_row_id <- function(data, id) {
  if (!is.null(id)) {
    # User supplied a column name
    if (!id %in% names(data)) {
      rlang::abort(sprintf("Column `%s` supplied as `id` not found in data.", id))
    }
    if (any(duplicated(data[[id]]))) {
      rlang::warn(sprintf(
        "Column `%s` contains duplicate values; it may not uniquely identify rows.", id
      ))
    }
    data$.cf_row_id <- data[[id]]
    return(data)
  }

  if (".cf_row_id" %in% names(data)) {
    # Already has an ID column — use it
    return(data)
  }

  # Auto-generate
  message("No `id` supplied and no `.cf_row_id` column found. ",
          "Adding a sequential `.cf_row_id`.")
  data$.cf_row_id <- seq_len(nrow(data))
  data
}
