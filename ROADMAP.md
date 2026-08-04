# cohortflow Project Execution Plan & Roadmap

> Last updated: 2026-08-04

## Current Status Summary

| Milestone | Status |
|-----------|--------|
| 1. Project Setup & Infrastructure | 🟡 Mostly complete |
| 2. Core Data Structures & Attrition | ✅ Largely complete |
| 3. Visualization & CONSORT Diagrams | 🟡 In progress |
| 4. `targets` Integration | ❌ Not started |
| 5. Documentation & CRAN Readiness | 🟡 In progress |
| 6. Staged & Hierarchical Pipeline Extensions | ✅ Complete (see §5-6) |

---

## 1. Architecture Roadmap for Data Structures

The core data structures use S3 classes wrapping standard data frames, compatible with `targets` and the `tidyverse`.

### Implemented Classes
- **`cf_criterion`** — A single inclusion/exclusion rule (formula or function).
- **`cf_criteria`** — An ordered collection of `cf_criterion` objects.
- **`cf_hierarchy`** — Defines nested/clustered cohort structures (e.g., participants within sites).
- **`cf_flow`** — The primary pipeline object: wraps the dataset and accumulates attrition logs as criteria are applied.

### Design Principles
- All pipeline functions take a `cf_flow` as their first argument and return a `cf_flow`, enabling `|>` chaining and `targets` compatibility.
- Criteria pipelines are serialisable to/from YAML for reproducibility and sharing.

---

## 2. Directory Structure

```text
cohortflow/
├── .github/          # CI/CD workflows (R CMD check, linting, test coverage) ❌
├── R/
│   ├── apply.R       # apply_criteria(), include(), exclude(), group_*(), select_within()
│   ├── criteria.R    # cf_criteria() S3 class
│   ├── criterion.R   # cf_criterion() S3 class
│   ├── flow.R        # cf_flow S3 class
│   ├── hierarchy.R   # cf_hierarchy() S3 class
│   ├── mock.R        # mock_cohortflow() for examples/tests
│   ├── table.R       # as_attrition_tibble(), as_attrition_table()
│   ├── consort.R     # as_consort_diagram(), plot.cf_flow()
│   └── yaml.R        # export_criteria(), import_criteria()
├── tests/
│   └── testthat/     # Tests for apply, criteria, criterion, hierarchy, table, yaml, mock
├── man/              # roxygen2 generated documentation
├── vignettes/        # ❌ Not yet created
├── dev/              # Exploratory scripts (excluded from build)
├── scripts/          # Utility scripts (e.g., README figure generation)
├── DESCRIPTION
├── NAMESPACE
├── README.md
└── ROADMAP.md
```

---

## 3. Prioritized Backlog of Milestone Tasks

### Milestone 1: Project Setup & Infrastructure
- [x] **1.1** Initialize R package and standard directory structure
- [x] **1.2** Configure CI/CD (GitHub Actions): `R CMD check`, `lintr`, `styler`
- [x] **1.3** Set up `testthat` framework; add `covr` for coverage tracking

### Milestone 2: Core Data Structures & Attrition Logic
- [x] **2.1** Implement S3 classes: `cf_criterion`, `cf_criteria`, `cf_hierarchy`, `cf_flow`
- [x] **2.2** Implement `include()`, `exclude()`, `group_include()`, `group_exclude()`, `select_within()`, `apply_criteria()`
- [x] **2.3** Implement `as_attrition_tibble()`, `as_attrition_table()`, `cohort()`, `excluded()`
- [x] **2.4** Unit tests for criteria application and edge cases
- [x] **2.5** Fix: add `ggplot2` to `Imports` in `DESCRIPTION`
- [x] **2.6** Fix: update placeholder author info in `DESCRIPTION`

### Milestone 3: Visualization & CONSORT Diagrams
- [x] **3.1** ~~Attrition bar chart (`ggplot2`)~~ Removed -- superseded by CONSORT flow diagram below
- [x] **3.2** Implement true CONSORT flow diagram (`grid`-based) in `consort.R`
- [x] **3.3** Add plot customisation: themes, label formatting, colour palettes
  - [x] APA-style attrition tables (no colour, minimal borders, Times New Roman)
  - [x] Singleton category handling (suppress duplicate exclusion counts)
  - [x] `wrap_width` parameter for text wrapping in boxes
  - [x] Conditional colon in exclusion headers
  - [x] Reduced right-side whitespace in diagrams
