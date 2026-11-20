# The missing-`reason` warning in as_consort_diagram() is throttled (shown at
# most every 8 hours), so it would fire in whichever test happens to draw a
# categorised diagram first, making results depend on test order. Turn it off
# here; tests that check it turn it back on locally.
withr::local_options(cohortflow.warn_missing_reason = FALSE, .local_envir = teardown_env())
