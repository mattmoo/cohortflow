#'
#' Serialises a `cf_criteria` object to a human-readable YAML file (or string).
#' The schema is self-describing and can be re-imported with [import_criteria()].
#'
#' @section YAML schema:
#' ```yaml
#' cohortflow_criteria:
#'   version: 1
#'   steps:
#'     - label:  "Adults only"
#'       type:   include
#'       kind:   formula
#'       by:     null
#'       expr:   "age >= 18"
#'       fn_ref: null
#' ```
#'
#' Formula-based criteria round-trip cleanly. Anonymous function bodies are
#' deparsed as a fallback; complex closures may not round-trip and a warning
#' is issued. Named exported functions can be stored as `"pkg::name"` references
#' via `fn_refs`.
#'
#' @param criteria A `cf_criteria` object.
#' @param path A file path to write to. If `NULL` (default), the YAML text is
#'   returned as a character string.
#' @param fn_refs An optional named list mapping function objects to
#'   `"pkg::name"` reference strings.
#'
#' @return Invisibly, the `criteria` object (or the YAML string if `path = NULL`).
#' @export
export_criteria <- function(criteria, path = NULL, fn_refs = list()) {
  if (!inherits(criteria, "cf_criteria")) {
    rlang::abort("`criteria` must be a `cf_criteria` object.")
  }

  steps_list <- lapply(criteria$steps, .criterion_to_list, fn_refs = fn_refs)

  doc <- list(
    cohortflow_criteria = list(
      version = 1L,
      steps   = steps_list
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
#' @param text A YAML string. Exactly one of `path` or `text` must be supplied.
#' @param envir The environment in which to evaluate re-parsed expressions.
#'
#' @return A `cf_criteria` object.
#' @export
import_criteria <- function(path = NULL, text = NULL, envir = parent.frame()) {
  if (is.null(path) == is.null(text)) {
    rlang::abort("Exactly one of `path` or `text` must be supplied.")
  }

  raw <- if (!is.null(path)) yaml::read_yaml(path) else yaml::yaml.load(text)

  if (is.null(raw$cohortflow_criteria)) {
    rlang::abort(paste0(
      "YAML does not look like a cohortflow criteria file ",
      "(missing top-level `cohortflow_criteria` key)."
    ))
  }

  doc   <- raw$cohortflow_criteria
  steps <- lapply(doc$steps, .list_to_criterion, envir = envir)
  do.call(cf_criteria, steps)
}

# ---------------------------------------------------------------------------
# Internal helpers

.criterion_to_list <- function(crit, fn_refs = list()) {
  if (is.null(crit$predicate)) {
    return(list(
      label    = crit$label,
      type     = crit$type,
      kind     = "none",
      by       = crit$by,
      expr     = NULL,
      fn_ref   = NULL,
      category = crit$category,
      arms     = crit$arms
    ))
  }

  is_fn <- is.function(crit$predicate)

  if (!is_fn) {
    expr_str <- paste(deparse(crit$predicate[[2L]], width.cutoff = 500L), collapse = " ")
    return(list(
      label  = crit$label,
      type   = crit$type,
      kind   = "formula",
      by     = crit$by,
      expr   = expr_str,
      fn_ref = NULL,
      category = crit$category,
      arms     = crit$arms
    ))
  }

  # Function: look for a pkg::name reference
  fn_ref_str <- NULL
  for (nm in names(fn_refs)) {
    if (identical(crit$predicate, fn_refs[[nm]])) {
      fn_ref_str <- nm
      break
    }
  }

  if (is.null(fn_ref_str)) {
    fn_env <- environment(crit$predicate)
    if (!identical(fn_env, globalenv()) && !identical(fn_env, baseenv()) &&
          !identical(fn_env, emptyenv()) && length(ls(fn_env)) > 0L) {
      rlang::warn(paste0(
        "Criterion '", crit$label, "': the function predicate captures ",
        "variables from its enclosing environment and may not round-trip ",
        "faithfully through YAML."
      ))
    }
  }

  body_str    <- paste(deparse(body(crit$predicate), width.cutoff = 500L), collapse = "\n")
  formals_str <- paste(names(formals(crit$predicate)), collapse = ", ")

  list(
    label    = crit$label,
    type     = crit$type,
    kind     = "function",
    by       = crit$by,
    expr     = body_str,
    fn_args  = formals_str,
    fn_ref   = fn_ref_str,
    category = crit$category,
    arms     = crit$arms
  )
}

.list_to_criterion <- function(s, envir = parent.frame()) {
  kind     <- rlang::`%||%`(s$kind, "formula")
  by_val   <- rlang::`%||%`(s$by,   NULL)
  arms_val <- rlang::`%||%`(s$arms, NULL)

  if (kind == "none") {
    pred <- NULL
  } else if (kind == "formula") {
    expr <- parse(text = s$expr, keep.source = FALSE)[[1L]]
    pred <- stats::as.formula(call("~", expr), env = envir)
  } else {
    if (!is.null(s$fn_ref)) {
      parts <- strsplit(s$fn_ref, "::", fixed = TRUE)[[1L]]
      pred  <- if (length(parts) == 2L) {
        utils::getFromNamespace(parts[2L], parts[1L])
      } else {
        get(s$fn_ref, envir = envir)
      }
    } else {
      args_str <- if (!is.null(s$fn_args) && nzchar(s$fn_args)) s$fn_args else "d"
      fn_text  <- sprintf("function(%s) %s", args_str, s$expr)
      pred     <- eval(parse(text = fn_text, keep.source = FALSE), envir = envir)
    }
  }

  cf_criterion(predicate = pred, label = s$label, type = s$type, by = by_val,
              category = s$category, arms = arms_val)
}
