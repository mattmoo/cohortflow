# cohortflow (development version)

* `as_attrition_table()` gained a `levels` argument, mirroring
  `as_attrition_tibble(levels = )`: it renders one row per criterion with a
  column block (N / Removed / % removed) per hierarchy level, so a single
  row reports its effect at both the unit of analysis and the unit of
  recruitment (e.g. participants and clusters) side by side. This is the
  reporting form required by the CONSORT cluster extension (Campbell,
  Elbourne & Altman, BMJ 2004;328:702-8) and the within-person extension.
  New `level_labels` argument supplies display names for the column blocks
  (level names are otherwise used as-is, unmangled). A `show_consequential`
  argument adds an optional fourth column per level for units lost only
  because a `group_include()`/`group_exclude()` group they belonged to was
  removed; by default it appears only when populated. `levels` cannot be
  combined with `group_x`/`group_y`/`branch_by`/`count_by`. Shading
  (`shade`/`shade_fn`) is computed per level.
