# NARWC Database Project — Status

_Branch: refactor | Last updated: 2026-06-26_

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
│   ├── get_config.m            # Central config source (paths, validation params, DB settings)
│   ├── get_lookup_table.m      # Loads CSV lookup tables from data/tables/ by name
│   ├── db_config_template.m    # Copy to db_config.m and add credentials (gitignored)
│   ├── logging_config.m        # Stub — logging not yet configured
│   ├── validation_config.m     # DEAD CODE — intentionally throws; replaced by get_config
│   └── reload_config.m         # Clears cached config to force reload
│
├── src/
│   ├── +migration/             # Phase 1 leftovers — both files marked for deletion
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
│   ├── sql/                            # (planned)
│   └── setup/
│       ├── test_connection.m               # Quick DB connection test
│       └── update_lookup_tables.m          # Pushes local CSV lookup tables to DB
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
│   ├── overrides.csv                   # Version-controlled warning acknowledgements
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

- **Personal pipeline walkthrough** (Russ) — run the full migration end-to-end on a local copy to surface remaining blockers; not yet started
- **Lookup table updates** (Category A, 19 codes) — add missing platform codes (13), species codes (5), behavior codes (2), ANHEAD codes (2), BLOCK code (MB), GLARE code (9) to `data/tables/`; prerequisite for most remaining FK validation failures; pending Bob confirmation on each entry
- **ANHEAD lookup expansion** — clarify whether ANHEAD=19 is valid or a sentinel; add full 19-code compass rose (codes 0–22 minus gaps); requires domain expert input
- **`apply_known_fixes.m` side-script** (Category C) — mirrors Bob's SAS macro corrections to our copy of the legacy data; not yet started
- **Package layout refactor** — rename `+io/` → `+ingestion/` (parsers), move `BatchUploader` to `+db/`, extract single-survey `Uploader` from `BatchUploader`; pre-August handoff goal
- **SAS rule porting** — port SAS QC checks (`scripts/sas/Chk*.sas`) to MATLAB validation rules; TAXCODE-aware NUMBER thresholds first

---

## 5. Recent commits

```
2026-06-26 Refactor PROJECT_STATUS.md for readability and maintainability
2026-06-26 93c0c7e Vectorize behavioral_rules, fix formatErrorDetails EVENTNO, clean up smoke_validate
2026-06-25 7498bb6 Add smoke_validate script and synthetic volume fixture
2026-06-25 73381a1 Add per-survey override mode to acknowledgement system
2026-06-25 eea3002 Add per-warning override system to replace binary AllowWarnings toggle
2026-06-25 1fcd847 Merge branch 'refactor' of https://github.com/rshom/NARWC-DB into refactor
2026-06-25 bb6221a added sas scripts
2026-06-24 405084d Relocate SurveyExtractor to +narwc/+ingestion and add transaction-safe overwrite
2026-06-24 e8233bd Fix off-by-one in test_characterization_extractor row count expectations
2026-06-24 dc4aa4a Add test baseline: skip-if-no-DB, remove deleted-code tests, characterization tests
2026-06-24 1fc4ccd generated fixtures
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
- **`SurveyValidator` config split**: The right config structure for distinguishing legacy migration from ongoing curation is unresolved. `validation_config.m` is dead; the comments in `SurveyValidator.m` suggest a config-driven split was intended but not implemented.
- **`visibility_allow_negative` split**: `BatchUploader` sets this to `false` (strict) by default, `true` only in `LegacyMode`. The global `get_config` default remains `true` for backwards compatibility. Callers that construct `SurveyValidator` directly still get the permissive value.
- **`temportal_rules.m` filename typo**: Will cause issues on case-sensitive filesystems; rename pending.
- **ANHEAD=19 intent**: README says "ANHEAD = 19 is a valid error" — ambiguous. Clarify before adding to lookup table.
- **Live SQL Server transaction semantics**: `beginTransaction` / `commit` / `rollback` verified only with Mac-side mock. Production behavior with the JDBC driver in use is unconfirmed. Blocks confidence in the transaction-safe overwrite for production migration runs.

---

## 8. Reference

### 8.1 Architecture and design decisions

**Warning override philosophy.** Validation warnings block upload unless explicitly acknowledged. Acknowledgements are stored in `data/overrides.csv` (version-controlled), keyed by `(fileid, eventno, field, rule_id)`. A per-row entry suppresses exactly one warning instance. A per-survey entry (empty `eventno`) suppresses a `(fileid, field, rule_id)` combination across the entire survey. The `AllowWarnings = true` flag is preserved as an emergency escape valve but is not the intended workflow. Curator workflow documented in `docs/warning_overrides.md`.

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

### 8.4 Lookup table audit

_Status as of 2026-06-23; refresh after lookup table updates land._

**Nothing on the README's "to add" list is currently present in any lookup table.** All additions below remain missing.

| Table        | Missing entries                                                                                          |
| ------------ | -------------------------------------------------------------------------------------------------------- |
| SPECCODE.csv | CV-C, CV-O, CV-P, CV-R (wind-farm construction vessels), ECOT (dolphin watching)                        |
| Behave.csv   | 73 (security zone patrol), 74 (pile-driving)                                                             |
| ANHEAD.csv   | 19 (intent unclear — clarify before adding), 20 (underway, course unknown)                               |
| Block.csv    | MB (Mass Bay — "not in manual, add?")                                                                    |
| GLARE.csv    | 9 (legacy missing-value sentinel — add or null-ify existing values)                                      |
| PLATFORM.csv | 70, 193, 194, 266, 268, 280, 325, 329, 330, 332, 573, 637, 644 (all 13 absent from PLATFORM.csv)        |

Adding these codes and running `scripts/setup/update_lookup_tables.m` is the prerequisite for resolving the majority of FK validation failures in the legacy data.

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
