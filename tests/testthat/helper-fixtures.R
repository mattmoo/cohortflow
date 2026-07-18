# ===========================================================================
# Shared test fixtures
# ===========================================================================
#
# testthat auto-sources helper-*.R files before running tests, so these
# builders are available to every test file without duplication.

# ---------------------------------------------------------------------------
# Generic (mock_cohortflow-based) fixtures
# ---------------------------------------------------------------------------

make_flow_categorised <- function() {
  dat <- suppressWarnings(mock_cohortflow(n_participants = 200, seed = 1))
  crit <- cf_criteria() |>
    include(~ !is.na(age),          label = "Age recorded",     category = "Valid age") |>
    include(~ age >= 18,            label = "Adults only",      category = "Valid age") |>
    include(~ eligible_screen,      label = "Passed screening", category = "Eligible at screening") |>
    include(~ !is.na(consent_date), label = "Consent recorded", category = "Consent") |>
    exclude(~ withdrew,             label = "Withdrew consent", category = "Consent")
  apply_criteria(dat, crit)
}

make_flow_flat <- function() {
  dat <- suppressWarnings(mock_cohortflow(n_participants = 200, seed = 1))
  crit <- cf_criteria() |>
    include(~ !is.na(age),          label = "Age recorded") |>
    include(~ age >= 18,            label = "Adults only") |>
    include(~ !is.na(consent_date), label = "Consent recorded") |>
    exclude(~ withdrew,             label = "Withdrew consent")
  apply_criteria(dat, crit)
}

make_flow_no_exclusions <- function() {
  dat <- suppressWarnings(mock_cohortflow(n_participants = 100, seed = 42))
  # A criterion that keeps everyone
  crit <- cf_criteria() |>
    include(~ !is.na(participant_id), label = "Has ID")
  apply_criteria(dat, crit)
}

# ---------------------------------------------------------------------------
# Design-specific fixtures
# ---------------------------------------------------------------------------

make_flow_parallel_rct <- function() {
  dat <- mock_parallel_rct(n_participants = 200, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age),          label = "Age recorded",     category = "Valid age") |>
    include(~ age >= 18,            label = "Adults only",      category = "Valid age") |>
    include(~ eligible_screen,      label = "Passed screening", category = "Eligible at screening") |>
    include(~ !is.na(consent_date), label = "Consent recorded", category = "Consent") |>
    exclude(~ withdrew,             label = "Withdrew consent", category = "Consent")
  apply_criteria(dat, crit)
}

make_flow_crossover <- function() {
  dat <- mock_crossover(n_participants = 80, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age),          label = "Age recorded",     category = "Valid age") |>
    include(~ age >= 18,            label = "Adults only",      category = "Valid age") |>
    include(~ eligible_screen,      label = "Passed screening", category = "Eligible at screening") |>
    include(~ !is.na(consent_date), label = "Consent recorded", category = "Consent") |>
    exclude(~ withdrew,             label = "Withdrew consent", category = "Consent")
  apply_criteria(dat, crit, id = "event_id")
}

make_flow_cluster_rct <- function() {
  dat <- mock_cluster_rct(n_clusters = 10, n_participants = 300, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age),          label = "Age recorded",     category = "Valid age") |>
    include(~ age >= 18,            label = "Adults only",      category = "Valid age") |>
    include(~ eligible_screen,      label = "Passed screening", category = "Eligible at screening") |>
    include(~ !is.na(consent_date), label = "Consent recorded", category = "Consent") |>
    exclude(~ withdrew,             label = "Withdrew consent", category = "Consent")
  apply_criteria(dat, crit)
}

make_flow_stepped_wedge <- function() {
  dat <- mock_stepped_wedge(n_clusters = 10, n_participants = 300,
                            n_periods = 4, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age),          label = "Age recorded",     category = "Valid age") |>
    include(~ age >= 18,            label = "Adults only",      category = "Valid age") |>
    include(~ eligible_screen,      label = "Passed screening", category = "Eligible at screening") |>
    include(~ !is.na(consent_date), label = "Consent recorded", category = "Consent") |>
    exclude(~ withdrew,             label = "Withdrew consent", category = "Consent")
  apply_criteria(dat, crit, id = "event_id")
}
