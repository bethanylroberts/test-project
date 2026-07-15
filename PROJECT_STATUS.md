# NARWC Database Project — Status

_Branch: refactor | Last updated: 2026-06-29_

---

## 1. Current state

The system can extract per-survey CSV files from a monolithic legacy flat-file (SAS-era export), validate each survey against 9 rule modules covering required fields, coordinates, datetime, species, environmental conditions, Beaufort sea state, behavior codes, photos, and foreign-key constraints, acknowledge specific validation warnings via a version-controlled override file (`data/overrides.csv`), and upload validated surveys to a SQL Server `Master` table via transaction-safe inserts (rollback on failure). The override system supports per-row acknowledgements keyed on `(fileid, eventno, field, rule_id)` and per-survey acknowledgements (empty `eventno` to suppress a warning class across an entire survey). Test suite: 90 passing, 0 failing, 10 DB-skipped (require live SQL Server).

What the system cannot do yet: ingest new-format surveys (NEAQFormat parser is a stub), apply Bob's known bulk corrections automatically, or provide a curator-facing GUI. Live SQL Server transaction behavior has not been verified end-to-end; the Mac-side mock tests verify control flow only.

---

## 2. Project scope

The project delivers two things:

1. **Legacy migration** — migrate the NARWC sightings database from a SAS-era flat-file CSV into a modern SQL schema with validation, error tracking, and a version-controlled correction record.
2. **Curation tools** — provide a sustainable pathway for ingesting new surveys and a curator-facing interface for managing data quality going forward.

**Deadline: end of August 2026.** Curator is away August 1–18 and will be the primary user of the curation tools post-handoff. Phase 1 (legacy migration) should be complete before she leaves; Phase 2 tools should be in usable shape on her return.

---

## 3. Repository map

