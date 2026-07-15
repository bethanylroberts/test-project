# NARWC Database Project

Northern Atlantic Right Whale Consortium aerial survey database management system.

**Status**: Phase 1 in progress — historical migration pipeline functional; lookup table gaps and per-survey corrections blocking full migration run.

## Quick Start

```matlab
% 1. Initialize project
startup

% 2. Configure database (one-time)
% Copy config/local/db_config_local.m.template → config/local/db_config_local.m
% and fill in your credentials.

% 3. Test connection
scripts/setup/test_connection

% 4. Use database
conn = narwc.db.Connection.create();
data = conn.fetch('SELECT TOP 10 * FROM Master');
conn.close();
```

## Requirements

- MATLAB R2020b or later
- Database Toolbox
- SQL Server, MySQL, or PostgreSQL

## Project Structure

```
NARWC-DB/
├── startup.m                       # Add paths, check toolboxes, create data dirs — run first
├── config/
│   ├── load_config.m               # Layered config: defaults < local < batch
│   ├── defaults/                   # Baseline values (db, validation, pipeline)
│   ├── local/                      # Gitignored — db_config_local.m with credentials
│   ├── batches/migration.m         # Permissive overrides for legacy migration run
│   └── overrides/migration_overrides.csv  # Per-warning acknowledgements
├── src/
│   ├── +migration/
│   │   └── apply_known_fixes.m     # Category C pre-validation corrections
│   └── +narwc/
│       ├── +ingestion/             # BatchUploader, SurveyExtractor
│       ├── +db/                    # Connection, FieldDefinitions
│       ├── +io/+parsers/           # StandardFormat, NEAQFormat (stub), ParserFactory
│       ├── +validation/            # SurveyValidator, ErrorCollector, +rules/
│       ├── +processing/            # SurveyProcessor, ChangeTracker, +steps/
│       └── +reports/               # ValidationReport, ProcessingReport, SummaryStatistics
├── scripts/
│   ├── migration/                  # Steps 0–3 + run_full_migration.m
│   ├── sql/                        # Schema, curation, verification, teardown scripts
│   └── setup/                      # test_connection, pull/push_lookup_tables
├── tests/                          # test_runner.m, fixtures/, unit/
├── lib/+logging/                   # Logging toolbox
├── data/                           # Runtime data (mostly gitignored)
│   └── tables/                     # Lookup table CSVs (committed)
├── docs/                           # Developer guide, config reference, override guide
└── ref/                            # NARWC Users Guide PDF and reference material
```

## Common Commands

```matlab
startup                             % Add all paths, check toolboxes, create data dirs
scripts/setup/test_connection       % Verify database connection

% Validation
validator = narwc.validation.SurveyValidator();
[is_valid, results] = validator.validate(data);

% Migration (run in order)
config = load_config('migration');
step1_extract_surveys(csv_file)
step2_upload_surveys('Config', config)
step3_validate_migration()

% Tests
test_runner()                       % Run all tests
test_runner('unit', 'Verbose', true) % Unit tests only, verbose
```

## Development Status

- [x] Phase 0: Project infrastructure, database connectivity
- [x] Phase 0: Validation framework (9 rule modules, override system)
- [x] Phase 0: Migration pipeline (extract → validate → upload, transaction-safe)
- [ ] Phase 1: Historical migration — pipeline ready; blocked on lookup table gaps and per-survey corrections
- [ ] Phase 2: New-survey ingestion (NEAQFormat parser, curator GUI)

See `PROJECT_STATUS.md` for the full active work list, open questions, and per-survey data issues.

## Known Data Issues

The legacy CSV contains a number of data quality issues that require curator decisions before or during migration. These are tracked in `PROJECT_STATUS.md §8.5` and fall into three categories:

- **Lookup table gaps** — missing SPECCODE, BEHAV, ANHEAD, PLATFORM, BLOCK, and GLARE codes; tracked in `PROJECT_STATUS.md §8.4`
- **Category C bulk corrections** — sentinel values (99), PHOTOS=0, STRIP>16 handled automatically by `apply_known_fixes.m`
- **Per-survey manual corrections** — specific event/field errors in individual surveys requiring curator or Bob sign-off; tracked in `PROJECT_STATUS.md §8.5`

## Documentation

- Configuration: `docs/configuration_reference.md`
- Validation rules and overrides: `docs/warning_overrides.md`
- Testing: `docs/testing_guide.md`
- Database schema: `docs/database_schema.md`
- Help: `help narwc`, `help narwc.db.Connection`

## Contact

russ.shomberg@marineacoustics.com

---
**Version**: 0.2.0 | **Last Updated**: 2026-06
