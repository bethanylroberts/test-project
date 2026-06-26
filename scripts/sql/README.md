# SQL Scripts

T-SQL scripts for the NARWC SQL Server database. All scripts target SQL Server and
use T-SQL syntax. They have only been tested on Windows; they are committed here for
review and version control.

**Credentials and connection strings are never embedded in these files.** All
connections are established externally (MATLAB Database Toolbox, SSMS, sqlcmd).

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `schema/` | Create database, Master table, lookup tables, indexes, FK constraints, and populate lookups |
| `teardown/` | Drop tables or truncate Master (development use only) |
| `verification/` | Row-count and integrity queries to confirm a clean migration |
| `curation/` | Day-to-day curator operations: delete survey, find duplicates, recent uploads |
| `migration/` | Post-upload data corrections that mirror MATLAB apply_known_fixes logic |

## Execution Order for Initial Setup

1. `schema/01_create_database.sql`
2. `schema/02_create_master_table.sql`
3. `schema/03_create_lookup_tables.sql`
4. `schema/04_create_indexes.sql`
5. `schema/05_add_foreign_keys.sql`
6. `schema/06_populate_lookup_tables.sql`

Steps 4 and 5 can be reordered (FKs first, indexes second) if desired, but the
listed order is recommended because FKs benefit from existing indexes on the
referenced columns (FILEID, SPECCODE, PLATFORM, etc.) for validation performance.

Run verification scripts after migration to confirm row counts and referential
integrity.

## Notes

- All schema/teardown scripts wrap mutations in transactions.
- File-path placeholders use `<FILL_IN>` markers — replace before running.
- Identifier casing matches `FieldDefinitions.m` exactly (`Master`, `FILEID`, `EVENTNO`).
