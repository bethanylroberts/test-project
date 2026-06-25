# Warning Override Workflow

This document describes how curators manage validation warnings that are
expected or acceptable and should not block upload.

---

## What warnings mean

When `SurveyValidator` runs, it flags data conditions that may indicate errors.
Warnings are conditions that are suspicious but not definitively wrong — for
example, a latitude that falls slightly outside the typical survey area, or a
year that predates the standard survey era. 

By default, **warnings block upload** just like errors. This is intentional:
every warning should be reviewed by a human before data goes into the database.

---

## The override workflow

1. **Run validation.** Process surveys with `BatchUploader.uploadFromFolder()`.
   Surveys with new warnings will be moved to `failed/` and logged to
   `failed/_errors.log`.

2. **Review each warning.** Open `failed/_errors.log` and read the warning
   messages. For each warning, decide:
   - **Fix the data.** Correct the source CSV and re-run. This is the preferred path.
   - **Acknowledge the warning.** If the data is actually correct and the
     warning is a false positive, add an override entry to `data/overrides.csv`.

3. **Add an override entry.** Open `data/overrides.csv` in a text editor and add
   one row per acknowledged warning:

   ```
   fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason
   f098027,42,LAT_DD,coordinate_rules.outside_survey_lat,RS,2026-06-25,Opportunistic sighting near shore
   ```

   Required fields:
   | Column              | What to enter                                                                      |
   | ------------------- | ---------------------------------------------------------------------------------- |
   | `fileid`            | The survey FILEID (e.g., `f098027`)                                                |
   | `eventno`           | The EVENTNO of the specific event row                                              |
   | `field`             | The field that was flagged (e.g., `LAT_DD`)                                        |
   | `rule_id`           | The rule identifier from the warning (e.g., `coordinate_rules.outside_survey_lat`) |
   | `acknowledged_by`   | Your name or initials                                                              |
   | `acknowledged_date` | Today's date in `YYYY-MM-DD` format                                                |
   | `reason`            | Brief explanation (optional but recommended)                                       |

4. **Re-run the upload.** Move the survey CSV back to `pending/` and run the
   uploader again. Surveys whose warnings all match entries in
   `data/overrides.csv` will now upload successfully. Surveys with any
   unacknowledged warnings will still fail.

5. **Commit `data/overrides.csv`.** The override file is version-controlled.
   After adding entries, commit it so other curators and future runs share the
   same acknowledged state.

---

## Finding the rule_id for a warning

The `rule_id` appears in the validation output and in `_errors.log`. It takes the form `<rule_file>.<check_name>`, for example:

| rule_id                                         | What it checks                                |
| ----------------------------------------------- | --------------------------------------------- |
| `coordinate_rules.outside_survey_lat`           | Latitude outside typical survey area          |
| `coordinate_rules.outside_survey_lon`           | Longitude outside typical survey area         |
| `datetime_rules.year_too_old`                   | Year before warning threshold (default: 1990) |
| `environmental_rules.visibility_too_high`       | Visibility above maximum                      |
| `environmental_rules.surftemp_too_cold`         | Surface temperature below minimum             |
| `environmental_rules.surftemp_too_hot`          | Surface temperature above maximum             |
| `species_rules.taxcode_not_in_table`            | TAXCODE not found in lookup table             |
| `species_rules.number_zero_for_sighting`        | NUMBER=0 for a sighting record                |
| `species_rules.number_large_group`              | Group size unusually large                    |
| `species_rules.numcalf_exceeds_max`             | Calf count above maximum threshold            |
| `species_rules.numcalf_non_mammal`              | Calf count for non-mammal species             |
| `species_rules.numcalf_exceeds_half`            | Calf count more than half the group           |
| `species_rules.right_whale_large_group`         | Right whale group unusually large             |
| `species_rules.right_whale_high_calf_count`     | Right whale calf count unusually high         |
| `behavioral_rules.calf_behavior_no_calf`        | Calf-associated behavior without calf present |
| `behavioral_rules.taxcode_behavior_restriction` | Behavior not valid for taxcode                |
| `behavioral_rules.species_behavior_restriction` | Behavior not typical for species              |

---

## How to remove an incorrect override

If you acknowledged a warning by mistake, delete the corresponding row from
`data/overrides.csv` and commit the change. The next validation run will treat
that warning as new again.

---

## Override matching is exact

An override suppresses a warning only when all four key fields match exactly:
- `fileid` — exact string match
- `eventno` — exact integer match
- `field` — exact string match
- `rule_id` — exact string match

There is no fuzzy matching or wildcards. If a survey's EVENTNO changes (e.g.,
because rows were inserted above it in the source file), the override will no
longer match and the warning will re-appear. This is by design: EVENTNO is a
stable semantic identifier within a survey and should not change.

---

## When to use `AllowWarnings = true`

The `AllowWarnings = true` option in `BatchUploader.uploadFromFolder()` bypasses
the entire warning gate and uploads surveys regardless of warnings. This is an
emergency escape valve for situations where you need data in the database
immediately and cannot review warnings first.

**Use it rarely and with a documented reason.** Warnings exist for a reason. If
you use `AllowWarnings = true`, make sure you revisit the warnings and either
fix the data or add proper override entries afterward.

---

## Reviewing the run log

After each batch run, two files in `failed/` record what happened:

- `_errors.log` — Human-readable log, one entry per failed survey. Accumulates
  across runs (never overwritten). Each run is separated by a header with
  timestamp and options.
- `_run_summary.csv` — Machine-readable CSV with one row per survey per run:
  fileid, status, error count, new warning count, acknowledged warning count,
  notes.

Use `_run_summary.csv` to track progress across migration runs and confirm that
override additions are having the expected effect.
