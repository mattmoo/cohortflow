#' Export a criteria pipeline to YAML
#'
#' Serialises a `cf_criteria` object to a human-readable YAML file (or string).
#' The schema is self-describing and can be re-imported with [import_criteria()].
#'
#' @section YAML schema:
#' ```yaml
#' cohortflow_criteria:
#'   version: 1
#'   hierarchy:           # optional
#'     participant: participant_id
#'     cluster:     cluster_id
#'     site:        site_id
#'   steps:
#'     - label:   "Adults only"
#'       type:    include
#'       kind:    formula        # "formula" | "function"
#'       expr:    "age >= 18"    # for formula: deparsed RHS; for function: body
#'       fn_ref:  null           # for function: "pkg::name" if named/exported
#' ```
#'
#' **Portability notes**
#'
#' * Formula-based criteria round-trip cleanly: the RHS is deparsed to a string
#'   and re-parsed on import.
#' * Anonymous function criteria are stored as a deparsed function body.
#'   These can be re-imported as formulas when the body is a simple expression,
#'   or as functions otherwise. Complex closures (functions that capture
#'   variables from their enclosing environment) may not round-trip faithfully —
#'   a warning is issued.
#' * Named, exported functions can be stored as `"pkg::name"` references for
#'   fully portable YAML. Pass `fn_refs` to supply these mappings.
#'
#' @param criteria A `cf_criteria` object.
#' @param path A file path to write to. If `NULL` (default), the YAML text is
#'   returned as a character string.
#' @param fn_refs An optional named list mapping function objects to
#'   `"pkg::name"` reference strings, e.g.
#'   `list(has_consent = "mypkg::has_consent")`. Only needed for function-based
#'   criteria that you want to store as portable references.
#'
#' @return Invisibly, the `criteria` object. Side effect: writes the YAML file
#'   if `path` is not `NULL`, or returns the YAML string if `path` is `NULL`.
#' @export
#'
#' @examples
#' crit <- cf_criteria() |>
#'   include(~ age >= 18, label = "Adults only") |>
#'   exclude(~ is.na(consent_date), label = "No consent")
#'
#' # Return as a string
#' cat(export_criteria(crit))
#'
#' # Write to a file
#' \dontrun{
#' export_criteria(crit, path = "criteria.yaml")
#' }
export_criteria <- function(criteria, path = NULL, fn_refs = list()) {
  if (!inherits(criteria, "cf_criteria")) {
    rlang::abort("`criteria` must be a `cf_criteria` object.")
  }

  # -- Hierarchy -------------------------------------------------------------
  hier_list <- if (!is.null(criteria$hierarchy)) {
    as.list(unclass(criteria$hierarchy))
  } else {
    NULL
  }

  # -- Steps -----------------------------------------------------------------
  steps_list <- lapply(criteria$steps, function(s) {
    .criterion_to_list(s, fn_refs = fn_refs)
  })

  # -- Assemble --------------------------------------------------------------
  doc <- list(
    cohortflow_criteria = list(
      version   = 1L,
      hierarchy = hier_list,
      steps     = steps_list
    )
  )

  yml <- yaml::as.yaml(doc)

  if (is.null(path)) {
    return(invisible(yml))
  }

  writeLines(yml, con = path)
  invisible(criteria)
}