```
NARWC-DB/
├── startup.m                   # Adds all paths, checks toolboxes, creates data dirs — run first
├── config/
│   ├── load_config.m           # Layered config loader: defaults < local < batch
│   ├── get_config.m            # Legacy config source (paths, validation params); still used by rule modules
│   ├── get_lookup_table.m      # Loads CSV lookup tables from data/tables/ by name
│   ├── reload_config.m         # Clears cached get_config singleton
│   ├── defaults/               # Version-controlled baseline values (db, validation, pipeline)
│   ├── local/                  # Gitignored; contains db_config_local.m with credentials
│   ├── batches/                # Per-workflow override files (migration.m, future: routine.m)
│   └── overrides/              # Per-batch warning-override CSVs and README
│
├── src/
│   ├── +migration/
│   │   ├── apply_known_fixes.m    # Category C corrections applied pre-validation
│   │   ├── ConversionValidator.m  # FIXME:DELETE — unused
│   │   └── MetadataExtractor.m    # FIXME:DELETE — unused
│   │
│   └── +narwc/
│       ├── +ingestion/
│       │   ├── BatchUploader.m     # Workhorse: validates + uploads from pending/, transaction-safe overwrite
│       │   └── SurveyExtractor.m   # Splits monolithic legacy CSV into per-survey CSV files
│       ├── +db/
│       │   ├── Connection.m        # DB connection wrapper; includes beginTransaction/commit/rollback
│       │   └── FieldDefinitions.m  # Single source of truth for all 55 field names and types
│       ├── +io/
│       │   ├── SurveyReader.m          # FIXME:DELETE
│       │   ├── DataTypeConverter.m     # Type coercion before sqlwrite()
│       │   └── +parsers/
│       │       ├── BaseParser.m        # Abstract base class for all parsers
│       │       ├── StandardFormat.m    # Parser for 55-column legacy CSV (Phase 1)
│       │       ├── NEAQFormat.m        # Stub — needs to be filled in
│       │       ├── TabDeliminatedFormat.m  # FIXME:DELETE — test artifact
│       │       └── ParserFactory.m         # FIXME:REMOVE — manual selection preferred
│       ├── +validation/
│       │   ├── SurveyValidator.m       # Orchestrates all rule modules; loads overrides.csv
│       │   ├── FieldValidator.m        # Static field-level validators (range, set, missing)
│       │   ├── ErrorCollector.m        # Accumulates errors/warnings/info by field and severity
│       │   └── +rules/
│       │       ├── _rules_template.m       # Template for new rules
│       │       ├── coordinate_rules.m
│       │       ├── datetime_rules.m
│       │       ├── species_rules.m
│       │       ├── behavioral_rules.m
│       │       ├── environmental_rules.m
│       │       ├── beaufort_rules.m
│       │       ├── foreign_key_rules.m
│       │       ├── required_fields.m
│       │       ├── photos_rules.m
│       │       ├── platform_rules.m
│       │       └── temportal_rules.m       # (filename misspelling; rename pending)
│       ├── +processing/
│       │   ├── SurveyProcessor.m           # Pipeline runner — exercised by tests only
│       │   ├── ChangeTracker.m             # Field-level change tracking — may not be needed
│       │   └── +steps/
│       │       ├── remove_duplicates.m     # FIXME: do not use
│       │       ├── standardize_coordinates.m
│       │       ├── standardize_species_codes.m
│       │       ├── calculate_derived_fields.m
│       │       └── flag_outliers.m
│       ├── +reports/
│       │   ├── ValidationReport.m
│       │   ├── ProcessingReport.m
│       │   └── SummaryStatistics.m
│       └── +utils/
│           └── sanitize_filename.m
│
├── scripts/
│   ├── smoke_validate.m                # Quick end-to-end validation smoke test (TODO: move to tests)
│   ├── migration/
│   │   ├── validate_csv_database_lines.m   # Step 0: per-line CSV sanity check
│   │   ├── step1_extract_surveys.m         # Step 1: calls SurveyExtractor
│   │   ├── step2_upload_surveys.m          # Step 2: calls BatchUploader
│   │   ├── step3_validate_migration.m      # Step 3: analyzes results, generates report
│   │   ├── run_full_migration.m            # Runs steps 1–3 in sequence
│   │   └── generate_migration_report.m     # Produces markdown/HTML report + charts
│   ├── sql/                            # T-SQL schema and operational scripts — see scripts/sql/README.md
│   │   ├── schema/                     # 01–06: create DB → tables → indexes → FKs → populate lookups
│   │   ├── verification/               # Row counts, FK integrity checks
│   │   ├── curation/                   # delete_survey, find_duplicates, recent_uploads
│   │   ├── migration/                  # apply_known_fixes (SQL fallback for post-upload correction)
│   │   └── teardown/                   # drop_all_tables, truncate_master (dev only)
│   └── setup/
│       ├── test_connection.m               # Quick DB connection test
│       ├── pull_lookup_tables.m            # Pulls lookup tables from DB into local CSVs
│       └── push_lookup_tables.m            # Pushes local CSV lookup tables into DB
│
├── tests/
│   ├── test_runner.m / run_*.m         # Test runner infrastructure
│   ├── fixtures/
│   │   ├── TestFixtures.m              # Generates and loads mock survey data
│   │   ├── README.md                   # (planned)
│   │   └── sample_data/                # Per-survey fixture CSVs (aT*, fT*, oT*, pT*, HT*)
│   │       └── aT99001_volume.csv      # Synthetic high-volume fixture for smoke tests
│   └── unit/
│       ├── test_validation.m
│       ├── test_parsers.m
│       ├── test_processing.m
│       ├── test_reports.m
│       ├── test_db_connection.m        # Requires live DB
│       ├── test_get_config.m
│       ├── test_characterization_batch.m
│       ├── test_characterization_extractor.m
│       ├── test_characterization_parser.m
│       └── test_upload_guardrail.m
│
├── lib/
│   └── +logging/                       # Logging toolbox (Logger class + level functions)
│
├── data/                               # Runtime data (mostly gitignored)
│   ├── overrides.example.csv           # Example/template for overrides
│   ├── tables/                         # Lookup table CSVs (committed)
│   ├── legacy/                         # Source CSVs from SAS export
│   └── raw/pending|processed|rejected/ # Staging dirs for new survey ingestion
│
├── docs/                               # Architecture docs, rule guide, testing guide, override guide
├── scripts/sas/                        # SAS QC scripts (Chk*.sas) + legacy PRG/DBF files
└── ref/                                # NARWC Users Guide PDF and other reference material
```

