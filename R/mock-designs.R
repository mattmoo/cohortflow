# ===========================================================================
# Design-specific synthetic data generators
# ===========================================================================
#
# These functions replace mock_cohortflow() (now deprecated) with generators
# tailored to specific study designs. Each embeds realistic imperfections
# (missing data, failed screening, non-consent, withdrawal) so that
# cohortflow's include()/exclude() criteria have something to remove, and
# each includes an explicit `arm` column reflecting the design's
# randomisation/allocation structure.

#' Generate synthetic data for a parallel-group randomised controlled trial
#'
#' Produces one row per participant, individually randomised to one of
#' `length(arm_labels)` arms with equal allocation. No clustering or
#' repeated measures -- the simplest of the four designs.
#'
#' @param n_participants Integer. Total number of participants.
#' @param arm_labels Character vector. Labels for the trial arms (allocation
#'   is balanced across these labels).
#' @param seed Integer. Random seed for reproducibility.
#'
#' @return A [tibble::tibble()] with one row per participant, including
#'   `participant_id`, `arm`, demographic columns (`age`, `age_group`,
#'   `sex`, `ethnicity`), and consent-flow columns (`eligible_screen`,
#'   `consent_date`, `baseline_complete`, `withdrew`).
#' @export
#'
#' @examples
#' mock_parallel_rct()
#' mock_parallel_rct(n_participants = 300, arm_labels = c("Placebo", "Drug"), seed = 7)
mock_parallel_rct <- function(
  n_participants = 300L,
  arm_labels     = c("Control", "Intervention"),
  seed           = 123L
) {
  n_participants <- as.integer(n_participants)
  arm_labels     <- as.character(arm_labels)

  if (length(arm_labels) < 2L) {
    rlang::abort("`arm_labels` must have at least two elements.")
  }

  set.seed(seed)

  pid <- .mock_ids("P", seq_len(n_participants), width = 4L)
  arm <- sample(arm_labels, n_participants, replace = TRUE)

  demog <- .mock_demographics(n_participants)
  flow  <- .mock_consent_flow(n_participants)

  out <- tibble::tibble(
    participant_id    = pid,
    arm               = arm,
    age               = demog$age,
    age_group         = demog$age_group,
    sex               = demog$sex,
    ethnicity         = demog$ethnicity,
    eligible_screen   = flow$eligible_screen,
    consent_date      = flow$consent_date,
    baseline_complete = flow$baseline_complete,
    withdrew          = flow$withdrew
  )

  out
}

#' Generate synthetic data for a crossover trial
#'
#' Produces one row per participant per period. Each participant is assigned
#' a randomisation `sequence` (e.g. `"AB"` or `"BA"` for a two-period,
#' two-treatment design), and the `arm` in each period is derived from that
#' sequence -- so participants genuinely switch treatments across periods
#' rather than `arm` being an unused label.
#'
#' @param n_participants Integer. Number of participants.
#' @param arm_labels Character vector. Labels for the treatments being
#'   crossed over. Determines both the number of periods
#'   (`length(arm_labels)`) and the number of possible sequences
#'   (all permutations of `arm_labels`).
#' @param seed Integer. Random seed for reproducibility.
#'
#' @return A [tibble::tibble()] with one row per participant per period,
#'   including `participant_id`, `event_id`, `period`, `sequence`, `arm`,
#'   demographic columns, and consent-flow columns. Consent-flow columns
#'   (`eligible_screen`, `consent_date`, `baseline_complete`, `withdrew`)
#'   are constant within a participant across periods, since they describe
#'   trial-level (not period-level) status; `withdrew` reflects withdrawal
#'   at any point during the trial.
#' @export
#'
#' @examples
#' mock_crossover()
#' mock_crossover(n_participants = 60, arm_labels = c("Drug", "Placebo"), seed = 3)
mock_crossover <- function(
  n_participants = 120L,
  arm_labels     = c("A", "B"),
  seed           = 123L
) {
  n_participants <- as.integer(n_participants)
  arm_labels     <- as.character(arm_labels)
  n_periods      <- length(arm_labels)

  if (n_periods < 2L) {
    rlang::abort("`arm_labels` must have at least two elements.")
  }

  set.seed(seed)

  # All permutations of arm_labels are candidate sequences (e.g. AB/BA)
  seq_perms  <- .permutations(arm_labels)
  seq_labels <- vapply(seq_perms, paste0, character(1), collapse = "")

  pid          <- .mock_ids("P", seq_len(n_participants), width = 4L)
  participant_seq <- sample(seq_labels, n_participants, replace = TRUE)

  demog <- .mock_demographics(n_participants)
  flow  <- .mock_consent_flow(n_participants)

  participants <- tibble::tibble(
    participant_id    = pid,
    sequence          = participant_seq,
    age               = demog$age,
    age_group         = demog$age_group,
    sex               = demog$sex,
    ethnicity         = demog$ethnicity,
    eligible_screen   = flow$eligible_screen,
    consent_date      = flow$consent_date,
    baseline_complete = flow$baseline_complete,
    withdrew          = flow$withdrew
  )

  # Expand to one row per participant per period, deriving `arm` from
  # the participant's sequence and the current period.
  out <- participants[rep(seq_len(n_participants), each = n_periods), ]
  out$period <- rep(seq_len(n_periods), times = n_participants)
  out$arm    <- vapply(
    seq_len(nrow(out)),
    function(i) {
      seq_i <- match(out$sequence[[i]], seq_labels)
      seq_perms[[seq_i]][[out$period[[i]]]]
    },
    character(1)
  )
  out$event_id <- .mock_ids("E", seq_len(nrow(out)), width = 5L)

  out <- dplyr::select(
    out,
    participant_id, event_id, period, sequence, arm,
    age, age_group, sex, ethnicity,
    eligible_screen, consent_date, baseline_complete, withdrew
  )

  tibble::as_tibble(out)
}

