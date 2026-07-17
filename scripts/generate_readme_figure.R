if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  install.packages(".", repos = NULL, type = "source", quiet = TRUE)
  library(cohortflow)
}

dat <- mock_parallel_rct(n_participants = 220, seed = 7)

crit <- cf_criteria() |>
  include(~ !is.na(age), label = "Age recorded", category = "Age") |>
  include(~ age >= 18, label = "Adults only", category = "Age") |>
  include(~ eligible_screen, label = "Passed screening", category = "Screening") |>
  exclude(~ withdrew, label = "Withdrew consent")

flow <- apply_criteria(dat, crit)
diagram <- as_consort_diagram(flow, title = "cohortflow CONSORT preview")

dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)

png("man/figures/consort-diagram-preview.png", width = 1400, height = 1000, res = 150)
print(diagram)
dev.off()

message("Wrote man/figures/consort-diagram-preview.png")