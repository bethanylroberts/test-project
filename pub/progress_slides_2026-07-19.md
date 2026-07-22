---
title: NARWC Database Project — Progress Update
date: 2026-07-19
style: |
  .visual-aid {
    border: 2px dashed #999;
    border-radius: 8px;
    padding: 0.8em 1.2em;
    margin-top: 1em;
    text-align: center;
    color: #666;
    font-size: 0.8em;
    line-height: 1.4;
  }
  .visual-aid .tag {
    font-size: 0.7em;
    letter-spacing: 0.05em;
    text-transform: uppercase;
    color: #999;
    margin-bottom: 0.3em;
  }
  .diagram { margin-top: 0.8em; }
  .flow-row { display: flex; align-items: center; justify-content: center; gap: 0.5em; flex-wrap: wrap; }
  .flow-box { border: 2px solid #2c5f7c; border-radius: 8px; padding: 0.4em 0.9em; font-weight: bold; color: #2c5f7c; background: #eef5f8; font-size: 0.85em; }
  .flow-box.small { font-size: 0.7em; padding: 0.3em 0.6em; }
  .flow-box.shared { background: #2c5f7c; color: #fff; }
  .flow-arrow { font-size: 1.3em; color: #999; }
  .flow-label { font-size: 0.7em; color: #666; text-align: center; margin-bottom: 0.3em; font-weight: bold; }
  .two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 1.5em; margin-top: 0.8em; }
  .two-col > div { display: flex; flex-direction: column; align-items: center; }
  .stat-row { display: flex; gap: 0.8em; margin-top: 0.8em; }
  .stat-card { flex: 1; border: 2px solid #2c5f7c; border-radius: 8px; padding: 0.6em; text-align: center; }
  .stat-number { font-size: 1.5em; font-weight: bold; color: #2c5f7c; display: block; }
  .stat-label { font-size: 0.65em; color: #666; }
  .bar-chart { margin-top: 0.8em; }
  .bar-row { display: flex; align-items: center; gap: 0.5em; margin: 0.35em 0; font-size: 0.7em; }
  .bar-label { width: 34%; text-align: right; color: #444; }
  .bar-track { flex: 1; background: #eee; border-radius: 4px; overflow: hidden; height: 0.9em; }
  .bar-fill { background: #2c5f7c; height: 100%; }
  .bar-fill.warn { background: #c47a2c; }
  .bar-value { width: 14%; font-weight: bold; color: #2c5f7c; }
  .bar-note { font-size: 0.55em; color: #999; margin-top: 0.4em; }
  .lookup-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 0.4em; margin-top: 0.6em; }
  .lookup-chip { border: 1px solid #2c5f7c; border-radius: 6px; padding: 0.3em; text-align: center; font-size: 0.62em; color: #2c5f7c; background: #eef5f8; }
  .timeline { display: flex; align-items: flex-start; margin-top: 1em; }
  .tl-point { display: flex; flex-direction: column; align-items: center; flex: 0 0 auto; }
  .tl-dot { width: 12px; height: 12px; border-radius: 50%; background: #2c5f7c; }
  .tl-line { flex: 1; height: 2px; background: #2c5f7c; margin: 6px 4px 0; }
  .tl-label { font-size: 0.65em; text-align: center; margin-top: 0.4em; max-width: 7em; }
  .tl-date { color: #666; display: block; }
---

# NARWC Database Project
## Progress Update

July 2026

<div class="visual-aid">
<div class="tag">Visual placeholder</div>
<strong>Title visual</strong> — NARWC/NEAQ logo or a representative survey photo
</div>

<!--
Set the tone: this is a working progress update, not a final delivery.
Q&A welcome throughout rather than saved to the end.
-->

---

# Project Scope

- Migrate the legacy NARWC database into a modern, validated SQL database
- Build tools to keep curating and ingesting new survey data going forward
- Target: migration complete and curation tools ready by end of August 2026

<!--
Two-part project: one-time migration + ongoing curation tooling.
August deadline is tied to the curator's availability (out Aug 1-18).
-->

---

# Legacy Database Migration to SQL Server

- Rebuilt the full legacy structure as a modern SQL schema
- Automated pipeline: extract, validate, upload — run against the entire
  historical dataset
- Every record is checked before it's allowed in; nothing is silently
  changed

<!--
This is the "before" picture — sets up the schema and pipeline slides
that follow.
-->

---

# The Database Schema

- One central table (~55 fields); **24 lookup tables** constrain species,
  behavior, platform, and more
- **35 foreign key constraints** — the database itself rejects unrecognized
  codes, even if something slips past validation

<div class="diagram">
<div class="flow-row"><div class="flow-box">Master (~55 fields)</div></div>
<div class="lookup-grid">
<div class="lookup-chip">SPECCODE</div>
<div class="lookup-chip">TAXCODE</div>
<div class="lookup-chip">PLATFORM</div>
<div class="lookup-chip">Behave</div>
<div class="lookup-chip">Block</div>
<div class="lookup-chip">ANHEAD</div>
<div class="lookup-chip">DDSOURCE</div>
<div class="lookup-chip">+ 17 more</div>
</div>
</div>

<!--
Emphasize: validation in code AND constraints in the database — two
independent layers, not one point of failure.
-->

---

# Setting Up a New Database

Run once, in order, against a fresh SQL Server instance:

<div class="diagram">
<div class="flow-row">
<div class="flow-box small">1. Create DB</div><div class="flow-arrow">→</div>
<div class="flow-box small">2. Master table</div><div class="flow-arrow">→</div>
<div class="flow-box small">3. Lookup tables</div><div class="flow-arrow">→</div>
<div class="flow-box small">4. Indexes</div><div class="flow-arrow">→</div>
<div class="flow-box small">5. Foreign keys</div><div class="flow-arrow">→</div>
<div class="flow-box small">6. Populate lookups</div>
</div>
</div>

Scripts are idempotent and credential-free — connect externally first.

<!--
This is what stands up a brand-new, empty NARWCDB from scratch — relevant
if NEAQ ends up hosting the database themselves.
-->

---

# The Data Pipeline

Two ways surveys enter the database — only the first step differs:

<div class="two-col">
<div>
<div class="flow-label">Migration (one-time)</div>
<div class="flow-box">Extract</div>
</div>
<div>
<div class="flow-label">Routine (ongoing)</div>
<div class="flow-box">Convert</div>
</div>
</div>
<div class="flow-row" style="margin-top:0.5em;"><div class="flow-arrow">↓</div></div>
<div class="flow-row">
<div class="flow-box shared">Validate</div>
<div class="flow-arrow">→</div>
<div class="flow-box shared">Upload</div>
</div>

The database is a second line of defense via foreign key constraints.

<!--
Key point for NEAQ: adding a new data contributor only touches the first
box (Convert) — Validate and Upload never change.
-->

---

# How It's Built

- One shared validation and upload process, no matter where data came from
- Adding a new contributor is a small, isolated piece of work
- Backed by an automated test suite, so changes can't silently break what
  already works

<!--
This is the "why it matters" slide — plain-language version of the
architecture just shown.
-->

---

# Data Curation Library & Tools

- MATLAB library for importing and curating surveys, built to extend to
  new providers
- Automated handling for known data-entry patterns
- Change tracking and quality-control reporting throughout

<!--
This is the toolbox curators use day to day, distinct from the one-time
migration.
-->

---

# Validation: What Gets Checked

Every survey is checked against 9 rule categories:

- Required fields, coordinates, dates and times
- Species, taxonomic, and behavior codes
- Environmental conditions and Beaufort sea state
- Cross-reference integrity against lookup tables

Curators can tune thresholds themselves — no code change required.

<!--
If asked "how do curators adjust sensitivity" — point to lookup-table
CSVs, not code changes.
-->

---

# Validation In Action — Real Errors

```
[ERROR] TAXCODE: TAXCODE mismatch: got 2, expected 1 for SPECCODE "RIWH" (rows 2, EVENTNO=42)
[ERROR] SPECCODE: SPECCODE "RIWHT" exceeds 4 characters (rows 1, EVENTNO=5)
[ERROR] TAXCODE: TAXCODE is required for sighting records (rows 51)
[ERROR] GLARER: GLARER contains invalid value(s) not in GLARE lookup table: 9 (+427 more rows)
```

Single-record issues show the exact EVENTNO; issues spanning many records
show a count instead.

<!--
Genuine output from the validation engine. First two include EVENTNO
(new fix); last two are historical, dataset-wide issues.
-->

---

# Validation In Action — Real Warnings

```
[WARNING] BEHAV: Calf-associated behavior(s) 40 recorded but no calf present (rows 1, EVENTNO=10)
[WARNING] LONG_DD: Longitude outside typical survey area [-85.0, -40.0] (rows 1, EVENTNO=10)
[WARNING] LAT_DD: Latitude outside typical survey area [20.0, 55.0] (rows 22, EVENTNO=380)
[WARNING] NUMCALF: NUMCALF (2) is more than half of NUMBER (3) - verify count (rows 45, EVENTNO=370)
```

Warnings never block silently — a curator reviews each one and either
fixes the data or records why it's expected.

<!--
Contrast with errors: warnings are judgment calls, not hard stops.
-->

---

# Known, Automatic Corrections

These reproduce corrections Bob has already made in the official
database — so migrated data matches what he's already hand-corrected.

```
=== Known Fixes Applied ===
PHOTOS = 0 -> 1 (sighting rows): 3 rows across 2 survey(s)
STRIP > 16 -> NULL (NEAq 2021): 0 rows
BEAUFORT = 99 -> NULL: 0 rows
```

Every fix is logged with a row count in that run's error log.

<!--
If asked "where's the audit trail" — the error log, every run, not just
a one-time note.
-->

---

# How To Run It — Getting Set Up

```matlab
startup                        % add paths, check toolboxes, create data dirs
scripts/setup/test_connection  % verify the database connection
```

Checks config, connection, and sample data with a pass/fail checklist.

<div class="visual-aid">
<div class="tag">Visual placeholder</div>
<strong>Console output</strong> — screenshot of the startup/connection-check checklist
</div>

<!--
One-time step: credentials come from config/local/db_config_local.m,
copied from the template first.
-->

---

# How To Run It — Convert a Contributor's Batch

```matlab
convert_contributor_batch('neaq', 'NEAQFormat')
```

- Converts a contributor's raw files into standard-format survey files,
  ready to upload
- New contributors just need one small parser, written once

<div class="visual-aid">
<div class="tag">Visual placeholder</div>
<strong>Console output</strong> — screenshot of a conversion run
</div>

<!--
This is the step that replaces manual format-wrangling per contributor.
-->

---

# How To Run It — Upload & Validate

```matlab
upload_contributor_batch('Config', load_config('routine'))
```

- Validates and uploads everything that passes
- Anything that doesn't goes to a review queue with a log explaining why

<div class="visual-aid">
<div class="tag">Visual placeholder</div>
<strong>Console output</strong> — screenshot of an upload run
</div>

<!--
Same underlying code as migration upload, just a different config preset.
-->

---

# The Override System — Acknowledging One Warning

Curators record a decision — name, date, reason — in a version-controlled
file:

```
fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason
f098027,42,LAT_DD,coordinate_rules.outside_survey_lat,RS,2026-06-25,Opportunistic sighting near shore
```

Re-run the upload to pick up the acknowledgement.

<!--
Emphasize: it's a record, not a dismissal — every override is auditable.
-->

---

# The Override System — Acknowledging a Whole Survey

Leave EVENTNO blank to acknowledge every matching warning in a survey at
once:

```
fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason
p905169G,,BEHAV,behavioral_rules.calf_behavior_no_calf,RS,2026-06-25,All 93 calf-behavior events reviewed; survey predates current coding convention
```

Exact per-row matches win; per-survey is the fallback. Committed to git,
so the whole team shares the same state.

<!--
Use sparingly — this is the "many warnings, one known cause" shortcut.
-->

---

# How To Run It — Bulk Migration

```matlab
step1_extract_surveys('data/legacy/original_csv/RUSS_24_VALID.CSV')
step2_upload_surveys('Config', load_config('migration'))
step3_validate_migration()
```

Steps run one at a time today, so problems can be caught between them.

<!--
Contrast with the contributor path shown earlier — same shape, migration-
specific config and defaults.
-->

---

# Historical Migration — Extraction Results

<div class="stat-row">
<div class="stat-card"><span class="stat-number">12,578</span><span class="stat-label">surveys extracted</span></div>
<div class="stat-card"><span class="stat-number">11.65M</span><span class="stat-label">records processed</span></div>
<div class="stat-card"><span class="stat-number">~341 min</span><span class="stat-label">elapsed (~5.7 hrs)</span></div>
</div>

<!--
Raw extraction step only — validation/upload results are next slide.
-->

---

# Historical Migration — Validation & Upload Results

<div class="bar-chart">
<div class="bar-row"><div class="bar-label">Uploaded</div><div class="bar-track"><div class="bar-fill" style="width:92.6%"></div></div><div class="bar-value">92.6%</div></div>
<div class="bar-row"><div class="bar-label">Under review</div><div class="bar-track"><div class="bar-fill warn" style="width:7.4%"></div></div><div class="bar-value">7.4%</div></div>
</div>

**11,641 of 12,578 surveys** successfully validated and uploaded;
**937** still have open issues, pending review.

<!--
92.6% is a real, current number — not a placeholder. "What's in the
7.4%?" is answered on the next slide.
-->

---

# What's Still Under Review

<div class="bar-chart">
<div class="bar-row"><div class="bar-label">Behavior-pattern warnings</div><div class="bar-track"><div class="bar-fill" style="width:100%"></div></div><div class="bar-value">2,368</div></div>
<div class="bar-row"><div class="bar-label">Geographic/date outliers</div><div class="bar-track"><div class="bar-fill" style="width:89%"></div></div><div class="bar-value">2,099</div></div>
<div class="bar-row"><div class="bar-label">Missing required fields</div><div class="bar-track"><div class="bar-fill" style="width:15%"></div></div><div class="bar-value">347</div></div>
<div class="bar-row"><div class="bar-label">Lookup code gaps</div><div class="bar-track"><div class="bar-fill" style="width:2%"></div></div><div class="bar-value">54</div></div>
<div class="bar-note">Counts are validation instances from the review run, not distinct surveys — one survey can trigger more than one.</div>
</div>

Validation working as designed — flagging for a human decision, not a
tooling problem.

<!--
Don't let this read as "broken" — reframe as known, categorized, and
being worked through.
-->

---

# Still To Do

1. **Batch converters** for each contributor's input format
2. **Test the git-based workflow** end to end
3. **Resolve** the remaining 937 surveys
4. **Get an updated data file** from Bob
5. **Transfer the full system to NEAQ** — the big remaining milestone

<!--
#5 is the headline ask — everything else is groundwork for it.
-->

---

# Timeline

<div class="timeline">
<div class="tl-point"><div class="tl-dot"></div><div class="tl-label">Now<span class="tl-date">Jul 2026</span></div></div>
<div class="tl-line"></div>
<div class="tl-point"><div class="tl-dot"></div><div class="tl-label">Migration complete<span class="tl-date">End Aug 2026</span></div></div>
<div class="tl-line"></div>
<div class="tl-point"><div class="tl-dot"></div><div class="tl-label">NEAQ transfer<span class="tl-date">Following</span></div></div>
</div>

<!--
Curator is away Aug 1-18 — migration needs to land before she leaves.
-->