---

## 4. Active work

- **SQL Server schema deployment** — all 6 schema scripts written (`scripts/sql/schema/`); next step is filling in the `<FILL_IN>` path in `06_populate_lookup_tables.sql` and running scripts 01–06 against the SQL Server instance. See `handoffs/db_setup_handoff.md`.
- **Personal pipeline walkthrough** (Russ) — run the full migration end-to-end on a local copy to surface remaining blockers; not yet started
- **Lookup table updates** (Category A, 19 codes) — add missing platform codes (13), species codes (5), behavior codes (2), ANHEAD codes (2), BLOCK code (MB), GLARE code (9) to `data/tables/`; prerequisite for most remaining FK validation failures; pending Bob confirmation on each entry. See §8.4.
- **ANHEAD lookup expansion** — clarify whether ANHEAD=19 is valid or a sentinel; requires domain expert input
- **Per-survey corrections** — specific event/field fixes for individual surveys; see §8.5. Prerequisite for those surveys passing validation.
- **`apply_known_fixes.m`** (Category C) — **done**. `src/+migration/apply_known_fixes.m` implements all 8 fixes; called by `BatchUploader.uploadFromFolder` between CSV parse and validation, gated by `config.pipeline.known_fixes.enabled`. SQL script retained as post-upload fallback. See `docs/known_fixes.md`.
- **Coordinate warning messages** — **done** (2026-06-29). `coordinate_rules.m` now includes the actual lat/lon value in all out-of-range and outside-survey-area warning messages.
- **Package layout refactor** — rename `+io/` → `+ingestion/` (parsers), move `BatchUploader` to `+db/`, extract single-survey `Uploader` from `BatchUploader`; pre-August handoff goal
- **SAS rule porting** — port SAS QC checks (`scripts/sas/Chk*.sas`) to MATLAB validation rules; TAXCODE-aware NUMBER thresholds implemented; remaining SAS checks TBD
- **Opportunistic sighting field warnings** — `required_fields.m` raises 'error' for missing DAY/MONTH/TIME; these should be 'warning' for opportunistic sightings (identified by survey type prefix or explicit flag). Not yet implemented.

---

## 5. Recent commits

```
2026-06-29         Add typical_max_group/typical_max_calf to SPECCODE and TAXCODE;
                   validator NUMBER/NUMCALF rules now use SPECCODE → TAXCODE → global
                   threshold cascade. Curators adjust thresholds via CSV, no code change.
                   Commits A+B: schema/CSV/SQL migration + species_rules.m rewrite.
2026-06-26 ade7fe1 debugging some sql stuff
2026-06-26 875f69c Updated the tests and files to match actual surveys and pass tests
2026-06-26 bb65c5e Add scripts/sql/ scaffolding for DB-side scripts
2026-06-26 10b275a Add pipeline walkthrough doc for curator onboarding
2026-06-26 abb08f6 Refactor PROJECT_STATUS.md for readability and maintainability
2026-06-26         SQL schema scripts fully written: all 6 schema files, docs/database_schema.md,
                   scripts/sql/README.md, handoffs/db_setup_handoff.md. Fixed USE NARWC → USE NARWCDB
                   across all non-schema scripts. Fixed BLOCK check bug in check_fk_integrity.sql.
```

---

## 6. Deferred / future work

