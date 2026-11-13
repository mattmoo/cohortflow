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
#'       category: null
#' ```
#'
#' Formula-based criteria round-trip cleanly. For function predicates
#' (`kind: function`), `expr` holds the full deparsed function source,
#' including its argument list and any default values (e.g.
#' `"function(d, thr = 18) d$age >= thr"`); complex closures may not
#' round-trip and a warning is issued. Named exported functions can be stored
#' as `"pkg::name"` references via `fn_refs`. Files written by earlier
#' versions, which stored the function body in `expr` and the argument names
#' in a separate `fn_args` field, can still be imported.
#'
#' @param criteria A `cf_criteria` object.
#' @param path A file path to write to. If `NULL` (default), the YAML text is
#'   returned as a character string.
#' @param fn_refs An optional named list mapping function objects to
#'   `"pkg::name"` reference strings.
#'
#' @return When `path = NULL`, the YAML text as a character string (returned
#'   visibly, so it prints at the console). Otherwise, invisibly, the
#'   `criteria` object.
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
    return(yml)
  }

  writeLines(yml, con = path)
  invisible(criteria)
}

#' Import a criteria pipeline from YAML
#'
#' Reads a YAML file (or string) written by [export_criteria()] and
#' reconstructs a `cf_criteria` object.
#'
#' @section Security:
#' Criteria files contain R code: every formula and function predicate is
#' parsed and evaluated when the file is imported (and again when the
#' criteria are applied), and `fn_ref` entries are looked up and called.
#' Treat a criteria file like an R script: do not import files from
#' untrusted sources.
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

  # A primitive (e.g. `is.na`) has no environment, so it captures nothing.
  if (is.null(fn_ref_str) && !is.primitive(crit$predicate)) {
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

  # Serialise the whole function (signature + body), so default argument
  # values survive the round-trip. deparse() never includes the
  # <environment>/<bytecode> lines that print() adds.
  fn_src <- paste(deparse(crit$predicate, width.cutoff = 500L), collapse = "\n")

  list(
    label    = crit$label,
    type     = crit$type,
    kind     = "function",
    by       = crit$by,
    expr     = fn_src,
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
    } else if (!is.null(s$fn_args)) {
      # Legacy format: `expr` holds only the body and `fn_args` the
      # argument names, so the function is rebuilt from the two parts.
      args_str <- if (nzchar(s$fn_args)) s$fn_args else "d"
      fn_text  <- sprintf("function(%s) %s", args_str, s$expr)
      pred     <- eval(parse(text = fn_text, keep.source = FALSE), envir = envir)
    } else {
      # Current format: `expr` holds the full function source.
      pred <- eval(parse(text = s$expr, keep.source = FALSE)[[1L]], envir = envir)
    }
  }

  cf_criterion(predicate = pred, label = s$label, type = s$type, by = by_val,
               category = s$category, arms = arms_val)
}
