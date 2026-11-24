# LLM use statement

cohortflow was developed with substantial help from large language model
(LLM) coding assistants. This page says which tools were used, what they
were used for, and how their output was checked.

## Tools

- **GitHub Copilot** in Visual Studio Code, running Anthropic’s Claude
  models, from the start of development (April 2026).
- **Claude Code** (Anthropic), from August 2026, with Claude Opus 5.5,
  Claude Sonnet 5.5 and Claude Fable 5.1.

## What the assistants did

The assistants wrote much of the package’s code, unit tests, roxygen
documentation, vignettes and articles, and the package logo. They also
drafted implementation plans, reviewed code for bugs, and ran the test
suite and `R CMD check` during development.

## What the author did

I (Matthew Moore) decided what the package should do: its scope, its
interface, and how it should count and report participants. I wrote or
approved the plan for each feature before it was implemented, and I
reviewed every change before it was merged. I am responsible for all of
the package’s contents, including any errors in them.

## How the output was checked

- An automated test suite (`testthat`) covers the package’s functions,
  including the counts in attrition tables, diagrams and narrative text.
  Coverage is tracked on
  [Codecov](https://codecov.io/gh/mattmoo/cohortflow).
- Every pull request and push to `master` runs `R CMD check` on Linux,
  macOS and Windows, and `lintr`, through GitHub Actions.
- Worked examples in the articles are re-run each time this site is
  built, so their output comes from the current code.

## Data

All example datasets in the package
([`mock_parallel_rct()`](https://mattmoo.github.io/cohortflow/reference/mock_parallel_rct.md)
and the other `mock_*()` functions) are synthetic. No real participant
or patient data were shared with any AI tool during development.

## Tracing AI contributions

Since August 2026, commits made with Claude Code end with a
`Co-Authored-By: Claude ...` trailer, so the [commit
history](https://github.com/mattmoo/cohortflow/commits/master) shows
which changes they were involved in. Earlier commits, made with GitHub
Copilot, carry no such marker, so assume that any part of the package
may have been written with AI assistance.

If you find a problem, please [open an
issue](https://github.com/mattmoo/cohortflow/issues).

*Last updated: 24 November 2026.*
