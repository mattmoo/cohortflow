if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE)
} else {
  install.packages(".", repos = NULL, type = "source", quiet = TRUE)
  library(cohortflow)
}

dat <- mock_cohortflow(n_participants = 220, seed = 7)
crit <- cf_criteria() |>
  include(~ !is.na(age), label = "Age recorded", category = "Age") |>
  include(~ age >= 18, label = "Adults only", category = "Age") |>
  include(~ eligible_screen, label = "Passed screening", category = "Screening") |>
  exclude(~ withdrew, label = "Withdrew consent")

flow <- apply_criteria(dat, crit)
tab <- as_attrition_tibble(flow)

dir.create("man/figures", recursive = TRUE, showWarnings = FALSE)

labels <- rev(as.character(tab$label))
removed <- rev(as.numeric(tab$n_removed))
removed[is.na(removed)] <- 0
row_types <- rev(as.character(tab$row_type))

cols <- ifelse(
  row_types %in% c("header", "final"),
  "#4C78A8",
  ifelse(row_types == "category", "#72B7B2", "#F58518")
)

png("man/figures/attrition-tibble-preview.png", width = 1400, height = 820, res = 150)
par(mar = c(4, 15, 4, 2))
barplot(
  height = removed,
  horiz = TRUE,
  names.arg = labels,
  las = 1,
  col = cols,
  border = NA,
  xlab = "Participants removed at each row"
)
title("cohortflow attrition preview (n_removed)")
legend(
  "topright",
  legend = c("header/final", "category", "step"),
  fill = c("#4C78A8", "#72B7B2", "#F58518"),
  bty = "n"
)
dev.off()

message("Wrote man/figures/attrition-tibble-preview.png")
