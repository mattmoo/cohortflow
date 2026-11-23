# Package index

## Defining criteria

Build a criteria pipeline step by step. Row-wise steps
([`include()`](https://mattmoo.github.io/cohortflow/reference/include.md),
[`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md))
keep or drop individual rows; grouped steps act on whole groups such as
clusters or participants;
[`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
marks the allocation point.

- [`cf_criteria()`](https://mattmoo.github.io/cohortflow/reference/cf_criteria.md)
  : Create an eligibility criteria pipeline
- [`include()`](https://mattmoo.github.io/cohortflow/reference/include.md)
  : Add an inclusion criterion to a criteria pipeline
- [`exclude()`](https://mattmoo.github.io/cohortflow/reference/exclude.md)
  : Add an exclusion criterion to a criteria pipeline
- [`group_include()`](https://mattmoo.github.io/cohortflow/reference/group_include.md)
  : Add a group-level inclusion criterion
- [`group_exclude()`](https://mattmoo.github.io/cohortflow/reference/group_exclude.md)
  : Add a group-level exclusion criterion
- [`select_within()`](https://mattmoo.github.io/cohortflow/reference/select_within.md)
  : Select rows within groups
- [`randomise()`](https://mattmoo.github.io/cohortflow/reference/randomise.md)
  : Mark the randomisation/allocation point in a criteria pipeline
- [`cf_criterion()`](https://mattmoo.github.io/cohortflow/reference/cf_criterion.md)
  : Create a single cohort criterion
- [`check_criteria()`](https://mattmoo.github.io/cohortflow/reference/check_criteria.md)
  : Check that criteria only refer to columns present in the data

## Applying criteria

Run a pipeline against data to get a `cf_flow`.

- [`apply_criteria()`](https://mattmoo.github.io/cohortflow/reference/apply_criteria.md)
  : Apply a criteria pipeline to a data frame
- [`continue_criteria()`](https://mattmoo.github.io/cohortflow/reference/continue_criteria.md)
  : Continue a criteria pipeline on top of an existing flow
- [`cf_hierarchy()`](https://mattmoo.github.io/cohortflow/reference/cf_hierarchy.md)
  : Declare the nesting hierarchy for a cohort
- [`cf_expected()`](https://mattmoo.github.io/cohortflow/reference/cf_expected.md)
  : Declare the expected set of observational units

## Inspecting a flow

Get the cohort, the excluded rows, and each row’s status at every step.

- [`cohort()`](https://mattmoo.github.io/cohortflow/reference/cohort.md)
  : Extract the surviving cohort from a flow object
- [`excluded()`](https://mattmoo.github.io/cohortflow/reference/excluded.md)
  : Extract excluded rows from a flow object
- [`criteria_status()`](https://mattmoo.github.io/cohortflow/reference/criteria_status.md)
  : Per-criterion status of every row
- [`stack_cohorts()`](https://mattmoo.github.io/cohortflow/reference/stack_cohorts.md)
  : Stack the cohort at each step into one data frame

## Attrition tables

- [`as_attrition_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_tibble.md)
  : Build an attrition tibble from a cohort flow object
- [`as_attrition_table()`](https://mattmoo.github.io/cohortflow/reference/as_attrition_table.md)
  : Format an attrition table from a cohort flow object

## CONSORT diagrams

- [`as_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/as_consort_diagram.md)
  : Build a CONSORT flow diagram from a cohort flow object

- [`save_consort_diagram()`](https://mattmoo.github.io/cohortflow/reference/save_consort_diagram.md)
  : Save a CONSORT diagram for manuscript submission

- [`plot(`*`<cf_flow>`*`)`](https://mattmoo.github.io/cohortflow/reference/plot.cf_flow.md)
  :

  Plot method for `cf_flow` objects

- [`print(`*`<consort_diagram>`*`)`](https://mattmoo.github.io/cohortflow/reference/print.consort_diagram.md)
  :

  Print method for `consort_diagram` objects

## Baseline characteristics

Step-wise “Table 1” of the cohort, or of the rows removed, at each step.

- [`as_characteristics_tibble()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_tibble.md)
  : Characteristics of the cohort at each step
- [`as_characteristics_table()`](https://mattmoo.github.io/cohortflow/reference/as_characteristics_table.md)
  : Render a step-wise characteristics table

## Reproducibility

- [`export_criteria()`](https://mattmoo.github.io/cohortflow/reference/export_criteria.md)
  : Export a criteria pipeline to YAML
- [`import_criteria()`](https://mattmoo.github.io/cohortflow/reference/import_criteria.md)
  : Import a criteria pipeline from YAML

## Example data

Synthetic data for four common trial designs.

- [`mock_parallel_rct()`](https://mattmoo.github.io/cohortflow/reference/mock_parallel_rct.md)
  : Generate synthetic data for a parallel-group randomised controlled
  trial
- [`mock_crossover()`](https://mattmoo.github.io/cohortflow/reference/mock_crossover.md)
  : Generate synthetic data for a crossover trial
- [`mock_cluster_rct()`](https://mattmoo.github.io/cohortflow/reference/mock_cluster_rct.md)
  : Generate synthetic data for a cluster-randomised controlled trial
- [`mock_stepped_wedge()`](https://mattmoo.github.io/cohortflow/reference/mock_stepped_wedge.md)
  : Generate synthetic data for a stepped-wedge cluster-randomised trial

## Deprecated

- [`mock_cohortflow()`](https://mattmoo.github.io/cohortflow/reference/mock_cohortflow.md)
  : Generate synthetic cohort data for testing and examples (deprecated)
