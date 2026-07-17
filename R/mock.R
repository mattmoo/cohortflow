utils::globalVariables(c(
  "participant_id", "event_id", "cluster_id", "site_id", "period",
  "sequence", "age", "age_group", "sex", "ethnicity",
  "eligible_screen", "consent_date", "baseline_complete", "withdrew",
  "arm"
))

# ---------------------------------------------------------------------------
# Internal helpers shared by all mock_* generators
# ---------------------------------------------------------------------------

# Generate demographic columns (age, age_group, sex, ethnicity) for `n` rows.
# Deliberately introduces missingness in `age` to give criteria something to
# exclude on.
.mock_demographics <- function(n) {
  age_raw <- round(stats::rnorm(n, mean = 45, sd = 15))
  age_raw[age_raw < 5]  <- 5L    # floor at 5
  age_raw[age_raw > 90] <- 90L   # cap at 90
  if (n > 0L) {
    age_raw[sample(n, max(1L, round(0.05 * n)))] <- NA_real_
  }

  age_group <- dplyr::case_when(
    is.na(age_raw)  ~ NA_character_,
    age_raw < 18    ~ "<18",
    age_raw < 40    ~ "18-39",
    age_raw < 65    ~ "40-64",
    TRUE            ~ "65+"
  )

  sex <- sample(c("M", "F", "O"), n, replace = TRUE,
                prob = c(0.48, 0.48, 0.04))

  ethnicities <- c("European", "Maori", "Pacific", "Asian", "Other")
  ethnicity   <- sample(ethnicities, n, replace = TRUE,
                        prob = c(0.60, 0.15, 0.09, 0.12, 0.04))

  tibble::tibble(
    age       = age_raw,
    age_group = age_group,
    sex       = sex,
    ethnicity = ethnicity
  )
}

# Generate screening/consent/baseline/withdrawal columns for `n` rows,
# mimicking a typical trial pipeline: ~10% fail screening, 85% of eligible
# consent, 90% of consented complete baseline, 5% of baseline-completers
# withdraw.
.mock_consent_flow <- function(n) {
  eligible_screen <- stats::runif(n) > 0.10

  consent_prob <- ifelse(eligible_screen, 0.85, 0)
  consented    <- stats::runif(n) < consent_prob

  origin       <- as.Date("2023-01-01")
  consent_date <- as.Date(
    ifelse(consented,
           as.numeric(origin) + sample(0:364, n, replace = TRUE),
           NA_real_),
    origin = "1970-01-01"
  )

  baseline_complete <- consented & (stats::runif(n) < 0.90)
  withdrew          <- baseline_complete & (stats::runif(n) < 0.05)

  tibble::tibble(
    eligible_screen   = eligible_screen,
    consent_date      = consent_date,
    baseline_complete = baseline_complete,
    withdrew          = withdrew
  )
}

# Zero-pad an integer id vector with a prefix, e.g. .mock_ids("P", 1:5).
.mock_ids <- function(prefix, i, width = NULL) {
  if (is.null(width)) width <- max(2L, nchar(as.character(max(i, 1L))))
  paste0(prefix, formatC(i, width = width, flag = "0"))
}

# Emit a one-time-per-session deprecation warning for mock_cohortflow().
.deprecate_mock_cohortflow <- function() {
  rlang::warn(
    paste(
      "`mock_cohortflow()` is deprecated. Use a design-specific generator",
      "instead: mock_parallel_rct(), mock_crossover(), mock_cluster_rct(),",
      "or mock_stepped_wedge()."
    )
  )
}