#' Import a criteria pipeline from YAML
#'
#' Reads a YAML file (or string) written by [export_criteria()] and
#' reconstructs a `cf_criteria` object.
#'
#' @param path A file path to read from. Exactly one of `path` or `text` must
#'   be supplied.
#' @param text A YAML string (as produced by `export_criteria(crit)` with no
#'   `path`). Exactly one of `path` or `text` must be supplied.
#' @param envir The environment in which to evaluate re-parsed formula
#'   expressions and resolve `pkg::name` function references. Defaults to the
#'   caller's environment.
#'
#' @return A `cf_criteria` object.
#' @export
#'
#' @examples
#' crit <- cf_criteria() |>
#'   include(~ age >= 18,          label = "Adults only") |>
#'   exclude(~ is.na(consent_date), label = "No consent")
#'
#' yml  <- export_criteria(crit)
#' crit2 <- import_criteria(text = yml)
#' crit2
import_criteria <- function(path = NULL, text = NULL, envir = parent.frame()) {
  if (is.null(path) == is.null(text)) {
    rlang::abort("Exactly one of `path` or `text` must be supplied.")
  }

  raw <- if (!is.null(path)) {
    yaml::read_yaml(path)
  } else {
    yaml::yaml.load(text)
  }

  if (is.null(raw$cohortflow_criteria)) {
    rlang::abort(
      paste0(
        "YAML does not look like a cohortflow criteria file ",
        "(missing top-level `cohortflow_criteria` key)."
      )
    )
  }

  doc <- raw$cohortflow_criteria

  # -- Hierarchy -------------------------------------------------------------
  hier <- if (!is.null(doc$hierarchy)) {
    do.call(cf_hierarchy, doc$hierarchy)
  } else {
    NULL
  }

  # -- Steps -----------------------------------------------------------------
  steps <- lapply(doc$steps, function(s) {
    .list_to_criterion(s, envir = envir)
  })

  do.call(cf_criteria, c(steps, list(hierarchy = hier)))
}

# ---------------------------------------------------------------------------
# Internal helpers

.criterion_to_list <- function(crit, fn_refs = list()) {
  is_fn <- is.function(crit$predicate)

  if (!is_fn) {
    # Formula: deparse the RHS
    expr_str <- paste(deparse(crit$predicate[[2L]], width.cutoff = 500L),
                      collapse = " ")
    return(list(
      label  = crit$label,
      type   = crit$type,
      kind   = "formula",
      expr   = expr_str,
      fn_ref = NULL
    ))
  }

  # Function: look for a pkg::name reference first
  fn_ref_str <- NULL
  for (nm in names(fn_refs)) {
    if (identical(crit$predicate, fn_refs[[nm]])) {
      fn_ref_str <- nm
      break
    }
  }

  if (is.null(fn_ref_str)) {
    # Check for a function that captures variables from its enclosing env
    fn_env <- environment(crit$predicate)
    if (!identical(fn_env, globalenv()) && !identical(fn_env, baseenv()) &&
        !identical(fn_env, emptyenv()) && length(ls(fn_env)) > 0L) {
      rlang::warn(
        paste0(
          "Criterion '", crit$label, "': the function predicate captures ",
          "variables from its enclosing environment and may not round-trip ",
          "faithfully through YAML."
        )
      )
    }
  }

  # Deparse the function body as a fallback
  body_str <- paste(deparse(body(crit$predicate), width.cutoff = 500L),
                    collapse = "\n")

  # Deparse formals to reconstruct the function signature
  formals_str <- paste(
    names(formals(crit$predicate)),
    collapse = ", "
  )

  list(
    label    = crit$label,
    type     = crit$type,
    kind     = "function",
    expr     = body_str,
    fn_args  = formals_str,
    fn_ref   = fn_ref_str
  )
}

.list_to_criterion <- function(s, envir = parent.frame()) {
  kind <- s$kind %||% "formula"

  if (kind == "formula") {
    expr    <- parse(text = s$expr, keep.source = FALSE)[[1L]]
    pred    <- as.formula(call("~", expr), env = envir)
  } else {
    # function
    if (!is.null(s$fn_ref)) {
      # Resolve pkg::name reference
      parts <- strsplit(s$fn_ref, "::", fixed = TRUE)[[1L]]
      if (length(parts) == 2L) {
        pred <- utils::getFromNamespace(parts[2L], parts[1L])
      } else {
        pred <- get(s$fn_ref, envir = envir)
      }
    } else {
      # Re-parse body
      args_str <- if (!is.null(s$fn_args) && nzchar(s$fn_args)) s$fn_args else "d"
      fn_text  <- sprintf("function(%s) %s", args_str, s$expr)
      pred     <- eval(parse(text = fn_text, keep.source = FALSE), envir = envir)
    }
  }

  cf_criterion(predicate = pred, label = s$label, type = s$type)
}

# Null-coalescing operator (avoid importing rlang's %||% into global namespace)
`%||%` <- function(x, y) if (is.null(x)) y else x