- [x] **3.4** Support allocation branching in CONSORT diagrams
  - [x] `branch_by` parameter for parallel/crossover trial arms
  - [x] `stage_by` and `stage_label_by` for crossover period/arm labels
  - [x] `count_by` for distinct participant counts in crossover data
- [ ] **3.5** Support export to PNG/SVG/PDF for manuscript submission
- [ ] **3.6** CONSORT 2010 template (blue heading boxes, classic layout)
- [ ] **3.7** Modern parallel trial template
- [ ] **3.8** Modern crossover trial template
- [ ] **3.9** Adaptive main-flow row spacing — row y-positions are currently
  spaced evenly (`row_height <- (top - bottom) / (n_main - 1)`), sized for
  the default box height rather than each row's actual (possibly
  `wrap_width`-wrapped, multi-line) box height. A long wrapped label makes
  that row's box taller than the fixed spacing allows, visually overlapping
  the box above/below it. Reproduces in the plain single-trunk diagram (no
  `branch_by`/`randomise()` needed) — found while validating Milestone 6.6's
  split-cascade geometry, but predates and is independent of it. Needs
  cumulative per-row heights instead of a fixed `seq()`/`row_height`, for
  both the main trunk and per-arm split cascades.

### Milestone 4: `targets` Integration
- [ ] **4.1** Develop `tar_cohort()` target factory
- [ ] **4.2** Demonstrate dynamic branching over multiple cohorts
- [ ] **4.3** Verify `cf_flow` serialises cleanly through `targets` caching

### Milestone 5: Documentation & CRAN Readiness
- [x] **5.1** `roxygen2` docs generated for all exports
- [ ] **5.2** Ensure 100% roxygen2 coverage with reproducible examples
- [ ] **5.3** Write vignettes: (a) basic workflow, (b) hierarchical designs, (c) `targets` integration
- [ ] **5.4** Final `R CMD check` with zero warnings/notes
- [ ] **5.5** CRAN submission

### Milestone 6: Staged & Hierarchical Pipeline Extensions

