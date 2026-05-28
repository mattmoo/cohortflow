# cohortflow Project Execution Plan & Roadmap

> Last updated: 2026-05-28

## Current Status Summary

| Milestone | Status |
|-----------|--------|
| 1. Project Setup & Infrastructure | 🟡 Mostly complete |
| 2. Core Data Structures & Attrition | ✅ Largely complete |
| 3. Visualization & CONSORT Diagrams | 🟡 In progress |
| 4. `targets` Integration | ❌ Not started |
| 5. Documentation & CRAN Readiness | 🟡 In progress |

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
│   ├── flow.R        # cf_flow S3 class, attrition bar chart
│   ├── hierarchy.R   # cf_hierarchy() S3 class
│   ├── mock.R        # mock_cohortflow() for examples/tests
│   ├── table.R       # as_attrition_tibble(), as_attrition_table()
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
- [x] **3.1** Attrition bar chart (`ggplot2`) implemented in `flow.R`
- [ ] **3.2** Implement true CONSORT flow diagram (consider `DiagrammeR`, `ggraph`, or `grid`-based)
- [ ] **3.3** Add plot customisation: themes, label formatting, colour palettes
- [ ] **3.4** Support export to PNG/SVG/PDF for manuscript submission

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

---

## 4. Future / Nice-to-Have Features

These are not in the current backlog but would add significant value:

### Reporting & Output
- [ ] **Narrative text generation** — Auto-generate methods-section paragraph from attrition log (e.g., *"Of 500 patients assessed, 17 were excluded due to age..."*)
- [ ] **Quarto/R Markdown integration** — Helper to embed CONSORT diagram or attrition table directly into a report chunk
- [ ] **Comparison across cohorts** — Side-by-side attrition tables/plots when multiple cohorts are defined

### Criteria Management
- [ ] **Criteria versioning** — Tag criteria sets with a version/date so pipeline changes are auditable
- [ ] **Criteria validation** — Pre-flight check that all formula variables exist in the supplied dataset before applying
- [ ] **Criteria summary printing** — Human-readable summary of what each criterion does (beyond the label)

### Data Handling
- [ ] **Soft exclusion / flagging mode** — Mark rows as excluded without dropping them, useful for sensitivity analyses
- [ ] **Time-varying criteria** — Support for criteria that vary over observation windows (relevant for longitudinal/retrospective studies)
- [ ] **Missing data reporting** — Automatic NA counts per variable at each step alongside attrition counts

### Interoperability
- [ ] **`dplyr` verb compatibility** — Ensure `cf_flow` objects pass through standard `dplyr` verbs without losing attrition metadata
- [ ] **REDCap / ODM import** — Helpers to import criteria definitions from common clinical data management formats
- [ ] **`gtsummary` integration** — Feed final cohort directly into `gtsummary::tbl_summary()` for Table 1 generation