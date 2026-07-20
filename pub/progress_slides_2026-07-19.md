---
title: NARWC Database Project — Progress Update
date: 2026-07-19
---

# NARWC Database Project
## Progress Update

July 2026

---

# Project Scope

- Migrate the historical NARWC sightings database from its legacy flat-file
  format into a modern, validated SQL database
- Build sustainable tools for curating and ingesting new survey data going
  forward
- Target: legacy migration complete and curation tools in usable shape by
  end of August 2026

---

# What's Built: The Database

- A complete, modern SQL schema for the sightings database, rebuilt from
  the recovered legacy structure
- Covers all survey fields, lookup tables (species, behavior, platform,
  survey block, and more), and the relationships between them
- Ready to deploy

---

# What's Built: The Migration Pipeline

- End-to-end pipeline: extract individual surveys from the legacy file,
  validate each one, upload to the database
- Uploads are transaction-safe — a failed upload rolls back cleanly rather
  than leaving partial data
- Runs against the full historical dataset (~1,200 surveys)

---

# What's Built: Data Validation

- Every survey is checked against the rules that matter: required fields,
  coordinates, dates and times, species and behavior codes, environmental
  conditions, and cross-reference integrity
- Known, reviewed exceptions can be explicitly acknowledged and tracked —
  nothing is silently ignored or silently changed
- Curators can tune validation thresholds themselves (e.g. expected group
  sizes by species) without needing code changes

---

# Where the Migration Stands

- The pipeline, schema, and validation are ready
- What remains is **data cleanup**, not tooling:
  - A known set of missing reference codes (species, behavior, platform,
    and similar lookup values) need confirmation
  - A known set of individual surveys have specific data issues that need
    review and correction
- Once those are resolved, the full historical dataset is ready to load

---

# Still To Do

1. **Batch converters for the different input file formats** — each data
   provider currently sends surveys in its own format; these need
   dedicated parsers
2. **Test the git-based workflow** end to end
3. **Resolve the remaining data errors and warnings** in the historical
   data
4. **Get an updated data file from Bob** with the latest corrections
5. **Transfer the full system to NEAQ** — the big remaining milestone

---

# Timeline

- Legacy migration: targeting completion before end of August 2026
- Curation tools: usable shape by end of August 2026
- Full system transfer to NEAQ: following migration completion
