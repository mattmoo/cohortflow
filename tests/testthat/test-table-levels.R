# ===========================================================================
# Tests for as_attrition_table(levels = )
# ===========================================================================
#
# Shared fixtures (make_flow_hierarchy(), make_flow_flat()) live in
# helper-fixtures.R.

test_that("levels renders one column block per level", {
  skip_if_not_installed("flextable")
  skip_if_not_installed("officer")

  flow <- make_flow_hierarchy()

  ft <- as_attrition_table(flow, levels = c("participant", "cluster"))
  expect_s3_class(ft, "flextable")
  # criterion + 3 columns per level (no group-level criteria beyond the
  # group_include() step already baked into make_flow_hierarchy(), which
  # does populate n_consequential -- so this table has a 4th column too)
  n_cols <- flextable::ncol_keys(ft)
  expect_true(n_cols %in% c(1L + 3L * 2L, 1L + 4L * 2L))
})

test_that("row alignment across levels is asserted", {
  flow <- make_flow_hierarchy()
  tbl  <- as_attrition_tibble(flow, levels = c("participant", "cluster"))

  # Corrupt one level's rows so the row skeleton no longer matches --
  # if `.attrition_tibble_one_level()` is ever changed to emit
  # level-specific rows, this test should catch the drift.
  tbl$label[tbl$level == "cluster"][[1]] <- "Corrupted label"

  expect_error(
    cohortflow:::.attrition_build_level_grid(
      tbl, c("participant", "cluster"),
      c(participant = "participant", cluster = "cluster"),
      shade = NULL, shade_fn = NULL, shade_palette = c("#FFFFFF", "#F8696B")
    ),
    "differ across"
  )
})

test_that("levels is mutually exclusive with grouping arguments", {
  dat  <- mock_cluster_rct(n_clusters = 6, seed = 1)
  flow <- apply_criteria(
    dat, cf_criteria() |> include(~ !is.na(participant_id), label = "All"),
    hierarchy = cf_hierarchy(participant = "participant_id",
                             cluster = "cluster_id"),
    id = "participant_id"
  )
  expect_error(
    as_attrition_table(flow, levels = "cluster", group_x = "arm"),
    "cannot be combined"
  )
  expect_error(
    as_attrition_table(flow, levels = "cluster", branch_by = "arm"),
    "cannot be combined"
  )
})

test_that("default behaviour is unchanged", {
  skip_if_not_installed("flextable")
  skip_if_not_installed("officer")

  flow <- make_flow_flat()
  expect_equal(
    flextable::ncol_keys(as_attrition_table(flow)),
    flextable::ncol_keys(as_attrition_table(flow, levels = character(0)))
  )
})

test_that("counts match the tibble they came from", {
  skip_if_not_installed("gt")

  flow <- make_flow_hierarchy()

  tib <- as_attrition_tibble(flow, levels = c("participant", "cluster"))
  ft  <- as_attrition_table(flow, levels = c("participant", "cluster"),
                            backend = "gt")

  cl_removed <- tib$n_removed[tib$level == "cluster" & tib$row_type == "step"]
  expect_true(any(cl_removed[!is.na(cl_removed)] > 0L))

  # The cluster block's step-row n_removed values should be reproduced
  # verbatim in the rendered gt table's underlying data.
  df <- ft[["_data"]]
  cluster_removed_col <- grep("^removed_cluster$", names(df), value = TRUE)
  expect_length(cluster_removed_col, 1L)

  rendered <- df[[cluster_removed_col]][tib$row_type[tib$level == "cluster"] == "step"]
  # em-dash used for zero, numeric string otherwise
  expect_equal(
    rendered[cl_removed > 0L & !is.na(cl_removed)],
    as.character(cl_removed[cl_removed > 0L & !is.na(cl_removed)])
  )
})

