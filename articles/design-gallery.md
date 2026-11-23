# Study design gallery

``` r

library(cohortflow)
```

One complete, copyable example per study design, from data to diagram
and table. Each uses one of the package’s mock-data generators, so it
runs as is; swap in your own data and criteria.

| Design | Generator | Unit of a row | What’s different |
|----|----|----|----|
| [Parallel-group RCT](#parallel-group-randomised-trial) | [`mock_parallel_rct()`](https://mattmoo.github.io/cohortflow/reference/mock_parallel_rct.md) | participant | per-arm cascade after [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md) |
| [Crossover trial](#crossover-trial) | [`mock_crossover()`](https://mattmoo.github.io/cohortflow/reference/mock_crossover.md) | participant-period | sequences and periods; `count_by` a hierarchy level |
| [Cluster RCT](#cluster-randomised-trial) | [`mock_cluster_rct()`](https://mattmoo.github.io/cohortflow/reference/mock_cluster_rct.md) | participant | cluster rules; cluster and participant counts |
| [Stepped-wedge trial](#stepped-wedge-trial) | [`mock_stepped_wedge()`](https://mattmoo.github.io/cohortflow/reference/mock_stepped_wedge.md) | participant-period | cluster-periods; site × period grid |

## Parallel-group randomised trial

Participants are individually randomised. Losses after allocation are
reported per arm.

``` r

dat <- mock_parallel_rct(n_participants = 400, seed = 1)

crit <- cf_criteria() |>
  include(~ !is.na(age), label = "Age recorded", reason = "Age missing", category = "Age") |>
  include(~ age >= 18, label = "Aged 18 or over", reason = "Under 18", category = "Age") |>
  include(~ eligible_screen, label = "Met inclusion criteria", reason = "Did not meet inclusion criteria") |>
  include(~ !is.na(consent_date), label = "Consented", reason = "Did not consent") |>
  randomise(by = "participant_id", arms = "arm") |>
  exclude(~ withdrew, label = "Withdrew") |>
  include(~ baseline_complete, label = "Baseline complete", reason = "Baseline incomplete")

flow <- apply_criteria(dat, crit, id = "participant_id")
```

``` r

as_consort_diagram(flow)
```

![Parallel-group CONSORT diagram splitting into two arms after
randomisation.](design-gallery_files/figure-html/unnamed-chunk-3-1.png)

``` r

as_attrition_table(flow, backend = "gt")
```

[TABLE]

## Crossover trial

Each participant receives both treatments, in a randomised order
(sequence). The data has one row per participant per period, so rows are
identified by `event_id`. The hierarchy names both units, and
`count_by = "participant"` makes every box count participants.

``` r

co <- mock_crossover(n_participants = 150, seed = 1)

crit_co <- cf_criteria() |>
  include(~ eligible_screen, label = "Met inclusion criteria",
          reason = "Did not meet inclusion criteria") |>
  include(~ !is.na(consent_date), label = "Consented", reason = "Did not consent") |>
  exclude(~ withdrew, label = "Withdrew")

flow_co <- apply_criteria(
  co, crit_co, id = "event_id",
  hierarchy = cf_hierarchy(period = "event_id", participant = "participant_id")
)
```

``` r

as_consort_diagram(
  flow_co,
  branch_by = "sequence",
  stage_by = "period",
  stage_label_by = "arm",
  count_by = "participant",
  final_label = "Randomised"
)
```

![Crossover CONSORT diagram with two sequences, each showing its two
treatment
periods.](design-gallery_files/figure-html/unnamed-chunk-6-1.png)

The same hierarchy gives a table with participants and
participant-periods side by side:

``` r

as_attrition_table(
  flow_co,
  levels = c("participant", "period"),
  level_labels = c("Participants", "Participant-periods"),
  backend = "gt"
)
```

[TABLE]

## Cluster-randomised trial

Clusters (practices, schools, wards) are randomised, and participants
are recruited within them. Cluster-level rules use
[`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md)
or
[`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md),
and the CONSORT cluster extension asks for losses at both levels.

``` r

cl <- mock_cluster_rct(n_clusters = 16, n_participants = 600, seed = 7)

crit_cl <- cf_criteria() |>
  include(~ eligible_screen, label = "Met inclusion criteria", reason = "Did not meet inclusion criteria") |>
  include(~ !is.na(consent_date), label = "Consented", reason = "Did not consent") |>
  group_include(by = "cluster_id", ~ n() >= 20,
                label = "Cluster recruited 20 or more") |>
  randomise(by = "cluster_id", arms = "arm") |>
  exclude(~ withdrew, label = "Withdrew")

flow_cl <- apply_criteria(
  cl, crit_cl, id = "participant_id",
  hierarchy = cf_hierarchy(participant = "participant_id", cluster = "cluster_id")
)
```

``` r

as_consort_diagram(flow_cl, wrap_width = 24)
```

![Cluster trial CONSORT diagram at participant level, splitting into two
arms after cluster
randomisation.](design-gallery_files/figure-html/unnamed-chunk-9-1.png)

``` r

as_attrition_table(
  flow_cl,
  levels = c("participant", "cluster"),
  level_labels = c("Participants", "Clusters"),
  backend = "gt"
)
```

[TABLE]

The “Consequential” column counts participants lost only because their
cluster was removed. See [Hierarchical and cluster
designs](https://mattmoo.github.io/cohortflow/articles/hierarchical-designs.html#how-units-are-counted).

## Stepped-wedge trial

Every cluster starts in the control condition and crosses to the
intervention at a randomised time, so each cluster contributes to both
conditions over the periods of the trial. Results are usually reported
by period, and losses by cluster-period.

``` r

sw <- mock_stepped_wedge(n_clusters = 8, n_participants = 400,
                         n_periods = 4, n_sites = 2, seed = 3)

crit_sw <- cf_criteria() |>
  include(~ !is.na(consent_date), label = "Consented", reason = "Did not consent") |>
  exclude(~ withdrew, label = "Withdrew") |>
  group_include(by = c("cluster_id", "period"), ~ n() >= 8,
                label = "Cluster-period has 8 or more")

flow_sw <- apply_criteria(
  sw, crit_sw, id = "event_id",
  hierarchy = cf_hierarchy(
    observation = "event_id",
    cluster_period = c("cluster_id", "period"),
    cluster = "cluster_id"
  )
)
```

``` r

as_consort_diagram(flow_sw, branch_by = "period", final_label = "Analysed")
```

![Stepped-wedge CONSORT diagram whose final box splits into the four
periods.](design-gallery_files/figure-html/unnamed-chunk-12-1.png)

Attrition by site and period, with each block counted separately:

``` r

as_attrition_table(
  flow_sw,
  backend = "gt",
  group_x = "site_id", group_x_label = "Site",
  group_y = "period", group_y_label = "Period"
)
```

[TABLE]

And at each level of the design:

``` r

as_attrition_table(
  flow_sw,
  levels = c("observation", "cluster_period", "cluster"),
  level_labels = c("Observations", "Cluster-periods", "Clusters"),
  backend = "gt"
)
```

[TABLE]