#' Generate synthetic data for a cluster-randomised controlled trial
#'
#' Produces one row per participant, nested within clusters (e.g. GP
#' practices, schools) that are themselves nested within sites. Each
#' cluster -- not each participant -- is randomised to an arm, so all
#' participants within a cluster share the same `arm`.
#'
#' @param n_clusters Integer. Number of clusters.
#' @param n_participants Integer. Total number of participants, distributed
#'   unevenly across clusters.
#' @param n_sites Integer. Number of sites (clusters nested in sites; must
#'   be <= `n_clusters`).
#' @param arm_labels Character vector. Labels for the trial arms; clusters
#'   are allocated to these labels with balanced randomisation.
#' @param seed Integer. Random seed for reproducibility.
#'
#' @return A [tibble::tibble()] with one row per participant, including
#'   `participant_id`, `cluster_id`, `site_id`, `arm` (cluster-level),
#'   demographic columns, and consent-flow columns.
#' @export
#'
#' @examples
#' mock_cluster_rct()
#' mock_cluster_rct(n_clusters = 20, n_participants = 800, seed = 5)
mock_cluster_rct <- function(
  n_clusters     = 12L,
  n_participants = 480L,
  n_sites        = 3L,
  arm_labels     = c("Control", "Intervention"),
  seed           = 123L
) {
  n_clusters     <- as.integer(n_clusters)
  n_participants <- as.integer(n_participants)
  n_sites        <- as.integer(n_sites)
  arm_labels     <- as.character(arm_labels)

  if (n_sites > n_clusters) {
    rlang::abort("`n_sites` must be <= `n_clusters`.")
  }
  if (length(arm_labels) < 2L) {
    rlang::abort("`arm_labels` must have at least two elements.")
  }

  set.seed(seed)

  cluster_ids <- .mock_ids("C", seq_len(n_clusters), width = 2L)
  site_ids    <- paste0("S", seq_len(n_sites))

  # Balanced cluster-level randomisation: allocate clusters to arms as
  # evenly as possible, then shuffle.
  cluster_arm <- rep(arm_labels, length.out = n_clusters)
  cluster_arm <- sample(cluster_arm)

  cluster_tbl <- tibble::tibble(
    cluster_id = cluster_ids,
    site_id    = sample(site_ids, n_clusters, replace = TRUE),
    arm        = cluster_arm
  )

  # Imbalanced cluster sizes (Gamma shape=0.5 gives high variance)
  cluster_weights <- stats::rgamma(n_clusters, shape = 0.5)
  cluster_probs   <- cluster_weights / sum(cluster_weights)
  cluster_draw    <- sample(cluster_ids, n_participants, replace = TRUE,
                            prob = cluster_probs)

  pid <- .mock_ids("P", seq_len(n_participants), width = 4L)

  demog <- .mock_demographics(n_participants)
  flow  <- .mock_consent_flow(n_participants)

  participants <- tibble::tibble(
    participant_id    = pid,
    cluster_id        = cluster_draw,
    age               = demog$age,
    age_group         = demog$age_group,
    sex               = demog$sex,
    ethnicity         = demog$ethnicity,
    eligible_screen   = flow$eligible_screen,
    consent_date      = flow$consent_date,
    baseline_complete = flow$baseline_complete,
    withdrew          = flow$withdrew
  )

  out <- dplyr::left_join(participants, cluster_tbl, by = "cluster_id")
  out <- dplyr::select(
    out,
    participant_id, cluster_id, site_id, arm,
    age, age_group, sex, ethnicity,
    eligible_screen, consent_date, baseline_complete, withdrew
  )

  out
}

