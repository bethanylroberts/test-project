# SQL Scripts

T-SQL scripts for the NARWCDB SQL Server database. All scripts target SQL Server and
use T-SQL syntax. They have been developed for SQL Server 2014 Express and later;
they are committed here for review and version control.

**Credentials and connection strings are never embedded in these files.** All
connections are established externally (SSMS, sqlcmd, or MATLAB Database Toolbox).

## Subdirectories

| Directory       | Purpose                                                                       |
| --------------- | ----------------------------------------------------------------------------- |
| `schema/`       | Initial database and table setup — run once to build the schema               |
| `teardown/`     | Drop tables or truncate Master — development use only                         |
| `verification/` | Row-count and integrity queries to confirm a clean migration                  |
| `curation/`     | Day-to-day curator operations: delete survey, find duplicates, recent uploads |
| `migration/`    | Post-upload data corrections that mirror MATLAB `apply_known_fixes` logic     |

---

## Initial Setup: Execution Order

Run the `schema/` scripts in this order from a connection to the SQL Server instance:

| Step | File | What it does |
|------|------|--------------|
| 1 | `schema/01_create_database.sql` | Creates the NARWCDB database with `SQL_Latin1_General_CP1_CI_AS` collation. Connect to `[master]` first. |
| 2 | `schema/02_create_master_table.sql` | Creates the `Master` table with a surrogate `Master_ID` primary key and all 55 survey fields. |
| 3 | `schema/03_create_lookup_tables.sql` | Creates all 24 lookup tables (ANHEAD, Beaufort, Behave, …) with a primary key on each `Value` column. |
| 4 | `schema/04_create_indexes.sql` | Adds non-clustered indexes on `Master` for common query patterns (FILEID, YEAR, SPECCODE, LAT/LONG, PLATFORM). |
| 5 | `schema/05_add_foreign_keys.sql` | Adds 35 foreign key constraints from `Master` columns to their lookup tables. |
| 6 | `schema/06_populate_lookup_tables.sql` | Bulk-loads lookup table CSVs from `data/tables/`. **Requires a file-path placeholder to be filled in first — see the note below.** |

Steps 4 and 5 can be swapped (FKs before indexes) but the listed order is recommended:
FK validation scans the referenced table, and existing indexes make that faster.

All scripts are idempotent — re-running them skips objects that already exist.

### Before running step 6

Open `06_populate_lookup_tables.sql` and replace every `<FILL_IN>` with the absolute
Windows path to the `data/tables/` directory as seen by the SQL Server host process,
for example:

```
N'C:\NARWC-DB\data\tables\'
```

The SQL Server service account must have read permission on that directory.
The ANHEAD section uses a `@data_root` variable near the top of the file; the
remaining sections use inline path strings — replace all occurrences.

---

## Schema Design Notes

Full design rationale is in `docs/database_schema.md`. Brief summary:

- **Master.Master_ID** is a surrogate `int IDENTITY` primary key. It provides a
  stable row handle for curation without enforcing `(FILEID, EVENTNO)` uniqueness
  at the database level — duplicate detection is handled by MATLAB validation before
  upload.

- **Column types** follow `FieldDefinitions.m`: `int` for numeric coded fields
  (PLATFORM, CLOUD, IDREL, BEHAV1-15, LEGTYPE, LEGSTAGE, BEAUFORT, GLAREL/GLARER,
  ANHEAD, PHOTOS, STRIP, TAXCODE, CONFIDNC); `varchar` only for genuine string
  values (FILEID, SPECCODE, DDSOURCE, IDSOURCE, STRATUM, BLOCK, WX).

- **FK constraints** in step 5 are belt-and-suspenders. MATLAB validation catches
  invalid codes before upload. The constraints document schema intent for future
  maintainers and prevent manual data entry mistakes.

- **MONTH table** includes 16 rows: 12 calendar months (1–12) plus 4 season codes
  (13 = Winter, 14 = Spring, 15 = Summer, 16 = Fall). MATLAB validation accepts
  values 1–16 to match the FK constraint.

---

## Notes

- All schema and teardown scripts wrap mutations in `BEGIN TRANSACTION` / `COMMIT`
  with rollback on error.
- File-path placeholders use `<FILL_IN>` — search for this string before running.
- Identifier casing matches `FieldDefinitions.m` exactly (`Master`, `FILEID`,
  `EVENTNO`, etc.).
- The recovered SSMS export from 2025-06-16 (`handoffs/recovered_narwcdb_schema_2025-06-16.sql`)
  was the baseline for the column list. Types and constraints were corrected from
  that export's auto-generated artifacts.
