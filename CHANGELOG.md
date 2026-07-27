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
- Batch ledger (`data/surveys/batch_log.csv`, `narwc.ingestion.append_batch_log`/
  `read_batch_log`/`check_prior_conversion`): every `convert_contributor_batch`
  run mints a `batch_id` and logs it, plus later `upload_contributor_batch`/
  `validate_batch` runs against it, so it's always answerable which raw
  sources have already been converted and what the current batch is.
  `upload_contributor_batch`/`BatchUploader.uploadFromFolder` can scope a run
  to one batch's FILEIDs via `'BatchId'`.
- `scripts/ingestion/validate_batch.m`: generalized version of the old
  migration-only `step3_validate_migration.m` — validates and reports on any
  batch, any source, writing to `reports/batches/<batch_id>/` so reports never
  get silently overwritten by a later run.
- Five new contributor parsers, built from real raw files at `data/surveys/raw/`:
  `CCSAerialFormat`, `CCSVesselFormat`, `CCSOpportunisticFormat` (Center for
  Coastal Studies — one parser per platform schema), `NEAQVesselFormat` (New
  England Aquarium & Canadian Whale Institute joint vessel program), and
  `NEAQAerialFormat` (New England Aquarium aerial, "Wind Energy Area 2024").
  `StandardFormat.fileidFromFilename()`: shared helper deriving FILEID from a
  source filename's stem, since none of these raw files carry FILEID
  themselves (one raw file is one survey for these contributors).
- DDSOURCE/IDSOURCE/PLATFORM injection: `data/tables/contributor_defaults.csv`
  (contributor + subfolder → curator-assigned defaults, seeded from real
  cover-sheet data), `narwc.ingestion.lookup_contributor_defaults()`, and
  `narwc.ingestion.apply_field_overrides()` — these fields are never present
  in contributor raw files (confirmed curator/GSO-assigned per the NARWC
  manual), so `convert_contributor_batch` now resolves and injects them
  per-file, with an explicit `'FieldOverrides'` option to override the table.
  Three contributor/subfolder combinations are deliberately left unmapped
  pending curator confirmation — see `PROJECT_STATUS.md` §8.7.
- `required_fields.m` now checks two axes from the NARWC users guide instead
  of one flat field list: `universal` fields (every row) and `sighting_only`
  fields (required when SPECCODE is populated, and a new
  `required_fields.forbidden_on_non_sighting` warning when populated on a
  non-sighting row instead). See `docs/configuration_reference.md`.
- `StandardFormat.clearSpuriousSightno()`: blanks SIGHTNO on any row without
  a SPECCODE. Curator-confirmed (2026-07-27): SIGHTNO is auto-logged by the
  GPS/survey software on any marker-button press, not just animal sightings,
  and operators don't clean up the stray values afterward — confirmed
  against real CCS Aerial data, where most SIGHTNO-but-no-SPECCODE rows
  turned out to be effort/watch narration, not sightings. Without this,
  every stray marker press was misclassified as a sighting missing its
  species code by `required_fields.m`/`species_rules.m`. Called by every
  parser with a SIGHTNO field (all 5 new contributor parsers). See
  `data/README.md`.
- `StandardFormat.fillTaxcodeFromSpeccode()`: fills in TAXCODE from
  `data/tables/SPECCODE.csv` for any row with a recognized SPECCODE but no
  TAXCODE. TAXCODE is curator/GSO-assigned like DDSOURCE/IDSOURCE/PLATFORM
  (never supplied by contributor raw files) but, unlike those three, is a
  deterministic function of SPECCODE, so it needs a lookup rather than a
  curator-provided default. Confirmed against real data (2026-07-27): once
  `clearSpuriousSightno()` removed the marker-press noise, 100% of the
  remaining validation errors across all 5 new parsers were
  `species_rules.taxcode_missing_for_sighting`, all for known SPECCODEs
  with an existing TAXCODE in the lookup table. Called by every parser
  with a SPECCODE field (all 5 new contributor parsers), right after
  `clearSpuriousSightno()`. See `data/README.md`.

### Changed

- `ParserFactory` simplified to explicit `createByName()` selection; removed
  content-sniffing auto-detection and the unused `TabDeliminatedFormat`/`SurveyReader`
  classes.
- `apply_known_fixes.m` promoted to the primary Category C correction path
  (previously planned as SQL-only); the SQL version is now the post-upload
  fallback.
- Unified `data/raw/` (routine ingestion) and `data/legacy/` (one-time
  migration) into a single `data/surveys/{raw,pending,processed,rejected,skipped}`
  pipeline — the legacy monolith is just another raw source
  (`data/surveys/raw/legacy/`) that happens to need chunked reading given its
  size. `failed/` renamed to `rejected/` for consistency with the run-summary
  status column, which already used that name. `step1_extract_surveys.m`/
  `step2_upload_surveys.m`/`step3_validate_migration.m` are now thin wrappers
  over the shared `convert_contributor_batch.m`/`upload_contributor_batch.m`/
  `validate_batch.m`.
- `config.validation.required_fields` changed shape from a flat cell array to
  a struct (`.universal`/`.sighting_only`) — batch configs or callers setting
  this directly need updating; see `docs/configuration_reference.md`.
- `src/+narwc/+ingestion/convert_contributor_batch.m` (core) gained a 4th
  `file_overrides` argument (default `struct()`, backward-compatible);
  `scripts/ingestion/convert_contributor_batch.m` gained `'FieldOverrides'`/
  `'UseContributorDefaults'` options.

### Deprecated

### Removed

- `NEAQFormat.m` (and its test/fixture) — retired in favor of
  `NEAQVesselFormat`/`NEAQAerialFormat`, built from real files instead of the
  one confirmed lead available when the stub was written. See "Added" above.

### Fixed

- Moved entire project to a fresh repository and set up a structure. The old
  repository had become very unorganized and contained a lot of old unused code.
- `species_rules`/`datetime_rules` errors now carry `EVENTNO`, matching what
  `behavioral_rules` warnings already did, so error output is traceable to a
  specific event row.
- `config/format_definitions.json`'s `"legacy"` entry pointed at a
  `LegacyFormat` parser class that doesn't exist; corrected to `StandardFormat`,
  what's actually registered in `ParserFactory` and used for legacy CSVs.

### Security