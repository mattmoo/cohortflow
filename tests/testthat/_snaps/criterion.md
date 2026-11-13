# evaluation errors interpolate the real values

    Code
      cohortflow:::eval_criterion(cf_criterion(function(d) d$x * 2, label = "Doubled x"),
      d)
    Condition
      Error in `cohortflow:::eval_criterion()`:
      ! Criterion predicate must return a logical vector.
      x Criterion "Doubled x" returned <numeric>.

---

    Code
      cohortflow:::eval_criterion(cf_criterion(function(d) TRUE, label = "Scalar"), d)
    Condition
      Error in `cohortflow:::eval_criterion()`:
      ! Criterion predicate must return a vector of length 3 (`nrow(data)`).
      x Criterion "Scalar" returned length 1.

---

    Code
      cohortflow:::eval_group_criterion(cf_criterion(~ n() >= 2, label = "Big site",
      type = "group_include", by = "site"), d)
    Condition
      Error in `cohortflow:::eval_group_criterion()`:
      ! Grouping column(s) `site` not found in data.
      i Criterion: "Big site"

---

    Code
      cohortflow:::eval_select_criterion(cf_criterion(~ x == min(x), label = "Lowest",
      type = "select_within", by = c("grp", "site")), d)
    Condition
      Error in `cohortflow:::eval_select_criterion()`:
      ! Grouping column(s) `site` not found in data.
      i Criterion: "Lowest"

