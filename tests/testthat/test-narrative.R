# ===========================================================================
# Narrative text: as_narrative
# ===========================================================================

# A flow shaped like the brief's example: a two-step category with reasons,
# an uncategorised inclusion with a reason, randomisation, then a category of
# post-allocation losses (one with an acronym reason).
make_flow_narrative_example <- function() {
  dat <- mock_parallel_rct(n_participants = 200, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age recorded", reason = "Age missing", category = "Age") |>
    include(~ age >= 18, label = "Aged 18 or over", reason = "Under 18", category = "Age") |>
    include(~ !is.na(consent_date), label = "Consented", reason = "Did not consent") |>
    randomise(by = "participant_id", arms = "arm") |>
    exclude(~ withdrew, label = "Withdrew consent", category = "Lost") |>
    include(~ baseline_complete, label = "Baseline done", reason = "BMI not recorded",
            category = "Lost")
  apply_criteria(dat, crit, id = "participant_id")
}

# Integers in a narrative, in order (thousands separators removed;
# percentages dropped).
narrative_ints <- function(x) {
  x <- gsub("[0-9.]+%", "", unclass(x))
  as.integer(gsub(",", "", regmatches(x, gregexpr("[0-9][0-9,]*", x))[[1L]]))
}

# Removal counts of the attrition rows the narrative lists, in order: each
# category/step that removed anyone, followed by its child steps that did.
attrition_removal_ints <- function(tbl) {
  groups <- cohortflow:::.consort_group_rows(tbl)
  groups <- groups[-c(1L, length(groups))]
  unlist(lapply(groups, function(g) {
    total <- cohortflow:::.consort_group_removal(g)$n_removed
    if (total == 0L) return(integer(0L))
    kids <- vapply(g$children, `[[`, integer(1L), "n_removed")
    kids <- kids[kids > 0L]
    if (length(kids) > 1L) c(total, kids) else total
  }))
}

# -- Snapshots ---------------------------------------------------------------

test_that("narratives read as expected", {
  expect_snapshot({
    as_narrative(make_flow_categorised())
    as_narrative(make_flow_flat())
    as_narrative(make_flow_randomise_multistep())
    as_narrative(make_flow_no_exclusions())
    as_narrative(make_flow_narrative_example())
  })
})

test_that("bullet style gives one sentence per line", {
  expect_snapshot(as_narrative(make_flow_randomise_multistep(), style = "bullets"))
  x <- as_narrative(make_flow_randomise_multistep(), style = "bullets")
  lines <- strsplit(unclass(x), "\n", fixed = TRUE)[[1L]]
  expect_true(all(startsWith(lines, "- ")))
  prose <- as_narrative(make_flow_randomise_multistep())
  expect_identical(paste(substring(lines, 3L), collapse = " "), unclass(prose)[[1L]])
})

test_that("zero-row and zero-step flows give one sentence", {
  dat <- mock_parallel_rct(n_participants = 50, seed = 1)
  crit <- cf_criteria() |> include(~ !is.na(age), label = "Age recorded")
  zero_rows  <- apply_criteria(dat[0, ], crit, id = "participant_id")
  zero_steps <- apply_criteria(dat, cf_criteria(), id = "participant_id")
  expect_snapshot({
    as_narrative(zero_rows)
    as_narrative(zero_steps)
  })
  expect_identical(
    unclass(as_narrative(zero_rows))[[1L]],
    "Of 0 participants assessed for eligibility, none were excluded."
  )
})

# -- Return value ------------------------------------------------------------

test_that("returns a cf_narrative string and prints it invisibly", {
  x <- as_narrative(make_flow_flat())
  expect_s3_class(x, c("cf_narrative", "character"), exact = TRUE)
  expect_length(x, 1L)
  out <- utils::capture.output(res <- withVisible(print(x)))
  expect_false(res$visible)
  expect_identical(res$value, x)
  expect_true(all(nchar(out) <= getOption("width")))
})

test_that("knit_print inserts the text as-is", {
  skip_if_not_installed("knitr")
  x <- as_narrative(make_flow_flat())
  out <- knitr::knit_print(x)
  expect_s3_class(out, "knit_asis")
  expect_match(out, unclass(x), fixed = TRUE)
})

test_that("arguments are checked", {
  flow <- make_flow_flat()
  expect_error(as_narrative(list()), "cf_flow", class = "rlang_error")
  expect_error(as_narrative(flow, unit = ""), "`unit` must be a single non-empty string")
  expect_error(as_narrative(flow, assessed_label = c("a", "b")), "`assessed_label`")
  expect_error(as_narrative(flow, big_mark = NA_character_), "`big_mark` must be a single string")
  expect_error(as_narrative(flow, digits = 1.5), "`digits`")
  expect_error(as_narrative(flow, digits = -1), "`digits`")
  expect_error(as_narrative(flow, show_categories = NA), "`show_categories` must be TRUE or FALSE")
  expect_error(as_narrative(flow, style = "table"), class = "error")
})

# -- Sentences and wording -----------------------------------------------------

test_that("show_categories = FALSE gives one sentence per step", {
  flow <- make_flow_categorised()
  n_sentences <- function(x) length(gregexpr("\\. ", unclass(x))[[1L]]) + 1L
  expect_gt(n_sentences(as_narrative(flow, show_categories = FALSE)),
            n_sentences(as_narrative(flow)))
})

test_that("removal text is the reason, the exclude label, or 'not meeting'", {
  dat <- mock_parallel_rct(n_participants = 200, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age recorded", reason = "Age missing") |>
    include(~ age >= 18, label = "Aged 18 or over") |>
    exclude(~ withdrew, label = "Withdrew consent")
  flow <- apply_criteria(dat, crit, id = "participant_id")
  withr::local_options(cohortflow.warn_missing_reason = TRUE)
  expect_no_warning(x <- as_narrative(flow))
  expect_match(x, "(age missing)", fixed = TRUE)
  expect_match(x, "(not meeting \"Aged 18 or over\")", fixed = TRUE)
  expect_match(x, "(withdrew consent)", fixed = TRUE)
  expect_no_match(x, "Age recorded", fixed = TRUE)
})

test_that("an include step without a reason inside a category does not warn", {
  withr::local_options(cohortflow.warn_missing_reason = TRUE)
  expect_no_warning(x <- as_narrative(make_flow_categorised()))
  expect_match(x, "not meeting \"Adults only\" (n = ", fixed = TRUE)
})

test_that("lowercase_reasons lower-cases all but acronyms", {
  flow <- make_flow_narrative_example()
  x <- as_narrative(flow)
  expect_match(x, "age missing (n = ", fixed = TRUE)
  expect_match(x, "BMI not recorded (", fixed = TRUE)
  y <- as_narrative(flow, lowercase_reasons = FALSE)
  expect_match(y, "Age missing (n = ", fixed = TRUE)
  expect_match(y, "BMI not recorded (", fixed = TRUE)
})

test_that("several reasons are listed with an Oxford comma", {
  expect_identical(cohortflow:::.oxford_join("a"), "a")
  expect_identical(cohortflow:::.oxford_join(c("a", "b")), "a and b")
  expect_identical(cohortflow:::.oxford_join(c("a", "b", "c")), "a, b, and c")

  dat <- mock_parallel_rct(n_participants = 300, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age recorded", reason = "Age missing", category = "Eligible") |>
    include(~ age >= 18, label = "Adult", reason = "Under 18", category = "Eligible") |>
    include(~ eligible_screen, label = "Screened", reason = "Failed screening", category = "Eligible")
  x <- as_narrative(apply_criteria(dat, crit, id = "participant_id"))
  expect_match(x, "age missing \\(n = \\d+\\), under 18 \\(n = \\d+\\), and failed screening \\(n = \\d+\\)")
})

test_that("a single removal reads 'was excluded'", {
  dat <- mock_parallel_rct(n_participants = 50, seed = 1)
  dat$flag <- seq_len(nrow(dat)) == 1L
  flow <- apply_criteria(dat, cf_criteria() |> exclude(~ flag, label = "Flagged"),
                         id = "participant_id")
  expect_match(as_narrative(flow), "1 (2.0%) was excluded (flagged)", fixed = TRUE)
})

test_that("big_mark groups thousands", {
  dat <- mock_parallel_rct(n_participants = 1500, seed = 1)
  flow <- apply_criteria(dat, cf_criteria() |> include(~ !is.na(age), label = "Age recorded"),
                         id = "participant_id")
  expect_match(as_narrative(flow), "Of 1,500 participants", fixed = TRUE)
  expect_match(as_narrative(flow, big_mark = ""), "Of 1500 participants", fixed = TRUE)
})

test_that("unit and assessed_label are used verbatim", {
  x <- as_narrative(make_flow_flat(), unit = "patients", assessed_label = "screened")
  expect_match(x, "^Of 200 patients screened, ")
  expect_match(x, "comprised \\d+ patients")
})

# -- Randomisation -------------------------------------------------------------

test_that("drop_randomise reports everything pooled", {
  x <- as_narrative(make_flow_randomise_multistep(), drop_randomise = TRUE)
  expect_no_match(x, "randomis")
  expect_no_match(x, "Control")
  expect_no_match(x, "Intervention")
})

test_that("nobody removed before randomisation reads 'All N ... were randomised'", {
  dat <- mock_parallel_rct(n_participants = 100, seed = 1)
  crit <- cf_criteria() |>
    randomise(by = "participant_id", arms = "arm") |>
    exclude(~ withdrew, label = "Withdrew")
  x <- as_narrative(apply_criteria(dat, crit, id = "participant_id"))
  expect_match(x, "^All 100 participants assessed for eligibility were randomised to Control")
  expect_match(x, "After randomisation, ")
})

test_that("arm counts match the CONSORT diagram", {
  flow <- make_flow_narrative_example()
  x <- as_narrative(flow)
  layout <- attr(as_consort_diagram(flow), "consort_layout")
  boxes  <- layout$branch_boxes

  arm_labels <- boxes$label[grepl("_label$", boxes$id)]
  for (lbl in arm_labels) {
    parts <- strsplit(lbl, "\n", fixed = TRUE)[[1L]]
    n <- sub("^\\(n=(.*)\\)$", "\\1", parts[2L])
    expect_match(x, sprintf("%s (n = %s)", parts[1L], n), fixed = TRUE)
  }

  # The last box of each arm's cascade is the arm's final count.
  for (b in unique(boxes$branch)) {
    arm   <- boxes[boxes$branch == b & !grepl("_label$", boxes$id), , drop = FALSE]
    last  <- arm$label[which.max(as.integer(sub(".*_box_", "", arm$id)))]
    n_end <- sub(".*\\(n=(.*)\\)$", "\\1", last)
    expect_match(x, sprintf("%s in %s", n_end, b), fixed = TRUE)
  }

  # Per-arm removals match the arm exclusion boxes.
  for (lbl in layout$branch_excl_boxes$label) {
    head <- strsplit(lbl, "\n", fixed = TRUE)[[1L]][1L]
    n <- sub("^.*?\\(n=([0-9]+(?:,[0-9]{3})*).*$", "\\1", head, perl = TRUE)
    expect_match(x, sprintf("%s (", n), fixed = TRUE)
  }
})

# -- Agreement with the attrition tibble ---------------------------------------

test_that("numbers agree with as_attrition_tibble()", {
  for (flow in list(make_flow_categorised(), make_flow_flat())) {
    tbl  <- as_attrition_tibble(flow)
    ints <- narrative_ints(as_narrative(flow))
    final_n <- tbl$n[tbl$row_type == "final"]
    expect_identical(ints, c(tbl$n[1L], attrition_removal_ints(tbl), final_n, final_n))
  }
})

test_that("count_by counts units and agrees with as_attrition_tibble(count_by = )", {
  flow <- make_flow_crossover()
  tbl  <- as_attrition_tibble(flow, count_by = "participant_id")
  ints <- narrative_ints(as_narrative(flow, count_by = "participant_id"))
  final_n <- tbl$n[tbl$row_type == "final"]
  expect_identical(ints, c(tbl$n[1L], attrition_removal_ints(tbl), final_n, final_n))
  expect_identical(tbl$n[1L], length(unique(flow$data$participant_id)))
  expect_false(identical(narrative_ints(as_narrative(flow))[1L], tbl$n[1L]))
})

test_that("count_by without a hierarchy errors as the table does", {
  expect_error(
    as_narrative(make_flow_flat(), count_by = "participant_id"),
    class = "cohortflow_count_by_hierarchy"
  )
})