#' Generate synthetic cohort data for testing and examples (deprecated)
#'
#' @description
#' **Deprecated.** `mock_cohortflow()` is deprecated in favour of
#' design-specific generators that produce realistic data for common study
#' designs: [mock_parallel_rct()], [mock_crossover()], [mock_cluster_rct()],
#' and [mock_stepped_wedge()]. Those functions include an explicit `arm`
#' column and design-appropriate structure (e.g. cluster-level
#' randomisation, within-participant crossover sequences, stepped-wedge
#' roll-out), which `mock_cohortflow()` never modelled.
#'
#' Produces a tibble that mimics a clustered cohort study with optional
#' stepped-wedge period structure. The returned data is deliberately
#' imperfect: some participants have missing values, withdrew consent, or
#' failed screening, so that inclusion/exclusion criteria have something to
#' remove.
#'
#' @param n_participants Integer. Total number of participant rows.
#' @param n_clusters Integer. Number of clusters (e.g., GP practices, schools).
#' @param n_sites Integer. Number of sites (clusters are nested in sites;
#'   must be <= `n_clusters`).
#' @param n_periods Integer. Number of time periods (e.g., waves in a
#'   stepped-wedge design). Set to `1` for a simple cross-sectional cohort.
#' @param seed Integer. Random seed for reproducibility.
#'
#' @return A [tibble::tibble()] with columns:
#' \describe{
#'   \item{`participant_id`}{Character. Unique participant identifier.}
#'   \item{`event_id`}{Character. Unique event (row) identifier -- useful when
#'     the dataset has multiple rows per participant (e.g., one per operation).}
#'   \item{`cluster_id`}{Character. Cluster identifier.}
#'   \item{`site_id`}{Character. Site identifier (clusters nested in sites).}
#'   \item{`period`}{Integer. Study period (1 = first period).}
#'   \item{`sequence`}{Integer. Stepped-wedge sequence the cluster is assigned
#'     to (NA if `n_periods == 1`).}
#'   \item{`age`}{Numeric. Age in years (some NAs to simulate missing data).}
#'   \item{`age_group`}{Character. Age group (`"<18"`, `"18-39"`, `"40-64"`, `"65+"`).}
#'   \item{`sex`}{Character. `"M"` / `"F"` / `"O"` (other).}
#'   \item{`ethnicity`}{Character. One of five broad ethnic groups.}
#'   \item{`consent_date`}{Date. Date of consent (NA = did not consent).}
#'   \item{`baseline_complete`}{Logical. Whether the baseline assessment is
#'     complete.}
#'   \item{`withdrew`}{Logical. Whether the participant withdrew after consent.}
#'   \item{`eligible_screen`}{Logical. Whether the participant passed initial
#'     eligibility screening (e.g., diagnosis confirmed).}
#' }
#' @export
#'
#' @examples
#' mock_cohortflow()
#'
#' # Larger study with three periods
#' mock_cohortflow(n_participants = 2000, n_clusters = 20, n_periods = 3, seed = 42)
mock_cohortflow <- function(
  n_participants = 500L,
  n_clusters     = 10L,
  n_sites        = 3L,
  n_periods      = 4L,
  seed           = 123L
) {
  .deprecate_mock_cohortflow()

  n_participants <- as.integer(n_participants)
  n_clusters     <- as.integer(n_clusters)
  n_sites        <- as.integer(n_sites)
  n_periods      <- as.integer(n_periods)

  if (n_sites > n_clusters) {
    rlang::abort("`n_sites` must be <= `n_clusters`.")
  }

  set.seed(seed)

  # -- Cluster / site / sequence structure ----------------------------------
  cluster_ids <- paste0("C", sprintf("%02d", seq_len(n_clusters)))
  site_ids    <- paste0("S", seq_len(n_sites))

  # Assign each cluster to a site and a stepped-wedge sequence
  cluster_tbl <- tibble::tibble(
    cluster_id = cluster_ids,
    site_id    = sample(site_ids, n_clusters, replace = TRUE),
    sequence   = if (n_periods > 1L) {
      # Sequences are 1..n_periods, spread across clusters
      ((seq_len(n_clusters) - 1L) %% n_periods) + 1L
    } else {
      NA_integer_
    }
  )

  # -- Participant rows -------------------------------------------------------
  pid <- paste0("P", sprintf("%04d", seq_len(n_participants)))

  # Imbalanced cluster sizes: Dirichlet-like draw (Gamma shape=0.5 gives high
  # variance -- some clusters will be 3-5x larger than others)
  cluster_weights <- stats::rgamma(n_clusters, shape = 0.5)
  cluster_probs   <- cluster_weights / sum(cluster_weights)
  cluster_draw    <- sample(cluster_ids, n_participants, replace = TRUE,
                            prob = cluster_probs)

  period_draw  <- sample(seq_len(n_periods), n_participants, replace = TRUE)

  demog <- .mock_demographics(n_participants)
  flow  <- .mock_consent_flow(n_participants)

  participants <- tibble::tibble(
    participant_id    = pid,
    event_id          = paste0("E", sprintf("%04d", seq_len(n_participants))),
    cluster_id        = cluster_draw,
    period            = period_draw,
    age               = demog$age,
    age_group         = demog$age_group,
    sex               = demog$sex,
    ethnicity         = demog$ethnicity,
    eligible_screen   = flow$eligible_screen,
    consent_date      = flow$consent_date,
    baseline_complete = flow$baseline_complete,
    withdrew          = flow$withdrew
  )

  # Join cluster attributes (site, sequence)
  out <- dplyr::left_join(participants, cluster_tbl, by = "cluster_id")

  # Reorder columns logically
  out <- dplyr::select(
    out,
    participant_id, event_id, cluster_id, site_id, period, sequence,
    age, age_group, sex, ethnicity,
    eligible_screen, consent_date, baseline_complete, withdrew
  )

  out
}
