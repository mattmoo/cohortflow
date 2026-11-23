# narratives read as expected

    Code
      as_narrative(make_flow_categorised())
    Output
      Of 200 participants assessed for eligibility, 13 (6.5%) were excluded: not
      meeting "Age recorded" (n = 10) and not meeting "Adults only" (n = 3). A
      further 20 (10.7%) were excluded (not meeting "Passed screening"). A further 35
      (21.0%) were excluded: not meeting "Consent recorded" (n = 24) and withdrew
      consent (n = 11), leaving 132. The final cohort comprised 132 participants
      (66.0% of those assessed).
    Code
      as_narrative(make_flow_flat())
    Output
      Of 200 participants assessed for eligibility, 10 (5.0%) were excluded (not
      meeting "Age recorded"). A further 3 (1.6%) were excluded (not meeting "Adults
      only"). A further 44 (23.5%) were excluded (not meeting "Consent recorded"). A
      further 11 (7.7%) were excluded (withdrew consent), leaving 132. The final
      cohort comprised 132 participants (66.0% of those assessed).
    Code
      as_narrative(make_flow_randomise_multistep())
    Output
      Of 240 participants assessed for eligibility, 12 (5.0%) were excluded (not
      meeting "Age recorded"). A further 7 (3.1%) were excluded (not meeting "Adults
      only"), leaving 221. The remaining 221 were randomised to Control (n = 110) and
      Intervention (n = 111). After randomisation, 7 (6.4%) in Control and 4 (3.6%)
      in Intervention were excluded (withdrew after allocation). A further 38 (36.9%)
      in Control and 38 (35.5%) in Intervention were excluded (missed baseline
      visit). The final cohort comprised 134 participants (55.8% of those assessed):
      65 in Control and 69 in Intervention.
    Code
      as_narrative(make_flow_no_exclusions())
    Output
      Of 100 participants assessed for eligibility, none were excluded; the final
      cohort comprised 100 participants.
    Code
      as_narrative(make_flow_narrative_example())
    Output
      Of 200 participants assessed for eligibility, 16 (8.0%) were excluded: age
      missing (n = 10) and under 18 (n = 6). A further 41 (22.3%) were excluded (did
      not consent), leaving 143. The remaining 143 were randomised to Control (n =
      74) and Intervention (n = 69). After randomisation, 11 (14.9%) in Control and
      10 (14.5%) in Intervention were excluded: withdrew consent (Control 3,
      Intervention 4) and BMI not recorded (Control 8, Intervention 6). The final
      cohort comprised 122 participants (61.0% of those assessed): 63 in Control and
      59 in Intervention.

# bullet style gives one sentence per line

    Code
      as_narrative(make_flow_randomise_multistep(), style = "bullets")
    Output
      - Of 240 participants assessed for eligibility, 12 (5.0%) were excluded (not
        meeting "Age recorded").
      - A further 7 (3.1%) were excluded (not meeting "Adults only"), leaving 221.
      - The remaining 221 were randomised to Control (n = 110) and Intervention (n =
        111).
      - After randomisation, 7 (6.4%) in Control and 4 (3.6%) in Intervention were
        excluded (withdrew after allocation).
      - A further 38 (36.9%) in Control and 38 (35.5%) in Intervention were excluded
        (missed baseline visit).
      - The final cohort comprised 134 participants (55.8% of those assessed): 65 in
        Control and 69 in Intervention.

# zero-row and zero-step flows give one sentence

    Code
      as_narrative(zero_rows)
    Output
      Of 0 participants assessed for eligibility, none were excluded.
    Code
      as_narrative(zero_steps)
    Output
      Of 50 participants assessed for eligibility, none were excluded; the final
      cohort comprised 50 participants.

