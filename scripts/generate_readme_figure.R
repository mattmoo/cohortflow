if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  install.packages(".", repos = NULL, type = "source", quiet = TRUE)
  library(cohortflow)
}

dat <- mock_parallel_rct(n_participants = 220, seed = 7)

crit <- cf_criteria() |>
  include(~ !is.na(age), label = "Age recorded", reason = "Age missing",
          category = "Valid age") |>
  include(~ age >= 18, label = "Adults only", reason = "Under 18", category = "Valid age") |>
  include(~ eligible_screen, label = "Passed screening", reason = "Failed screening") |>
  exclude(~ withdrew, label = "Withdrew consent")

flow <- apply_criteria(dat, crit, id = "participant_id")
diagram <- as_consort_diagram(flow, title = "cohortflow CONSORT preview")

dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)

save_consort_diagram(diagram, "man/figures/consort-diagram-preview.png", dpi = 150)

message("Wrote man/figures/consort-diagram-preview.png")