Proposed after applying `cohortflow` to a two-stage, trial-nested-within-participant
eligibility problem (eye-tracking trials within participants, IDEAL study). Full
design in [§5](#5-detailed-design-staged--hierarchical-pipeline-extensions) and
sequencing in [§6](#6-implementation-plan--sequencing).

- [x] **6.1** `cohort(flow, flag = TRUE)` — soft exclusion / flagging mode *(promoted from Future/Nice-to-Have)*
- [x] **6.2** Composite (multi-column) keys for `apply_criteria(id=)`, `group_include()`/`group_exclude()`/`select_within()` `by=`, and `cf_hierarchy()`
- [x] **6.3** `cf_expected()` + `apply_criteria(expected=, by=)` — expected-unit denominators
- [x] **6.4** `continue_criteria()` — resume a flow with newly joined columns
- [x] **6.5** Wire `cf_hierarchy` into attrition counting (`apply_criteria(hierarchy=)`, `as_attrition_tibble(levels=)`), including cluster `n_consequential` accounting
- [x] **6.6** `randomise()` marker step + generalise `branch_by`/`as_consort_diagram()` to split at the randomisation point
  - [x] `randomise()` step type, `branch_by`/`arms` auto-detection, `post_randomisation` column (see note below)
  - [x] `as_consort_diagram()` split-point geometry (per-arm post-randomisation sub-cascades)

---

## 4. Future / Nice-to-Have Features

These are not in the current backlog but would add significant value:

### Reporting & Output
- [ ] **Narrative text generation** — Auto-generate methods-section paragraph from attrition log (e.g., *"Of 500 patients assessed, 17 were excluded due to age..."*)
- [ ] **Quarto/R Markdown integration** — Helper to embed CONSORT diagram or attrition table directly into a report chunk
- [ ] **Comparison across cohorts** — Side-by-side attrition tables/plots when multiple cohorts are defined

### Criteria Management
- [ ] **Criteria versioning** — Tag criteria sets with a version/date so pipeline changes are auditable
- [ ] **Criteria validation** — Pre-flight check that all formula variables exist in the supplied dataset before applying. High priority: a forgotten join in a staged `continue_criteria()` pipeline (Milestone 6.4) currently fails deep inside `eval_criterion()` with a message that doesn't name the criterion or the missing variable.
- [ ] **Criteria summary printing** — Human-readable summary of what each criterion does (beyond the label)

### Data Handling
- [x] ~~Soft exclusion / flagging mode~~ → promoted to **Milestone 6.1** (`cohort(flow, flag = TRUE)`)
- [ ] **Time-varying criteria** — Support for criteria that vary over observation windows (relevant for longitudinal/retrospective studies)
- [ ] **Missing data reporting** — Automatic NA counts per variable at each step alongside attrition counts
- [ ] **Document `NA` semantics** — `include()` fails `NA`; `exclude()` does not exclude on `NA`. Both defensible, and the asymmetry is deliberate, but it's currently only discoverable by reading `apply.R`. Needs roxygen coverage on `include()`/`exclude()` and a vignette callout, since getting it wrong silently changes a denominator. Consider an explicit `na = c("fail", "pass")` argument so callers can state intent rather than rely on the default.

### Interoperability
- [ ] **`dplyr` verb compatibility** — Ensure `cf_flow` objects pass through standard `dplyr` verbs without losing attrition metadata
- [ ] **REDCap / ODM import** — Helpers to import criteria definitions from common clinical data management formats
- [ ] **`gtsummary` integration** — Feed final cohort directly into `gtsummary::tbl_summary()` for Table 1 generation

---

## 5. Detailed Design: Staged & Hierarchical Pipeline Extensions

Source: applying `cohortflow` to trial-level eye-tracking eligibility (~8,700
antisaccade trials nested within ~81 participants), with eligibility assessed
in two stages separated by an expensive processing step. Each item below is
independently implementable; sequencing is in [§6](#6-implementation-plan--sequencing).

### 6.1 `cohort(flow, flag = TRUE)` — soft exclusion / flagging mode

Some consumers (e.g. an epoch-extraction step that needs every trial present
so it can plot the full recording) want eligibility as a **flag column**
joined onto the full row set, not a filtered data frame. Reconstructing this
today from `cohort()`/`excluded()` by hand discards step attribution.

```r
cohort(flow, flag = FALSE)
```

With `flag = TRUE`, returns all original rows (i.e. `flow$data`, minus
`.cf_row_id`) plus:

| Column | Type | Meaning |
|---|---|---|
| `cf_included` | logical | Passed every step |
| `cf_excluded_step` | integer | First failing step, `NA` if included |
| `cf_excluded_label` | character | Label of that step |
| `cf_excluded_category` | character | Category of that step, `NA` if none |

Implementation: for each row, find the minimum `s$step` among steps whose
`excluded_ids` contain that row's `.cf_row_id` (a row can only appear in one
step's `excluded_ids`, since `apply_criteria()` removes rows from `current`
once excluded — so this is a single left-join of `flow$data` onto a
step-lookup built from `flow$steps`, not a search). No changes to
`apply_criteria()` are needed; this only touches `cohort()` in `R/flow.R`.

### 6.2 Composite (multi-column) keys

`apply_criteria(id = )`, `group_include()`/`group_exclude()`/`select_within()`
`by = `, and `cf_hierarchy()` all currently take a single column name.
Nested data is naturally keyed on a tuple (e.g. `participant_id`, `trial_id`).
Accept a character vector everywhere a single column name is currently
required, and paste the columns internally (with a separator unlikely to
collide, e.g. `"\r"`) to form the actual grouping/identifier key. Low effort;
removes a recurring papercut and is a prerequisite for 6.5's stepped-wedge
`cluster_period` level.

Touches: `.ensure_row_id()` in `R/apply.R`, the `by` handling in
`R/criteria.R` (`group_include()`, `group_exclude()`, `select_within()`) and
`R/apply.R` (`eval_group_criterion()`, `eval_select_criterion()`), and
`cf_hierarchy()` in `R/hierarchy.R` (accept `c(...)` values that are
themselves character vectors).

### 6.3 Expected-unit denominators

`apply_criteria()` starts from observed rows, so a unit that should exist but
has no record (e.g. a scheduled trial the experiment log never captured)
never appears in the attrition table — the most important exclusion
category, data that was never captured, is invisible.

```r
cf_expected(..., .stringsAsFactors = FALSE)   # thin wrapper over expand.grid()
apply_criteria(data, criteria, id = NULL, expected = NULL, by = NULL)
```

When `expected` is supplied, `data` is right-joined onto it before any
criteria run, so absent units appear as all-`NA` rows; a leading
`include(~ !is.na(some_key_column), label = "Record present")` then cleanly
counts them. `expected` must contain the `by` columns and nothing that
collides with `data`; the flow's starting `n` becomes `nrow(expected)`.
Emit a message stating how many expected units had no matching record (a
large number usually indicates a join-key problem, not genuine missingness).

Touches: new `R/expected.R` (or add to `R/apply.R`) for `cf_expected()`; the
top of `apply_criteria()` in `R/apply.R` to perform the join, reusing the
duplicate-key guard built for 6.4.

### 6.4 `continue_criteria()` — resume a flow with new columns

`ROADMAP.md`'s own design principle states pipeline functions take a
`cf_flow` and return a `cf_flow`; `apply_criteria()` breaks this by taking a
data frame. This makes any study with eligibility assessed in stages (screen
→ expensive processing → second round of exclusions on processing-derived
metrics) produce two disconnected flow objects: `as_attrition_tibble()` on
the second reports a denominator that silently excludes stage-1 losses,
`as_consort_diagram()` renders only half the study, and stage-1 excluded rows
are unreachable from the final object.

```r
continue_criteria(flow, criteria, join = NULL, by = NULL)
```

Returns a single `cf_flow` whose `steps` are the concatenation of the
original and new steps, renumbered contiguously, with `flow$criteria`
becoming `c(flow$criteria, criteria)` (so `export_criteria()` round-trips the
full pipeline). Semantics:

- New criteria run only against rows surviving all prior steps; `n_in` for
  the first new step equals `nrow(cohort(flow))`.
- `flow$data` gains the joined columns; rows excluded at earlier steps get
  `NA` there (correct — those columns were never measured for them).
- `.cf_row_id` must survive the join unchanged; a `join` with more than one
  row per key must abort naming the offending keys, not fan out rows. This
  is the same duplicate-key guard needed by 6.3, so implement it once as an
  internal helper (e.g. `.assert_no_join_fanout()`) shared by both.
- `join` without `by`, `by` columns absent from either side, or a `join`
  column colliding with an existing `flow$data` column all abort with a
  message naming the offending column(s).
- Empty surviving cohort → flow with zero-row steps, no error. Zero-length
  `criteria` → return `flow` unchanged.

Touches: new `R/continue.R`; reuses `eval_criterion()`/`eval_group_criterion()`
etc. from `R/apply.R` by factoring the step-execution loop in
`apply_criteria()` into an internal `.run_steps(current, steps, step_offset)`
so both entry points share one implementation.

### 6.5 Wire `cf_hierarchy` into attrition counting

`cf_hierarchy` is constructed, printed, formatted and validated, and used by
nothing (`grep -r hierarchy R/` returns only `hierarchy.R`). For nested data,
row counts are the wrong unit for at least half of reporting — e.g. *"of 81
participants contributing 9,720 expected trials, 3 participants (288 trials)
had no usable recording"* needs both numbers; the participant count isn't
derivable from the trial count.

```r
apply_criteria(data, criteria, id = NULL, hierarchy = NULL)
as_attrition_tibble(flow, levels = NULL)
```

`hierarchy` is a `cf_hierarchy`; when present, `validate_hierarchy()` (already
implemented) is called, and each step record additionally stores, per level,
the number of distinct units at risk/passing/failing.
`as_attrition_tibble(levels = "participant")` returns counts at that level;
`levels = NULL` returns all levels in long format with a `level` column;
`levels = character(0)` preserves current row-count-only behaviour.

Counting rule (**must** be stated explicitly in docs — the naive
implementation, counting distinct ids among excluded rows, gives a different
and wrong answer):

- A coarse unit is excluded at a step only when **all** its rows are excluded
  at or before that step. Partial loss is not exclusion, and coarse counts
  are therefore not additive across steps — attribute a unit to the step
  where its *last* row disappears, not every step that removed some of its
  rows.
- This is **bottom-up** attribution and is correct for `include()`/
  `exclude()`/`select_within()` steps. It is wrong for `group_include()`/
  `group_exclude()`, which are **top-down**: a cluster is removed as a
  cluster and its members disappear consequentially. Per the addendum below,
  give the step record an `n_consequential` count (per finer level) alongside
  the primary exclusion count, so *"2 clusters excluded (n<5), removing 34
  participants"* is representable and doesn't misreport those 34 as
  individually-excluded participants (CONSORT's cluster extension — Campbell,
  Elbourne & Altman, BMJ 2004;328:702-8 — expects cluster-flow and
  participant-flow to be distinguishable).

Touches: `R/apply.R` (step-record construction gains per-level counts,
branching on step `type` for bottom-up vs. top-down attribution), `R/table.R`
(`as_attrition_tibble(levels=)`, new `n_consequential` column), `R/hierarchy.R`
(no signature change, just gets called). This is the largest item and
depends on 6.2 for the stepped-wedge `cluster_period` composite level.

### 6.6 `randomise()` marker step and `branch_by` generalisation

See the dedicated design note below.

#### Position relative to randomisation

A cluster/parallel CONSORT diagram places allocation at a specific point,
and exclusions applied after that point carry an identification-bias
implication that pre-randomisation exclusions don't. `cf_flow` currently has
no concept of where randomisation sits in the cascade — `branch_by` is a
**rendering-time-only** parameter to `as_consort_diagram()`/
`as_attrition_table()` that always splits the diagram at the very end (after
`cohort(flow)` is computed), regardless of how many steps actually ran after
allocation.

```r
cf_criteria() |>
  include(~ eligible, label = "Eligible clusters") |>
  randomise(by = "cluster_id", arms = "arm") |>
  exclude(~ withdrew, label = "Withdrew after allocation")
```

`randomise()` is a new `cf_criteria` step type (`R/criteria.R`) that excludes
nothing (`n_fail` always `0`) and instead records its position, the
randomisation unit (`by`), and the arm column (`arms`) in the step record —
mirroring how `group_include()`/`group_exclude()` already carry `by`.
`apply_criteria()` (`R/apply.R`) needs a new branch in the `switch(s$type, ...)`
that passes every row through unchanged but still writes a step record (so it
prints and exports like any other step, and its position is addressable by
index for `randomise = TRUE`.

**Why current `branch_by` is *not* general enough, and what changes:**

1. **Detection.** `as_consort_diagram()`/`as_attrition_tibble()` currently
   require the caller to pass `branch_by` explicitly and read the branching
   column straight off `cohort(flow)`. They should first check
   `flow$criteria$steps` for a `type == "randomise"` entry; if found,
   `branch_by`/`arms` default to that step's recorded `by`/`arms` (explicit
   arguments still override). This makes `randomise()` and `branch_by`
   consistent instead of independent, duplicated ways to say the same thing.
2. **Split point.** Branching currently always happens after the *last* main
   box (i.e. after every step, via `cohort(flow)`). When a `randomise` step
   exists, the main flow must instead be drawn linearly up to and including
   that step's box, branch there, and render every subsequent step
   (`exclude(~ withdrew, ...)` etc.) as **per-arm sub-cascades** — reusing the
   existing branch/stage rendering primitives (`branch_df`/`stage_df` in
   `R/consort.R`) rather than the single shared trunk used today. Concretely:
   `.consort_group_rows()` needs to partition `groups` at the randomise
   step's index, and the branch-drawing block (currently only ever attached
   below `main_df[nrow(main_df), ]`) needs to attach below
   `main_df[randomise_idx, ]` instead, with one independent column of main
   boxes per arm for the remaining steps.
3. **Counting.** `as_attrition_tibble()` gains a `post_randomisation` logical
   column (`TRUE` for step rows at or after the randomise step), so reviewers
   can filter/highlight post-allocation exclusions — the reporting item
   actually checked in CONSORT-adherence review. This is additive to the
   existing row schema, not a breaking change.
4. **Backward compatibility.** With no `randomise` step present, `branch_by`
   keeps its current documented behaviour exactly (split at the end, driven
   by an explicit column) — nothing here changes today's parallel/crossover
   rendering; it only removes the restriction that branching can happen
   *only* at the very end of the cascade.
5. **YAML round-trip.** `randomise()` needs an `export_criteria()`/
   `import_criteria()` case in `R/yaml.R` alongside the existing step types.

**Implementation status:** All five items are **complete and tested** —
`randomise()` (`R/criteria.R`), the `randomise` type in `cf_criterion()`
(`R/criterion.R`, `predicate` must be `NULL`, `arms` required), the
`randomise` switch case in `apply_criteria()` (`R/apply.R`), YAML round-trip
(`R/yaml.R`), `branch_by`/`arms` auto-detection in both
`as_attrition_tibble()` and `as_consort_diagram()`, the additive
`post_randomisation` column in `as_attrition_tibble()`, and the item-2
split-point geometry below all have full test coverage (test-criterion.R,
test-criteria.R, test-apply.R, test-yaml.R, test-table.R, test-consort.R). A
`print.cf_flow()` bug (a `switch()` with no default case, silently dropping
the printed line for any unrecognised step type) was found and fixed while
implementing this.

Item 2 (the split-point geometry rework) is **implemented**:
`.consort_group_rows()`'s groups are partitioned at the randomise step's
index (`split_idx`), everything before it stays a single shared trunk, and
everything at or after it is re-run per arm (`apply_criteria()` on each
arm's subset against the remaining criteria) and drawn as its own column via
`.consort_build_cascade()` — the same helper the shared trunk uses,
refactored out for this purpose — with an explicit "Allocated to `<arm>`"
label box and a right-angle crossbar connector off the randomisation box.
`as_attrition_tibble(levels=)`/`count_by` are not supported together with a
split (aborts naming the incompatibility); everything else (`stage_by`,
`wrap_width`, exclusion boxes, singleton categories) works per arm
identically to the shared-trunk path.

While validating this by rendering multi-step post-randomisation cascades,
found and fixed a real geometry bug: `branch_spacing` (the horizontal gap
between arm columns) only reserved `max_w / 2 + gap_x` per column, but an
arm's own exclusion box sits a *full* `max_w`-wide box to the right of its
main column, so it could overlap the next arm's boxes whenever both arms
had exclusion boxes at similar row heights (visually: an exclusion box
crossing over into the neighbouring arm's cascade). Fixed by reserving
`2 * max_w + 2 * gap_x` between columns; regression test added
(`as_consort_diagram() does not overlap boxes across arms after a
randomise() split`, test-consort.R) using a new `make_flow_randomise_multistep()`
fixture — the existing single-post-randomisation-step fixture had enough
incidental vertical room to not trigger the bug, so it needed a fixture with
two post-randomisation exclusion steps to actually catch it.

**Known limitation (pre-existing, not introduced by this work, out of
scope here):** main-flow row y-positions are spaced evenly
(`row_height <- (top - bottom) / (n_main - 1)`), sized for the *default*
box height, not the actual per-row box height. A long `wrap_width`-wrapped
label (many lines) makes that row's box taller than `row_height`, and it
then visually overlaps the box above/below it. This is not new — it
reproduces identically with `branch_by`/`randomise()` absent entirely, i.e.
in the plain single-trunk diagram, so it predates and is independent of the
6.6 split-cascade work. Fixing it needs adaptive row spacing (cumulative
per-row heights instead of fixed `seq()`/`row_height`) across the whole
main-flow layout, main and per-arm alike — worth its own follow-up item
rather than folding into 6.6.

#### Stepped wedge

Stepped-wedge designs have three levels (participant within cluster-period
within cluster), and the coarse level is an interaction of cluster and
period, not a single column — this is the strongest concrete case for the
composite-key item (6.2):
`cf_hierarchy(participant = "pid", cluster_period = c("cluster_id", "period"), cluster = "cluster_id")`.
`as_attrition_table()` already supports `group_x`/`group_y` for this design
on the table-formatting side; 6.5 is what gives the counting side the same
support.

---

## 6. Implementation Plan & Sequencing

Ordered by dependency and effort, not by the numbering above:

| Phase | Item(s) | Why this order |
|---|---|---|
| **A** | 6.1 (flag mode), 6.2 (composite keys) | Small, self-contained, unblock real use immediately. 6.2 has no dependents yet but is a prerequisite for 6.5's stepped-wedge level. |
| **B** | 6.3 (expected-unit denominators) | Moderate; introduces the join-fanout guard reused by 6.4. |
| **C** | 6.4 (`continue_criteria()`) | Requires factoring `apply_criteria()`'s step-execution loop into a shared internal helper; reuses the guard from B. |
| **D** | 6.5 (hierarchy counting incl. `n_consequential`), 6.6 (`randomise()` + `branch_by` generalisation) | Largest; 6.5 depends on 6.2; 6.6 depends on 6.5 for `post_randomisation`/consequential-exclusion reporting to be meaningful, though the `randomise()` step type itself and the `as_consort_diagram()` split-point logic can be built independently and merged once 6.5 lands. |

Each phase should land with its own tests appended to the corresponding file
under `tests/testthat/` (`test-apply.R`, `test-hierarchy.R`, `test-consort.R`,
`test-table.R`, `test-yaml.R`) — see the worked test cases in the source
proposal doc for concrete `expect_*()` assertions per item, which should be
adapted rather than re-derived. Roxygen examples and `NEWS.md` entries follow
the existing per-function convention once a phase's functions stabilise.