- **Phase B pattern overrides** (`fileid_pattern` glob matching) — allows a single override entry to suppress a warning across multiple surveys matching a pattern; extension point stubbed in `SurveyValidator.buildMatcherList()`; defer until real curator use surfaces the need
- **GUI integration with override workflow** — Curator-friendly interface over the current CSV-based override mechanism; post-August
- **Curator-friendly bypass UX** — simpler interface for the curator over the existing override/ingestion machinery; post-August
- **NEAQFormat parser and new-survey ingestion pathway** — Phase 2b; `NEAQFormat.m` is currently a stub
- **Manual correction tool** (`apply_manual_correction.m`) — interactive tool for Bob's one-off data corrections; post-August
- **Historical SAS bulk corrections documentation** (`docs/historical_corrections.md`) — inventory what the PRG/DBF files in `scripts/sas/` historically did; out of scope to port
- **Live SQL Server transaction verification** — must verify `beginTransaction` / `commit` / `rollback` behavior with the JDBC driver before the next production migration run
- **Codetag cleanup pass** — review and fix FIXME/TODO comments throughout `src/` and `scripts/`; post-August

For the current TODO/FIXME/NOTE inventory, run:
```
grep -rn 'TODO\|FIXME\|NOTE' src/ scripts/ tests/ --include='*.m'
```

---

## 7. Open questions

- **`required_fields.m` accuracy**: `default_config()` lists `DDSOURCE, EVENTNO, FILEID, IDSOURCE, YEAR`; central config (`get_config`) lists `LAT_DD, LONG_DD, YEAR, MONTH, DAY`. Neither is confirmed against the database schema NOT NULL constraints. Blocks confidence in the required-field validation rule.
- **`SurveyValidator` config split**: Resolved. `load_config('migration')` returns permissive thresholds for the legacy migration; `load_config()` returns strict defaults for routine ingestion. Override CSV path comes from the batch config. `validation_config.m` deleted.
- **`visibility_allow_negative` split**: `BatchUploader` sets this to `false` (strict) by default, `true` only in `LegacyMode`. The global `get_config` default remains `true` for backwards compatibility. Callers that construct `SurveyValidator` directly still get the permissive value.
- **`temportal_rules.m` filename typo**: Will cause issues on case-sensitive filesystems; rename pending.
- **ANHEAD=19 intent**: README says "ANHEAD = 19 is a valid error" — ambiguous. Clarify before adding to lookup table.
- **Live SQL Server transaction semantics**: `beginTransaction` / `commit` / `rollback` verified only with Mac-side mock. Production behavior with the JDBC driver in use is unconfirmed. Blocks confidence in the transaction-safe overwrite for production migration runs.

---

## 8. Reference

### 8.1 Architecture and design decisions

**Validator thresholds are data-driven.** NUMBER and NUMCALF thresholds for group-size warnings cascade: SPECCODE.typical_max_group → TAXCODE.typical_max_group → config global default (1000 / 100). Curators adjust thresholds by editing `data/tables/SPECCODE.csv` or `TAXCODE.csv` and running `push_lookup_tables.m` — no MATLAB code change needed.

**Warning override philosophy.** Validation warnings block upload unless explicitly acknowledged. Acknowledgements are stored in `config/overrides/<batch>_overrides.csv` (version-controlled), keyed by `(fileid, eventno, field, rule_id)`. A per-row entry suppresses exactly one warning instance. A per-survey entry (empty `eventno`) suppresses a `(fileid, field, rule_id)` combination across the entire survey. The `AllowWarnings = true` flag is preserved as an emergency escape valve but is not the intended workflow. Curator workflow documented in `docs/warning_overrides.md`.

**Data correction philosophy.** Preserve what was originally recorded; do not silently transform data. Manual corrections are opt-in, audited, and tracked via `overrides.csv` or an explicit correction script. Speed and climb-rate threshold violations are warnings only (data recorded; threshold is advisory). The migration does not clean data in flight — it validates and rejects, forcing explicit correction decisions.

**Package layout target.** The intended layout before the August handoff: `+ingestion/` for parsers and `SurveyExtractor` (rename from `+io/`); `+db/` for writes including `BatchUploader` and a new single-survey `Uploader`; `+validation/` and `+processing/` unchanged. Rationale: align package names with data-flow stages (read → validate → process → write) so Curator can navigate the codebase without prior context.

### 8.2 Known bugs

**BLOCK column type varies across surveys** (latent — not surfaced by current tests).

