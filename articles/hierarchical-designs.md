# Hierarchical and cluster designs

``` r

library(cohortflow)
```

In many studies the rows of the data are not the only units that matter.
Participants sit inside clusters (practices, schools, wards), clusters
inside sites, and repeated measurements inside participants. Reporting
needs counts at more than one level: the CONSORT extension for cluster
trials (Campbell, Elbourne and Altman, *BMJ* 2004;328:702–8) asks for
losses at each stage to be given for clusters *and* for participants.

cohortflow handles this by recording, at every step, how many distinct
units were present at each level you declare.

## Declaring the hierarchy

[`cf_hierarchy()`](https://mattmoo.github.io/cohortflow/reference/cf_hierarchy.md)
names the levels, from finest to coarsest, and maps each to the
column(s) that identify it:

``` r

cl <- mock_cluster_rct(n_clusters = 16, n_participants = 600, seed = 7)

h <- cf_hierarchy(
  participant = "participant_id",
  cluster = "cluster_id",
  site = "site_id"
)
h
#> Cohort hierarchy (finest → coarsest):
#>   ├─ participant  →  column: participant_id
#>   ├─ cluster  →  column: cluster_id
#>   └─ site  →  column: site_id
```

Pass it to
[`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md)
with `hierarchy =`. Nothing changes about which rows are kept; the flow
just records the extra counts.

``` r

crit <- cf_criteria() |>
  include(~ eligible_screen, label = "Passed screening", reason = "Failed screening") |>
  include(~ !is.na(consent_date), label = "Consented", reason = "Did not consent") |>
  group_include(by = "cluster_id", ~ n() >= 20,
                label = "Cluster recruited 20 or more") |>
  randomise(by = "cluster_id", arms = "arm") |>
  exclude(~ withdrew, label = "Withdrew consent")

flow <- apply_criteria(cl, crit, id = "participant_id", hierarchy = h)
```

## Counts at every level

`levels` in
[`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
returns one block per level (`NULL` means all of them):

``` r

as_attrition_tibble(flow, levels = c("participant", "cluster"))
#> # A tibble: 14 × 8
#>    row_type label indent_level     n n_removed n_consequential pct_removed level
#>    <chr>    <chr>        <int> <int>     <int>           <int>       <dbl> <chr>
#>  1 header   Asse…            0   600        NA              NA        NA   part…
#>  2 step     Pass…            1   600        68               0        11.3 part…
#>  3 step     Cons…            1   532        83               0        15.6 part…
#>  4 step     Clus…            1   449         0              37         0   part…
#>  5 step     Rand…            1   412         0               0         0   part…
#>  6 step     With…            1   412        18               0         4.4 part…
#>  7 final    Fina…            0   394        NA              NA        65.7 part…
#>  8 header   Asse…            0    15        NA              NA        NA   clus…
#>  9 step     Pass…            1    15         0               0         0   clus…
#> 10 step     Cons…            1    15         0               0         0   clus…
#> 11 step     Clus…            1    15         5               0        33.3 clus…
#> 12 step     Rand…            1    10         0               0         0   clus…
#> 13 step     With…            1    10         0               0         0   clus…
#> 14 final    Fina…            0    10        NA              NA        66.7 clus…
```

[`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md)
puts the levels side by side, which is the layout the CONSORT cluster
extension describes. Each criterion reads across both levels at once:

``` r

as_attrition_table(
  flow,
  levels = c("participant", "cluster"),
  level_labels = c(participant = "Participants", cluster = "Clusters"),
  backend = "gt"
)
```

[TABLE]

## How units are counted

Two rules decide when a coarser unit counts as lost. They matter because
a naive count of “distinct clusters among the excluded rows” gives the
wrong answer.

**Row-level steps count from the bottom up.** A cluster is lost at a
step only when its *last* remaining participant is removed there. Losing
some of a cluster’s participants is not losing the cluster.

A small example makes this concrete. Cluster A has three participants
and cluster B has two:

``` r

toy <- data.frame(
  pid = c("a1", "a2", "a3", "b1", "b2"),
  cluster = c("A", "A", "A", "B", "B"),
  consented = c(TRUE, FALSE, TRUE, FALSE, FALSE)
)
toy_flow <- apply_criteria(
  toy,
  cf_criteria() |> include(~ consented, label = "Consented", reason = "Did not consent"),
  id = "pid",
  hierarchy = cf_hierarchy(participant = "pid", cluster = "cluster")
)
as_attrition_tibble(toy_flow, levels = NULL)[, c("level", "label", "n", "n_removed")]
#> # A tibble: 6 × 4
#>   level       label                        n n_removed
#>   <chr>       <chr>                    <int>     <int>
#> 1 participant Assessed for eligibility     5        NA
#> 2 participant Consented                    5         3
#> 3 participant Final cohort                 2        NA
#> 4 cluster     Assessed for eligibility     2        NA
#> 5 cluster     Consented                    2         1
#> 6 cluster     Final cohort                 1        NA
```

Three participants were removed (one from A, two from B), but only one
cluster, B, was lost, because A still has participants left.

**Group-level steps count from the top down.**
[`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md)
and
[`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md)
remove whole clusters, and their participants go with them. Those
participants were not individually excluded, so they are reported in a
separate `n_consequential` column rather than as `n_removed`. In the
trial above, the cluster-size rule removed 5 clusters, and with them 37
participants who were otherwise eligible:

``` r

tbl <- as_attrition_tibble(flow, levels = c("participant", "cluster"))
tbl[tbl$label == "Cluster recruited 20 or more",
    c("level", "n", "n_removed", "n_consequential")]
#> # A tibble: 2 × 4
#>   level           n n_removed n_consequential
#>   <chr>       <int>     <int>           <int>
#> 1 participant   449         0              37
#> 2 cluster        15         5               0
```

This is the distinction the cluster extension draws between losing a
cluster and losing participants.

## Composite levels: stepped-wedge trials

A level can be identified by more than one column. In a stepped-wedge
trial, each cluster contributes a cluster-period for every period of the
roll-out, so the cluster-period is identified by `cluster_id` *and*
`period`:

``` r

sw <- mock_stepped_wedge(n_clusters = 8, n_participants = 400,
                         n_periods = 4, n_sites = 2, seed = 3)

h_sw <- cf_hierarchy(
  observation = "event_id",
  cluster_period = c("cluster_id", "period"),
  cluster = "cluster_id"
)

crit_sw <- cf_criteria() |>
  include(~ !is.na(consent_date), label = "Consented", reason = "Did not consent") |>
  exclude(~ withdrew, label = "Withdrew") |>
  group_include(by = c("cluster_id", "period"), ~ n() >= 8,
                label = "Cluster-period has 8 or more")

flow_sw <- apply_criteria(sw, crit_sw, id = "event_id", hierarchy = h_sw)
```

``` r

as_attrition_table(
  flow_sw,
  levels = c("observation", "cluster_period", "cluster"),
  level_labels = c("Observations", "Cluster-periods", "Clusters"),
  backend = "gt"
)
```

[TABLE]

The cluster-period rule removed 12 cluster-periods but only 3 whole
clusters: the others still had at least one period with enough
participants.

Stepped-wedge results are also often shown by site and period. `group_x`
and `group_y` repeat the attrition table for each combination; see
[Attrition
tables](https://mattmoo.github.io/cohortflow/articles/attrition-tables.html#grids-by-site-and-period).

## Characteristics at the cluster level

[`as_characteristics_table()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_table.md)
and
[`stack_cohorts()`](https://mattmoo.github.io/cohortflow/reference/stack_cohorts.md)
take a `level` argument to describe units at that level rather than
rows. Every variable must be constant within a unit, as cluster-level
variables such as site and arm are:

``` r

as_characteristics_tibble(
  flow,
  vars = c("site_id", "arm"),
  steps = list(0, "Cluster recruited 20 or more"),
  level = "cluster",
  wide = TRUE
)
#> # A tibble: 5 × 4
#>   variable level        Assessed for eligibility (n = 1…¹ Cluster recruited 20…²
#>   <chr>    <chr>        <chr>                             <chr>                 
#> 1 site_id  S1           1 (6.7%)                          1 (10.0%)             
#> 2 site_id  S2           7 (46.7%)                         4 (40.0%)             
#> 3 site_id  S3           7 (46.7%)                         5 (50.0%)             
#> 4 arm      Control      8 (53.3%)                         5 (50.0%)             
#> 5 arm      Intervention 7 (46.7%)                         5 (50.0%)             
#> # ℹ abbreviated names: ¹​`Assessed for eligibility (n = 15)`,
#> #   ²​`Cluster recruited 20 or more (n = 10)`
```

## Limits

- `levels` cannot be combined with `group_x`, `group_y`, `branch_by` or
  `count_by` in the same table.
- [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md)
  draws one level at a time: rows by default, or a hierarchy level with
  `count_by` (`count_by = "cluster"` draws a cluster-flow diagram). For
  a cluster trial, draw the participant-level diagram and report cluster
  counts in the attrition table alongside it.
- [`cf_hierarchy()`](https://mattmoo.github.io/cohortflow/reference/cf_hierarchy.md)
  does not require strict nesting, but its counts are easiest to read
  when each level nests in the next.

## See also

- [Writing
  criteria](https://mattmoo.github.io/cohortflow/articles/writing-criteria.html#grouped-data)
  for the grouped step types.
- [Staged pipelines and missing
  units](https://mattmoo.github.io/cohortflow/articles/staged-pipelines.html)
  for denominators that include units with no data at all.
- [Study design
  gallery](https://mattmoo.github.io/cohortflow/articles/design-gallery.html)
  for complete cluster and stepped-wedge examples.
