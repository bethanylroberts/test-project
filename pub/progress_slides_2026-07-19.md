---
title: NARWC Database Project — Progress Update
date: 2026-07-19
---

# NARWC Database Project
## Progress Update

July 2026

<!-- VISUAL AID: title slide — NARWC/NEAQ logo or a survey photo, if available -->

---

# Project Scope

- Migrate the historical NARWC sightings database from its legacy flat-file
  format into a modern, validated SQL database
- Build sustainable tools for curating and ingesting new survey data going
  forward
- Target: legacy migration complete and curation tools in usable shape by
  end of August 2026

---

# Legacy Database Migration to SQL Server

- Recovered and rebuilt the full legacy database structure as a modern SQL
  schema
- Automated pipeline: extract, validate, and upload — run against the
  entire historical dataset
- Every record is checked against the rules that matter before it's
  allowed into the database
- Nothing is silently changed — every automatic correction and every
  judgment call is tracked

---

# The Database Schema

- Covers all ~55 survey fields and the lookup tables that constrain them:
  species, behavior, platform, survey block, and more
- Mirrors the structure of the field manual, translated into a relational
  schema
- Ready to deploy — schema creation, indexing, foreign keys, and lookup
  tables are all scripted

<!-- VISUAL AID: schema / ER diagram excerpt -->

---

# The Curation Pipeline

**Extract → Validate → Upload**

- **Extract** — split the single legacy export into one file per survey
- **Validate** — check every survey against 9 categories of rules before
  it's allowed in
- **Upload** — transaction-safe; a failed upload rolls back cleanly rather
  than leaving partial data behind

<!-- VISUAL AID: simple 3-box flow diagram (Extract -> Validate -> Upload) -->

---

# Data Curation Library & Tools

- A MATLAB library for importing and curating incoming surveys, built to
  extend to new data providers
- Automated handling for known, well-understood data-entry patterns
- Change tracking and reporting, so every edit is auditable
- Quality-control reporting to catch problems before they reach the
  database

---

# Validation: What Gets Checked

Every survey is checked against 9 rule categories:

- Required fields, coordinates, dates and times
- Species and taxonomic codes, behavior codes
- Environmental conditions (visibility, sea temperature), Beaufort sea
  state
- Cross-reference integrity against lookup tables (platform, block,
  source codes, and more)

Curators can tune thresholds themselves — e.g. expected group size by
species — by editing a lookup table. No code change required.

---

# Validation In Action — Real Errors

```
[ERROR] TAXCODE: TAXCODE is required for sighting records (rows 51)
[ERROR] SPECCODE: SPECCODE is required for sighting records (rows 51)
[ERROR] TAXCODE: TAXCODE mismatch: got 4, expected 9 for SPECCODE "UNCE" (rows 2238)
[ERROR] YEAR: YEAR outside valid range [1970, 2027]
[ERROR] GLARER: GLARER contains invalid value(s) not in GLARE lookup table: 9 (+427 more rows)
```

Real output from an actual validation run — genuine data-entry issues the
system caught before they reached the database.

---

# Validation In Action — Real Warnings

```
[WARNING] BEHAV: Calf-associated behavior(s) 40 recorded but no calf present (rows 1, EVENTNO=10)
[WARNING] LONG_DD: Longitude outside typical survey area [-85.0, -40.0] (rows 1, EVENTNO=10)
[WARNING] LAT_DD: Latitude outside typical survey area [20.0, 55.0] (rows 22, EVENTNO=380)
[WARNING] NUMCALF: NUMCALF (2) is more than half of NUMBER (3) - verify count (rows 45, EVENTNO=370)
```

Warnings don't block silently — a curator reviews each one and either
fixes the data or formally records why it's expected.

---

# Known, Automatic Corrections

Some legacy data-entry patterns are well understood and get corrected
automatically before validation — e.g. old "not recorded" sentinel values,
trailing whitespace in species codes. Real output from a run:

```
=== Known Fixes Applied ===
PHOTOS = 0 -> 1 (sighting rows): 3 rows across 2 survey(s)
STRIP > 16 -> NULL (NEAq 2021): 0 rows
BEAUFORT = 99 -> NULL: 0 rows
CLOUD = 99 -> NULL: 0 rows
GLAREL = 99 -> NULL: 0 rows
```

Every fix is logged with a row count — nothing is corrected silently.

---

# Graphical User Interface (GUI)

- In progress: a MATLAB-based interface to guide curators through review
  and correction
- Goal: make the review workflow shown in the next few slides accessible
  without hand-editing CSV files

<!-- VISUAL AID: GUI mockup or screenshot once available -->

---

# How To Run It — Getting Set Up

