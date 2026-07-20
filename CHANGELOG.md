# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Legacy migration pipeline: `SurveyExtractor`/`SurveyFileWriter` split the
  monolithic legacy CSV into per-survey files; `BatchUploader` validates and
  uploads them to SQL Server in transactions (rollback on failure); `step1`–`step3`
  scripts and `run_full_migration.m` drive the end-to-end run.
- Validation framework: `SurveyValidator` orchestrates 9 rule modules
  (coordinate, datetime, species, behavioral, environmental, beaufort,
  foreign-key, required-fields, photos/platform). `ErrorCollector` tracks
  errors/warnings/info with stable `rule_id`s.
- Warning override system: curators acknowledge expected warnings via a
  version-controlled CSV (`config/overrides/<batch>_overrides.csv`), matched
  per-row or per-survey. See `docs/warning_overrides.md`.
- Layered config system (`load_config`: defaults → local → batch overrides),
  replacing the older `get_config` cached singleton.
- Data-driven NUMBER/NUMCALF group-size thresholds: SPECCODE → TAXCODE →
  global-default cascade, adjustable via lookup-table CSVs with no code change.
- Routine (per-contributor-season) ingestion pipeline: `convert_contributor_batch`
  resolves a contributor's parser by name and splits its output by FILEID;
  `run_batch_upload` shares the connect→upload→stats→close logic with the
  migration pipeline's `step2_upload_surveys`.
- `NEAQFormat` parser (reference implementation for a header-based
  contributor format) and `TemplateFormat.m` as the starting point for new
  contributor parsers.
- SQL schema, verification, curation, and teardown scripts under `scripts/sql/`.

### Changed

- `ParserFactory` simplified to explicit `createByName()` selection; removed
  content-sniffing auto-detection and the unused `TabDeliminatedFormat`/`SurveyReader`
  classes.
- `apply_known_fixes.m` promoted to the primary Category C correction path
  (previously planned as SQL-only); the SQL version is now the post-upload
  fallback.

### Deprecated

### Removed

### Fixed

- Moved entire project to a fresh repository and set up a structure. The old
  repository had become very unorganized and contained a lot of old unused code.
- `species_rules`/`datetime_rules` errors now carry `EVENTNO`, matching what
  `behavioral_rules` warnings already did, so error output is traceable to a
  specific event row.

### Security