When two survey tables loaded with plain `readtable` are combined with `vertcat`, MATLAB may throw "Cannot concatenate the table variable 'BLOCK' because it is a cell in one table and a non-cell in another." Cause: `readtable` without explicit import options infers column type per file. Files with only empty BLOCK values yield `double` (all NaN); files with alphanumeric codes yield `cell` (R2020b) or `string` (R2021a+). `StandardFormat` uses `delimitedTextImportOptions` to enforce types but any caller that bypasses the parser inherits this behavior.

Mitigation (2026-06-24): `buildCombined` helper in `test_characterization_extractor.m` detects any variable whose class diverges across input tables and coerces to cell-of-char before `vertcat`. The underlying `StandardFormat` type-enforcement gap is still open; address when adding a multi-file parser characterization test.

### 8.3 Historical: refactor branch progress

The major structural moves completed on the `refactor` branch:

**BatchConverter → BatchUploader (2026-06-24).** `src/+migration/BatchConverter.m` relocated to `src/+narwc/+ingestion/BatchUploader.m`. Class renamed to `narwc.ingestion.BatchUploader`. Constructor gains `TableName` (default `'Master'`) and `LegacyMode` (default `false`) options. `LegacyMode = true` sets `visibility_allow_negative = true` in the validator config. `step2_upload_surveys.m` updated to pass `'LegacyMode', true`.

**SurveyExtractor relocation (2026-06-24).** `src/+migration/SurveyExtractor.m` relocated to `src/+narwc/+ingestion/SurveyExtractor.m`. All call sites in scripts and tests updated; `git grep migration.SurveyExtractor` returns zero hits.

**Transaction-safe overwrite (2026-06-24).** `BatchUploader.uploadSurvey()` now wraps delete + insert in a database transaction. `beginTransaction()` / `commit()` / `rollback()` methods added to `narwc.db.Connection`. Prior `AutoCommit` state saved and restored. If the driver does not support transactions, a warning is logged and the operation proceeds non-atomically. Four characterization tests in `test_characterization_batch.m` verify control flow. **Live DB verification still required.**

**Warning override system (2026-06-25).** `data/overrides.csv` introduced. `ErrorCollector` stores `rule_id` and `eventno` on every entry. All 9 rule modules emit stable `rule_id` values. `SurveyValidator` loads overrides at construction and demotes matched warnings to `info`. `_errors.log` and `_run_summary.csv` both append across runs.

**Per-survey override mode (2026-06-25).** Empty `eventno` in `overrides.csv` acknowledges all warnings of a `(fileid, field, rule_id)` combination across an entire survey. Results expose `warnings_acknowledged_per_row` and `warnings_acknowledged_per_survey`.

### 8.4 Open validation/code tasks

Items surfaced during migration that require code or config changes (not yet implemented):

| Task | Notes |
|------|-------|
| Opportunistic fields (DAY/MONTH/TIME) → warning | `required_fields.m` raises error; should be warning for opportunistic sightings |
| ANHEAD > 22 → NaN | Needs a new fix in `apply_known_fixes.m` (or post-upload SQL); threshold from field manual |
| Check year/month/day matches FILEID | New validation rule; FILEID encodes the survey date — mismatch indicates data-entry error |
| f403158: GLARER=7 → 1 | One-off correction; add to `apply_known_fixes.m` or override CSV |
| o105921: PLATFORM=164 → 900 | Unknown platform code; 900 is the "other/unknown" sentinel; confirm with Bob |
| o112971: DDSOURCE unknown | May be resolved by copying IDSOURCE to DDSOURCE; confirm with Bob |
| o121911: CONFIDNC row 444 = 90 → 0 | Invalid code; 0 is the correct value |
| o123921: EVENT 159 TIME=003716/DAY=11; EVENT 211 TIME=001240/DAY=26; EVENT 212 TIME=005201/DAY=26; EVENT 283 LONG_DD=-71.93525 (missing negative sign) | Four discrete corrections; add to override CSV or apply_known_fixes |

---

### 8.5 Lookup table audit

_Status as of 2026-06-23; refresh after lookup table updates land._

All entries below are absent from their respective CSVs. Adding them and running `scripts/setup/push_lookup_tables.m` is the prerequisite for resolving the majority of FK validation failures in the legacy data. Pending Bob confirmation on each entry.