#' Generate synthetic data for a stepped-wedge cluster-randomised trial
#'
#' Produces one row per participant per period, with clusters nested within
#' sites. Each cluster is assigned a crossover `sequence` -- the period in
#' which it switches from control to intervention -- and every cluster
#' eventually receives the intervention (the defining feature of a stepped
#' wedge). The `arm` for a given participant-period row is derived from
#' whether the current `period` has reached the cluster's `sequence`
#' (`period >= sequence`), so treatment assignment is genuinely driven by
#' the roll-out schedule rather than an unused column.
#'
#' @param n_clusters Integer. Number of clusters.
#' @param n_participants Integer. Total number of participants (each
#'   contributes one row per period), distributed unevenly across clusters.
#' @param n_periods Integer. Number of periods, including the initial
#'   all-control period. Must be >= 2 (clusters need at least one period
#'   before crossover and one after).
#' @param n_sites Integer. Number of sites (clusters nested in sites; must
#'   be <= `n_clusters`).
#' @param arm_labels Character vector of length 2: `c(control_label,
#'   intervention_label)`.
#' @param seed Integer. Random seed for reproducibility.
#'
#' @return A [tibble::tibble()] with one row per participant per period,
#'   including `participant_id`, `event_id`, `cluster_id`, `site_id`,
#'   `period`, `sequence`, `arm` (derived from `period >= sequence`),
#'   demographic columns, and consent-flow columns.
#' @export
#'
#' @examples
#' mock_stepped_wedge()
#' mock_stepped_wedge(n_clusters = 8, n_participants = 400, n_periods = 5, seed = 9)
mock_stepped_wedge <- function(
  n_clusters     = 12L,
  n_participants = 480L,
  n_periods      = 4L,
  n_sites        = 3L,
  arm_labels     = c("Control", "Intervention"),
  seed           = 123L
) {
  n_clusters     <- as.integer(n_clusters)
  n_participants <- as.integer(n_participants)
  n_periods      <- as.integer(n_periods)
  n_sites        <- as.integer(n_sites)
  arm_labels     <- as.character(arm_labels)

  if (n_sites > n_clusters) {
    rlang::abort("`n_sites` must be <= `n_clusters`.")
  }
  if (n_periods < 2L) {
    rlang::abort("`n_periods` must be >= 2 for a stepped-wedge design.")
  }
  if (length(arm_labels) != 2L) {
    rlang::abort("`arm_labels` must have exactly two elements: c(control, intervention).")
  }

  set.seed(seed)

  cluster_ids <- .mock_ids("C", seq_len(n_clusters), width = 2L)
  site_ids    <- paste0("S", seq_len(n_sites))

  # Sequence = the period in which the cluster crosses over to intervention.
  # Sequences run from 2..n_periods so every cluster spends >=1 period as
  # control and >=1 period as intervention.
  cluster_tbl <- tibble::tibble(
    cluster_id = cluster_ids,
    site_id    = sample(site_ids, n_clusters, replace = TRUE),
    sequence   = ((seq_len(n_clusters) - 1L) %% (n_periods - 1L)) + 2L
  )

  cluster_weights <- stats::rgamma(n_clusters, shape = 0.5)
  cluster_probs   <- cluster_weights / sum(cluster_weights)
  cluster_draw    <- sample(cluster_ids, n_participants, replace = TRUE,
                            prob = cluster_probs)

  pid <- .mock_ids("P", seq_len(n_participants), width = 4L)

  demog <- .mock_demographics(n_participants)
  flow  <- .mock_consent_flow(n_participants)

  participants <- tibble::tibble(
    participant_id    = pid,
    cluster_id        = cluster_draw,
    age               = demog$age,
    age_group         = demog$age_group,
    sex               = demog$sex,
    ethnicity         = demog$ethnicity,
    eligible_screen   = flow$eligible_screen,
    consent_date      = flow$consent_date,
    baseline_complete = flow$baseline_complete,
    withdrew          = flow$withdrew
  )

  participants <- dplyr::left_join(participants, cluster_tbl, by = "cluster_id")

  # Expand to one row per participant per period
  out <- participants[rep(seq_len(n_participants), each = n_periods), ]
  out$period <- rep(seq_len(n_periods), times = n_participants)

  control_label      <- arm_labels[[1]]
  intervention_label <- arm_labels[[2]]
  out$arm <- ifelse(out$period >= out$sequence, intervention_label, control_label)

  out$event_id <- .mock_ids("E", seq_len(nrow(out)), width = 5L)

  out <- dplyr::select(
    out,
    participant_id, event_id, cluster_id, site_id, period, sequence, arm,
    age, age_group, sex, ethnicity,
    eligible_screen, consent_date, baseline_complete, withdrew
  )

  tibble::as_tibble(out)
}

# ---------------------------------------------------------------------------
# Internal utility: all permutations of a vector (used by mock_crossover())
# ---------------------------------------------------------------------------

.permutations <- function(x) {
  n <- length(x)
  if (n <= 1L) return(list(x))
  perms <- list()
  for (i in seq_len(n)) {
    rest <- .permutations(x[-i])
    for (r in rest) {
      perms[[length(perms) + 1L]] <- c(x[[i]], r)
    }
  }
  perms
}
