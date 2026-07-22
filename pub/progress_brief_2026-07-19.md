# NARWC-DB Progress Brief

*Prepared 2026-07-19, covering work since the last team presentation (`NARWCDB-progress_report-20251112.ppt`, last updated 2026-02-17).*

## Where things stood at the last update

The February presentation covered three areas:

- **Legacy database migration to SQL Server** — reported a modernized SQL schema, an automated CSV-to-SQL pipeline, and roughly 10.7 million historical records migrated with a claimed 100% import rate and zero critical validation errors. (Note: the deck's results table was still marked "TODO: pull actual numbers," so these figures should be treated as a draft snapshot rather than a confirmed final result.)
- **Data curation library and scripts** — a MATLAB library for importing and curating incoming surveys, with most sub-items (custom per-provider parsers, automated processing, change tracking, validation, visualizations, quality-control reporting) flagged as in progress.
- **Curator GUI** — an early-stage MATLAB interface for the data curation process, also in progress, plus a validation approach based on the domain expert's (Bob's) existing tools.

## What's been done since (Feb 17 – Jul 19, 2026)

Roughly 65 commits landed on the `refactor` branch in this window. The work falls into a few clear threads:

**Config system overhaul.** Replaced ad hoc/hardcoded defaults with a layered config system (`defaults → local → batch`, later wins). Removed the old binary "legacy mode" toggle in favor of proper per-context configuration, and moved remaining hardcoded validation parameters into config files.

**Pipeline restructuring.** Renamed and relocated the core upload class (`BatchConverter` → `BatchUploader`), moved it and `SurveyExtractor` into a new `+ingestion` package, and made per-survey uploads transaction-safe (delete + insert wrapped in a DB transaction with rollback on failure).

**Validation and override system.** Replaced the single `AllowWarnings` on/off switch with a granular, version-controlled acknowledgement system: individual warnings can be signed off per-row or per-survey via an override CSV, keyed to a stable rule ID. Validation thresholds for group-size warnings (NUMBER/NUMCALF) were made data-driven — curators can now adjust them by editing lookup-table CSVs instead of touching code. Several validation rules were also vectorized and cleaned up for performance and accuracy.

**SQL schema work.** Recovered and rewrote the full NARWCDB SQL schema from scratch as six ordered scripts (create DB → tables → indexes → foreign keys → populate lookups), along with foreign-key integrity checks and row-count verification scripts. Lookup tables were normalized (consistent quoting, deduplication, header rows) and moved into version control under `data/tables/`, with new pull/push scripts to sync them against the live database.

**Testing and quality.** Added a baseline test suite with characterization tests, fixed several bugs surfaced by those tests (including a row-count off-by-one and two config-related failures), and corrected a fixture problem where tests were using headerless files instead of real survey headers. The suite now stands at 90 passing tests, 0 failing, 10 skipped (those require a live database connection).

**Documentation and data auditing.** Added a pipeline walkthrough document for curator onboarding, a full database schema reference, and reorganized `PROJECT_STATUS.md` for readability. Completed a lookup-table audit identifying 19 missing codes across six tables (species, behavior, platform, block, glare, and header-angle codes) and catalogued specific per-survey data corrections needed for roughly a dozen individual surveys — both pending confirmation from the domain expert.

## How the System Is Built

At a basic level, the software is organized into a few clear layers:

- **Parsers** — one per source format, each responsible for turning a
  contributor's raw file into the standard field layout the database
  expects. `StandardFormat` reads the historical legacy export;
  `NEAQFormat` is the first parser for a live data contributor.
- **Validation** — a shared framework of 9 rule modules that checks every
  survey record for required fields, valid coordinates, dates, species and
  behavior codes, and more, regardless of where the data came from.
- **Database layer** — a thin wrapper around the SQL Server connection
  that handles inserts, transactions, and rollback on failure.
- **Ingestion** — the layer that ties parsing, validation, and upload
  together into an actual pipeline.

**The migration/routine split.** There are two ways surveys get into the
database, and until this week they were built as two separate, overlapping
pipelines. They're now unified so that only the very first step differs:

1. **Legacy migration** (one-time) — the single, giant historical export
   file gets split into one file per survey.
2. **Routine ingestion** (ongoing) — each contributor's seasonal file gets
   run through that contributor's own parser (translating their column
   names/layout into the standard format), then split into one file per
   survey the same way.

From that point on, both paths are identical: every survey file —
regardless of how it arrived — goes through the same validation rules and
the same upload process, including the same warning-acknowledgement
workflow. Practically, this means adding support for a new data
contributor is just a matter of writing one small parser class; nothing
about validation or uploading has to change or be duplicated.

**Test suite.** The codebase has an automated test suite (MATLAB's
built-in unit testing framework) currently passing 160 of 171 tests. Many
of these are "characterization tests" — they lock in how key pieces of the
pipeline behave today, so a future change can't silently alter that
behavior without a test failing first to flag it. New capability (like the
migration/routine unification above) is built test-first: the test is
written to describe the expected behavior, confirmed to fail, and only
then is the code written to make it pass. The 11 remaining failures either
require a live database connection not available in this environment, or
reflect one pre-existing, unrelated config/test mismatch.

## Where things stand now

The pipeline is functional end-to-end: extract surveys from the legacy flat file, validate against nine rule modules, acknowledge expected warnings, and upload to SQL Server inside a transaction. What's blocking full historical migration:

- **Lookup table gaps** — 19 codes across six lookup tables, pending confirmation
- **Per-survey corrections** — roughly a dozen surveys with specific field-level issues (bad codes, missing signs, ambiguous values) that need explicit fixes
- **SQL Server deployment** — schema scripts are written but haven't yet been run against the production instance
- **Live transaction verification** — the transaction-safe upload logic has only been verified against a mock; behavior with the real database driver is unconfirmed

New-survey ingestion (the second phase of the project — new parser formats and a curator-facing GUI) has not started; that begins after the legacy migration is complete.

## Timeline

The project deadline is end of August 2026. The curator, who will be the primary user of the new curation tools, is away August 1–18, so the legacy migration needs to be complete before she leaves, with Phase 2 tools in usable shape by the time she returns.
