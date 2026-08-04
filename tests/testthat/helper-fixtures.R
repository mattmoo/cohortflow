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

make_flow_hierarchy <- function() {
  dat <- mock_cluster_rct(n_clusters = 10, n_participants = 300, seed = 1)
  h   <- cf_hierarchy(participant = "participant_id", cluster = "cluster_id")
  crit <- cf_criteria() |>
    include(~ !is.na(age),      label = "Age recorded",     category = "Valid age") |>
    include(~ age >= 18,        label = "Adults only",      category = "Valid age") |>
    group_include(by = "cluster_id", ~ n() >= 15, label = "Cluster size >= 15") |>
    exclude(~ withdrew,         label = "Withdrew consent", category = "Consent")
  apply_criteria(dat, crit, id = "participant_id", hierarchy = h)
}

make_flow_randomise <- function() {
  dat <- mock_cluster_rct(n_clusters = 8, n_participants = 200, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age recorded") |>
    randomise(by = "cluster_id", arms = "arm") |>
    exclude(~ withdrew,    label = "Withdrew after allocation")
  apply_criteria(dat, crit, id = "participant_id")
}

# Two post-randomisation exclusion steps (rather than one), so each arm's
# per-row cascade has multiple, closely-spaced exclusion boxes -- this is
# what actually exposes the arm-column overlap bug (an exclusion box drawn
# to the right of its own arm's column reaching into the next arm's main
# boxes), which a single post-randomisation step is too sparse to trigger.
make_flow_randomise_multistep <- function() {
  dat <- mock_parallel_rct(n_participants = 240, seed = 1)
  crit <- cf_criteria() |>
    include(~ !is.na(age), label = "Age recorded") |>
    include(~ age >= 18,   label = "Adults only") |>
    randomise(by = "participant_id", arms = "arm") |>
    exclude(~ withdrew,           label = "Withdrew after allocation") |>
    exclude(~ !baseline_complete, label = "Missed baseline visit")
  apply_criteria(dat, crit, id = "participant_id")
}