```matlab
% One-time: copy the credentials template and fill in DB access
%   config/local/db_config_local.m.template
%   -> config/local/db_config_local.m

startup                        % add paths, check toolboxes, create data dirs
scripts/setup/test_connection  % verify the database connection end to end
```

`test_connection` runs 7 checks — config, connection, query, sample data —
and prints a pass/fail checklist to the console.

<!-- VISUAL AID: screenshot of the startup/connection-check console output (checkmark-style report) -->

---

# How To Run It — Load & Validate a Survey

```matlab
parser = narwc.io.parsers.StandardFormat();
[data, metadata] = parser.parse('tests/fixtures/sample_data/oT06129.csv');

validator = narwc.validation.SurveyValidator();
[is_valid, results] = validator.validate(data);
disp(results.summary)
```

`is_valid` is `false` if any unacknowledged warning or error exists — by
default, warnings block upload just like errors, until a human reviews
them.

<!-- VISUAL AID: screenshot of a validation run in the MATLAB console -->

---

# How To Run It — Inspecting a Warning

```matlab
w = results.warnings(1);
fprintf('Field:   %s\n', w.field);
fprintf('EVENTNO: %d\n', w.eventno);
fprintf('Rule:    %s\n', w.rule_id);
fprintf('Message: %s\n', w.message);
```

Every warning carries exactly what's needed to make a decision: which
survey, which event, which field, and why it was flagged.

---

# The Override System — Acknowledging One Warning

Curators don't just dismiss a warning — they record a decision, with a
name, a date, and a reason, in a version-controlled file:

```
fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason
f098027,42,LAT_DD,coordinate_rules.outside_survey_lat,RS,2026-06-25,Opportunistic sighting near shore
```

```matlab
validator2 = narwc.validation.SurveyValidator();   % reloads overrides.csv
[is_valid2, results2] = validator2.validate(data);
```

- The acknowledged warning moves out of `results2.warnings`
- `is_valid2` becomes true once nothing unacknowledged remains

---

# The Override System — Acknowledging a Whole Survey

Leaving EVENTNO blank acknowledges every warning of that (field, rule)
combination across an entire survey in one line — for when a whole survey
shares one known, understood pattern:

```
fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason
p905169G,,BEHAV,behavioral_rules.calf_behavior_no_calf,RS,2026-06-25,All 93 calf-behavior events reviewed; survey predates current coding convention
```

- Exact per-row matches are checked first; per-survey acknowledgement is
  the fallback
- Every override is committed to git — the whole team, and every future
  run, shares the same acknowledged state

---

# How To Run It — Bulk Migration

```matlab
step1_extract_surveys('data/legacy/original_csv/RUSS_24_VALID.CSV')
step2_upload_surveys('Config', load_config('migration'))
step3_validate_migration()
```

- Anything that doesn't pass goes to a review queue with a log explaining
  why
- Step 3 generates a summary report

Steps are normally run one at a time today, not as a single hands-off
button, so problems can be caught between them.

---

# Historical Migration — Extraction Results

- **12,578 surveys** extracted from the legacy file
- **11,651,703 records** processed
- Took about **341 minutes** (~5.7 hours) end to end

---

# Historical Migration — Validation & Upload Results

- **11,641 of 12,578 surveys (92.6%) successfully validated and uploaded**
- **937 surveys (7.4%) still have open validation issues** pending review
- The remaining issues are concentrated in a handful of categories, not
  spread evenly across the dataset

<!-- VISUAL AID: pull reports/migration/validation_charts.png from a fresh run -->

---

# What's Still Under Review

The 937 remaining surveys break down into a mix of:

- **Missing required fields** — species/taxonomic code not recorded (the
  largest error category)
- **Lookup code gaps** — a known, small set of missing reference codes
  pending confirmation
- **Behavior-pattern warnings** — a large cluster flagged as
  "calf-associated behavior without a calf present"; still under review,
  not yet resolved
- **Geographic/date outliers** — sightings outside the typical survey
  area or date range, some of which may be legitimate opportunistic
  sightings

This reflects the validation pipeline working as designed — flagging
things for a human decision, not a tooling problem.

---

# Still To Do

1. **Batch converters for the different input file formats** — each data
   provider currently sends surveys in its own format; these need
   dedicated parsers
2. **Test the git-based workflow** end to end
3. **Resolve the remaining data errors and warnings** — the 937 surveys
   above
4. **Get an updated data file from Bob** with the latest corrections
5. **Transfer the full system to NEAQ** — the big remaining milestone

---

# Timeline

- Legacy migration: targeting completion before end of August 2026
- Curation tools: usable shape by end of August 2026
- Full system transfer to NEAQ: following migration completion