| Table        | Missing entries                                                                                   |
| ------------ | ------------------------------------------------------------------------------------------------- |
| SPECCODE.csv | CV-C, CV-O, CV-P, CV-R (wind-farm construction vessels), ECOT (dolphin watching)                 |
| Behave.csv   | 73 (security zone patrol), 74 (pile-driving)                                                      |
| ANHEAD.csv   | 19 (intent unclear — clarify before adding), 20 (underway, course unknown)                        |
| Block.csv    | MB (Mass Bay — not in manual; confirm before adding)                                              |
| GLARE.csv    | 9 (legacy missing-value sentinel — add as valid code or null-ify existing 9 values in data)       |
| PLATFORM.csv | 70, 193, 194, 266, 268, 280, 325, 329, 330, 332, 573, 637, 644 (13 codes absent from PLATFORM.csv) |

Platform notes: 573 = towboat/similar; 637 = APEM Partenavia; 266 = Canadian Coast Guard; 193 = Mingan Island Cetacean Study; 280 = misc./unknown Canadian vessel; 325 = Fugro Explorer; 194 = Helen H; 268 = R/V Leeway Odyssey; 329/330/332/644/70 = MMO vessels around wind farm.

---

### 8.6 Survey-specific data observations

Known data quality issues in individual surveys. "Correction needed" items require explicit fix via `apply_known_fixes.m`, override CSV, or manual DB correction with Bob's approval.

| Survey     | Issue                                                                                                                   | Status / Action |
| ---------- | ----------------------------------------------------------------------------------------------------------------------- | --------------- |
| c018101    | BEHAV1 values may be placed in ANHEAD field                                                                             | Investigate |
| f011048    | BEHAV1 values may be placed in ANHEAD field                                                                             | Investigate |
| f203360    | BEHAV1 values may be placed in ANHEAD field                                                                             | Investigate |
| f403158    | GLARER=7 should be 1                                                                                                    | Needs correction (apply_known_fixes or override) |
| f607053    | BEHAV1 values may be placed in ANHEAD field                                                                             | Investigate |
| f608034    | BEHAV1 values may be placed in ANHEAD field                                                                             | Investigate |
| o105921    | PLATFORM=164 (unknown code); likely should be 900 (other/unknown)                                                       | Confirm with Bob |
| o112971    | DDSOURCE unknown; may be copied from IDSOURCE                                                                           | Confirm with Bob |
| o113921    | PLATFORM=266 = Canadian Coast Guard (add to lookup — see §8.5)                                                          | Lookup table gap |
| o117001    | Lat outside typical survey area and early year are both valid — opportunistic sighting                                  | Add override CSV entry |
| o118921    | Lat/lon outside typical area is valid                                                                                   | Add override CSV entry |
| o121911    | CONFIDNC row 444 = 90 (invalid); should be 0                                                                            | Needs correction |
| o123921    | EVENT 159: TIME=003716/DAY=11; EVENT 211: TIME=001240/DAY=26; EVENT 212: TIME=005201/DAY=26; EVENT 283: LONG_DD=-71.93525 (missing negative sign) | Four corrections needed |
| p3127214   | EVENT 540: LAT_DD=0, LONG_DD=0 (both missing in source data; printout shows interpolated 48.042/−63.714)               | Investigate — likely missing, not zero |
| p905169G   | Large survey with many comments; suspected data corruption                                                              | Needs manual review before migration |

---

## 9. Glossary