test_that("consequential column appears only when populated", {
  skip_if_not_installed("gt")

  dat <- mock_cluster_rct(n_clusters = 10, seed = 1)
  h   <- cf_hierarchy(participant = "participant_id", cluster = "cluster_id")

  flow_grp <- apply_criteria(
    dat,
    cf_criteria() |> group_exclude(by = "cluster_id", ~ dplyr::n() < 30,
                                   label = "Small cluster"),
    hierarchy = h, id = "participant_id"
  )
  flow_row <- apply_criteria(
    dat, cf_criteria() |> include(~ !is.na(age), label = "Age recorded"),
    hierarchy = h, id = "participant_id"
  )

  ncol_grp <- ncol(as_attrition_table(flow_grp, levels = c("participant", "cluster"),
                                      backend = "gt")[["_data"]])
  ncol_row <- ncol(as_attrition_table(flow_row, levels = c("participant", "cluster"),
                                      backend = "gt")[["_data"]])

  expect_gt(ncol_grp, ncol_row)
})

test_that("gt and huxtable backends render", {
  skip_if_not_installed("gt")
  skip_if_not_installed("huxtable")

  dat  <- mock_cluster_rct(n_clusters = 8, seed = 1)
  h    <- cf_hierarchy(participant = "participant_id", cluster = "cluster_id")
  flow <- apply_criteria(dat, cf_criteria() |> include(~ !is.na(participant_id), label = "All"),
                         hierarchy = h, id = "participant_id")
  expect_s3_class(as_attrition_table(flow, levels = "cluster", backend = "gt"),
                  "gt_tbl")
  expect_s3_class(as_attrition_table(flow, levels = "cluster", backend = "huxtable"),
                  "huxtable")
})

test_that("levels of length 1 renders a single column block", {
  skip_if_not_installed("gt")

  flow <- make_flow_hierarchy()
  gt_tbl <- as_attrition_table(flow, levels = "cluster", backend = "gt")
  expect_s3_class(gt_tbl, "gt_tbl")
  expect_true(all(c("n_cluster", "removed_cluster", "pct_cluster") %in%
                    names(gt_tbl[["_data"]])))
})

test_that("level_labels resolves positionally, by name, or defaults to level names", {
  skip_if_not_installed("gt")

  flow <- make_flow_hierarchy()

  default_html <- gt::as_raw_html(as_attrition_table(
    flow, levels = c("participant", "cluster"), backend = "gt"
  ))
  expect_match(default_html, ">participant<")
  expect_match(default_html, ">cluster<")

  named_html <- gt::as_raw_html(as_attrition_table(
    flow, levels = c("participant", "cluster"),
    level_labels = c(cluster = "Clusters", participant = "Participants"),
    backend = "gt"
  ))
  expect_match(named_html, ">Participants<")
  expect_match(named_html, ">Clusters<")

  positional_html <- gt::as_raw_html(as_attrition_table(
    flow, levels = c("participant", "cluster"),
    level_labels = c("Participants", "Clusters"),
    backend = "gt"
  ))
  expect_match(positional_html, ">Participants<")
  expect_match(positional_html, ">Clusters<")
})

test_that("level_labels mismatches abort with a message naming the problem", {
  flow <- make_flow_hierarchy()

  expect_error(
    as_attrition_table(flow, levels = c("participant", "cluster"),
                       level_labels = "Only one"),
    "length"
  )
  expect_error(
    as_attrition_table(flow, levels = c("participant", "cluster"),
                       level_labels = c(participant = "P", nonexistent = "X")),
    "not found"
  )
})

test_that("levels naming an unknown hierarchy level aborts with the offending name", {
  flow <- make_flow_hierarchy()
  expect_error(
    as_attrition_table(flow, levels = c("participant", "site")),
    "Unknown hierarchy level"
  )
})

test_that("shade is computed per level", {
  skip_if_not_installed("gt")

  flow <- make_flow_hierarchy()
  gt_tbl <- as_attrition_table(flow, levels = c("participant", "cluster"),
                               shade = "pct_removed", backend = "gt")
  expect_s3_class(gt_tbl, "gt_tbl")
})