| Term                           | Definition                                                                                                                                                                               |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **NARWC**                      | North Atlantic Right Whale Consortium — the organization managing this sightings database                                                                                                |
| **NARW / RIWH**                | North Atlantic Right Whale; RIWH is the species code used in the database                                                                                                                |
| **FILEID**                     | Survey identifier — a short alphanumeric string (e.g., `F098027`) that groups all event rows from a single survey effort. First character typically indicates survey type (see below).   |
| **EVENTNO**                    | Sequential event number within a survey. Not globally unique; unique only within a FILEID.                                                                                               |
| **Master**                     | The primary SQL table into which all survey records are uploaded.                                                                                                                        |
| **SPECCODE**                   | 4-character species code (e.g., `RIWH`, `FIWH`, `HUWH`). Validated against `data/tables/SPECCODE.csv`.                                                                                  |
| **TAXCODE**                    | Taxonomic category code (numeric); validated against `data/tables/TAXCODE.csv`.                                                                                                          |
| **PLATFORM**                   | Numeric code identifying the vessel or aircraft used for the survey. Validated against `data/tables/PLATFORM.csv`.                                                                       |
| **BEHAV1–BEHAV15**             | Up to 15 behavior codes per event row. Validated against `data/tables/Behave.csv`.                                                                                                       |
| **ANHEAD**                     | Angle to the animal's head (1–8 compass points, or coded values). Not the same as `HEADING`.                                                                                             |
| **HEADING**                    | Direction of travel of the platform (degrees).                                                                                                                                           |
| **BEAUFORT**                   | Beaufort sea state scale (0–9 standard; 0–12 in full scale).                                                                                                                             |
| **DDSOURCE**                   | Position data source code (e.g., GPS, radar). FK to `DDSOURCE` lookup.                                                                                                                  |
| **IDSOURCE**                   | Identification source (how the sighting was identified). FK to `IDSOURCE` lookup.                                                                                                        |
| **IDREL**                      | Identification reliability code. FK to `IDREL` lookup.                                                                                                                                   |
| **CONFIDNC**                   | Confidence code for the sighting identification. FK to `Confidnc` lookup.                                                                                                                |
| **LEGNO / LEGTYPE / LEGSTAGE** | Survey leg number, type (e.g., on-effort, off-effort), and stage. FK to respective lookup tables.                                                                                        |
| **STRIP**                      | Strip transect identifier/flag. Values > 16 are considered invalid in the legacy data.                                                                                                   |
| **BLOCK**                      | Geographic survey block identifier (string). FK to `BLOCK` lookup.                                                                                                                       |
| **STRATUM**                    | Survey stratum identifier. FK to `STRATUM` lookup.                                                                                                                                       |
| **GLAREL / GLARER**            | Glare intensity on left and right sides of the trackline (0–3 valid; 9 is a legacy missing-value code).                                                                                  |
| **VISIBLTY**                   | Visibility in nautical miles. Negative values occur in legacy data (coded via `OLDVIZ` lookup table).                                                                                    |
| **SURFTEMP**                   | Sea surface temperature in °C.                                                                                                                                                           |
| **WX**                         | Weather code. FK to `WX` lookup.                                                                                                                                                         |
| **CLOUD**                      | Cloud cover in oktas (0–8). FK to `Cloud` lookup.                                                                                                                                        |
| **PHOTOS**                     | Whether photos were taken (1=No, 2=Yes slides/prints, 3=cine, 4=video, 5=multiple). FK to `PHOTOS` lookup.                                                                               |
| **NUMCALF**                    | Number of calves observed in the sighting group.                                                                                                                                         |
| **S_LAT / S_LONG / S_TIME**    | Starting latitude, longitude, and time for the event leg/trackline.                                                                                                                      |
| **ANGLEL / ANGLER**            | Angle to sighting left and right of the trackline.                                                                                                                                       |
| **Survey type prefixes**       | First character of FILEID encodes survey origin: `f` = aerial fixed-wing, `c` = aerial (CCS?), `o` = opportunistic, `p` = shipborne — based on README examples; not formally documented. |
| **Opportunistic sightings**    | Sightings not from systematic survey effort; Day/Month/Time fields may legitimately be missing. Should produce warnings, not errors.                                                     |
| **Bob**                        | Domain expert referenced in the README who is making manual data corrections to certain surveys.                                                                                         |
| **Curator**                    | Curator who will own the database and curation tools post-handoff (August 2026).                                                                                                         |
| **RUSS_24.CSV**                | The legacy flat-file CSV being migrated (hardcoded in `validate_csv_database_lines.m` and referenced in `run_full_migration.m`).                                                         |
