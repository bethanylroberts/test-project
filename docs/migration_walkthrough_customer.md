# NARWC-DB Migration Walkthrough — Fresh Machine to Live Database

**Audience:** Customer-facing demo walkthrough.
**Assumes:** A brand-new Windows machine — no MATLAB, no SQL Server, nothing installed yet.

---

## How this document is organized

Two demo speeds are shown side by side wherever they diverge:

| Track | What it runs | Why show it |
|---|---|---|
| **Sample track** | A small, hand-built 2-survey file made from the project's own test fixtures | Guaranteed to run start to finish cleanly. Use this for the live walkthrough. |
| **Full track** | The customer's actual legacy CSV export | The real migration. As of this writing it is **not** guaranteed to complete cleanly in one pass — see [Part 10](#part-10--honest-status-read-this-before-the-meeting) before promising a clean run live. |

Most setup steps (installing software, building the schema) are identical for both tracks and are shown once. The tracks only actually diverge starting at **Part 8, Step 1**.

---

## Prerequisites

- Windows 10/11 machine with administrator rights
- Internet access (installers are large — MATLAB alone is several GB)
- A MathWorks account with a MATLAB license that includes **Database Toolbox**
- ~10 GB free disk space
- The NARWC-DB project (via `git clone` or a zip export)
- For the full track: the customer's legacy CSV export

---

## Part 1 — Install MATLAB

1. Sign in to your MathWorks account and download the MATLAB installer for your license.
2. Run the installer. On the component-selection screen, make sure **Database Toolbox** is checked — it's required, not optional (`startup.m` checks for it and warns if missing).
3. Optional but useful: **Mapping Toolbox** and **Statistics and Machine Learning Toolbox**. Neither is required for the migration pipeline itself.
4. Finish the install and confirm MATLAB launches.

**Verify:** In the MATLAB command window:
```matlab
license('test', 'database_toolbox')
```
Should return `1`.

---

## Part 2 — Install SQL Server

1. Download **SQL Server 2019 or 2022** (Express edition is sufficient for a demo; Standard/Developer for production scale). Scripts in this repo are written for SQL Server 2014 Express and later.
2. Run the installer, choose **Basic** or **Custom** setup.
3. On the **Database Engine Configuration** screen, set **Authentication Mode to "Mixed Mode"** (SQL Server authentication + Windows authentication) and set a strong `sa` password. Mixed mode is what lets MATLAB connect with a SQL login rather than requiring Windows-integrated auth.
4. Note the **instance name** shown at the end of setup (default instance is just the machine name; a named instance looks like `MACHINENAME\SQLEXPRESS`).
5. Separately, download and install **SQL Server Management Studio (SSMS)** — it's not bundled with the engine installer anymore.

**Verify:** Open SSMS, connect to your instance using the `sa` login and password you set. You should see the standard system databases (`master`, `model`, `msdb`, `tempdb`).

---

## Part 3 — Install the ODBC Driver and create a DSN

MATLAB's Database Toolbox talks to SQL Server through an ODBC **Data Source Name (DSN)**, not a raw connection string — `narwc.db.Connection` calls `database(datasource, username, password)` for the `'sqlserver'` case, where `datasource` is the DSN name.

1. Download **ODBC Driver 17 or 18 for SQL Server** from Microsoft and install it.
2. Open **ODBC Data Source Administrator (64-bit)** (search Start menu for "ODBC").
3. Go to the **System DSN** tab (not User DSN — makes the source visible regardless of which account runs MATLAB) → **Add** → select the ODBC Driver for SQL Server you just installed.
4. Configure it:
   - **Name:** `NARWCDB_DSN` (this must match `config.db.DataSource` in your local config — see Part 5)
   - **Server:** your instance name from Part 2
   - **Authentication:** "With SQL Server authentication using a login ID and password entered by the user" — use the `sa` login (or a dedicated login you create later) to test the DSN
   - **Change the default database to:** `NARWCDB` (you'll create this database in Part 6 — if it doesn't exist yet, you can leave the default database as `master` for now and revisit this after Part 6)
5. Click **Test Data Source** at the end — it should report success.

---

## Part 4 — Get the project and run startup

1. Clone or copy the NARWC-DB project to the machine, e.g. `C:\NARWC-DB`.
2. Open MATLAB, `cd` to that folder (or use `Set Path` / the address bar).
3. Run:
   ```matlab
   startup
   ```

**What to expect:** `startup.m` adds all project paths, checks for Database Toolbox, creates the `data/surveys/`, `reports/`, and `logs/` directory trees, and attempts a test database connection. **At this point the connection test will fail** — that's expected, since there's no local config yet:
```
✗ config/local/db_config_local.m not found
✗ Database connection failed: ...
```

---

## Part 5 — Configure database credentials

1. Copy the template:
   ```matlab
   copyfile('config/local/db_config_local.m.template', 'config/local/db_config_local.m')
   ```
2. Open `config/local/db_config_local.m` and fill it in:
   ```matlab
   function db = db_config_local()
       db.Type         = 'SQLServer';
       db.Server       = 'MACHINENAME\SQLEXPRESS';   % your instance from Part 2
       db.DatabaseName = 'NARWCDB';
       db.DataSource   = 'NARWCDB_DSN';               % must match the DSN name from Part 3
       db.Username     = 'sa';                        % or a dedicated login
       db.Password     = 'your_password';
   end
   ```
   This file is gitignored — it will never be committed. It's loaded automatically by `load_config()` and merged on top of `config/defaults/db_config_default.m` (whose `Type` defaults to MySQL — the local override is what switches the project to SQL Server).

**Don't test the connection yet** — the `NARWCDB` database doesn't exist until Part 6.

---

## Part 6 — Build the SQL Server schema (one-time, shared by both tracks)

All scripts are in `scripts/sql/schema/`, numbered in execution order, and are idempotent (safe to re-run). Run them from SSMS, connected to your instance.

| # | Script | What it does |
|---|---|---|
| 1 | `01_create_database.sql` | Creates the `NARWCDB` database (`SQL_Latin1_General_CP1_CI_AS` collation). **Run this one against `[master]`** — it doesn't exist yet to connect to directly. |
| 2 | `02_create_master_table.sql` | Creates `Master` — the survey-observation table, 56 columns (1 surrogate `Master_ID` PK + 55 survey fields). |
| 3 | `03_create_lookup_tables.sql` | Creates the 24 lookup tables (ANHEAD, Beaufort, Behave, PLATFORM, SPECCODE, …), each keyed on `Value`. |
| 4 | `04_create_indexes.sql` | Adds non-clustered indexes on `Master` for FILEID, YEAR, SPECCODE, LAT/LONG, PLATFORM. |
| 5 | `05_add_foreign_keys.sql` | Adds 35 FK constraints from `Master` columns to their lookup tables. |
| 6 | `06_populate_lookup_tables.sql` | Bulk-loads the lookup CSVs from `data/tables/`. **Needs one edit first — see below.** |

**Before running script 6:** open `06_populate_lookup_tables.sql` and replace every `<FILL_IN>` placeholder with the absolute path to `data/tables/` **as seen by the SQL Server service account** — not necessarily your own machine path if SQL Server runs as a different account or on a different host:
```sql
N'C:\NARWC-DB\data\tables\'
```
There's one `@data_root` variable near the top (used by the ANHEAD section) and several inline occurrences after that — search the file for `<FILL_IN>` to make sure you got them all. The SQL Server service account needs read permission on that folder.

**Run 01 → 06 in order.** Script 1 runs against `[master]`; scripts 2–6 each start with `USE NARWCDB;` so they switch context automatically once NARWCDB exists.

**Verify the schema and data loaded cleanly**, from `scripts/sql/verification/`:
```sql
-- Row counts (sanity check the lookup data loaded)
count_by_year.sql
count_by_fileid.sql
count_by_species.sql

-- Referential integrity — should return ZERO rows
check_fk_integrity.sql
```

---

## Part 7 — Verify the MATLAB ↔ SQL Server connection

Back in MATLAB:
```matlab
scripts/setup/test_connection
```
This runs a 7-part check: loads config, opens a connection, confirms it's open, runs `SELECT @@VERSION`, confirms the `Master` table exists (record count will be 0 — nothing's loaded yet), runs a sample query, and closes cleanly. If anything fails, `docs/troubleshooting_connection.md` has a dedicated SQL Server ODBC/DSN section.

If this all passes, the environment is fully set up and identical for both tracks from here on.

---

## Part 8 — Run the migration pipeline

The pipeline is always the same three steps — **extract → upload → validate** — run from the MATLAB command window. The two tracks differ only in what file you point Step 1 at, and in what to expect out of Steps 2–3.

### Step 1 — Extract surveys from the source CSV

**Sample track** — build a small, safe demo input first by concatenating two of the project's own test fixtures into one mini "legacy export" (2 surveys, ~160 data rows total):
```matlab
mkdir('data/surveys/raw/legacy');
fids = {'tests/fixtures/sample_data/oT06129.csv', 'tests/fixtures/sample_data/fT00157.csv'};
out  = fopen('data/surveys/raw/legacy/SAMPLE_LEGACY.CSV', 'w');
for i = 1:numel(fids)
    lines = readlines(fids{i});
    if i > 1, lines(1) = []; end   % drop the repeated header
    fprintf(out, '%s\n', lines{:});
end
fclose(out);

summary = step1_extract_surveys('data/surveys/raw/legacy/SAMPLE_LEGACY.CSV');
```

**Full track** — point Step 1 at the customer's real legacy export, placed (untouched) under `data/surveys/raw/legacy/`:
```matlab
summary = step1_extract_surveys('data/surveys/raw/legacy/<CUSTOMER_EXPORT>.CSV');
```
Recommended first: run `scripts/migration/validate_csv_database_lines.m` (a basic line-shape check — correct field count per row, splits obviously malformed lines into a `_INVALID.CSV`/error log) against the raw file before Step 1. It's a standalone script, not a function — open it and edit the `input_csv` / `valid_output` variables at the top before running it, then point Step 1 at its `_VALID.CSV` output instead of the raw file.

**Both tracks:** `step1_extract_surveys` splits the source CSV by `FILEID` into one file per survey under `data/surveys/pending/`, and mints a `batch_id` (`<timestamp>_legacy`) recorded in `data/surveys/batch_log.csv`. Note the `batch_id` printed at the end — Steps 2 and 3 need it.

### Step 2 — Upload to SQL Server

Identical command for both tracks — only the `batch_id` differs:
```matlab
stats = step2_upload_surveys('BatchId', summary.batch_id);
```
This validates each survey (9 rule modules) and uploads it to `Master` inside a transaction, using the permissive `'migration'` config profile (`config/batches/migration.m` — tuned for known legacy-data quirks) plus any acknowledgements already recorded in `config/overrides/migration_overrides.csv`.

- **Sample track:** expect a clean pass — 2 surveys uploaded, 0 rejected.
- **Full track:** expect some surveys to land in `data/surveys/rejected/` rather than `processed/`. This is the known, tracked state of the legacy data — see [Part 10](#part-10--honest-status-read-this-before-the-meeting).

### Step 3 — Validate the migration and generate a report

Also identical for both tracks:
```matlab
results = step3_validate_migration('BatchId', summary.batch_id);
```
Writes a report to `reports/batches/<batch_id>/report.md` (never overwritten by a later run — each batch gets its own folder) summarizing processed/rejected/pending counts and validation findings against the live database.

---

## Part 9 — Confirm results in SQL Server

Back in SSMS (or MATLAB):
```sql
SELECT COUNT(*) FROM Master;
SELECT TOP 10 FILEID, YEAR, EVENTNO FROM Master ORDER BY YEAR DESC;
```
or from MATLAB:
```matlab
conn = narwc.db.Connection.create();
data = conn.fetch('SELECT TOP 10 * FROM Master');
disp(data);
conn.close();
```
Re-running `scripts/sql/verification/check_fk_integrity.sql` should still return zero rows — confirming nothing that failed MATLAB-side validation slipped into the database.

---

## Part 10 — Honest status (read this before the meeting)

Worth setting expectations on before running the full track live:

- **The full legacy migration is not yet a guaranteed clean run.** Per `PROJECT_STATUS.md §8.4–§8.6`, it's currently blocked on missing lookup-table codes (19 known missing platform/species/behavior/ANHEAD/BLOCK/GLARE codes, pending confirmation) and a list of per-survey manual corrections. Some rows in the customer's real export will validate cleanly; others will land in `rejected/` for a reason the validation report explains — that's the pipeline working as intended, not a bug, but it's not a finished migration yet.
- **Live SQL Server transaction behavior hasn't been fully verified end-to-end** (`PROJECT_STATUS.md §7`) — the transaction-safe upload/rollback logic has only been exercised against a mock connection so far. This walkthrough may be the first time it runs against a real SQL Server instance start to finish.
- The **sample track is the safe thing to run live** in front of the customer — it's built from data that's already known to pass every rule. The full track is genuinely useful to show (it's the real thing), but frame it as "here's the pipeline working against your real data today" rather than "here's the finished migration."

---

## Quick troubleshooting reference

| Symptom | Likely cause / fix |
|---|---|
| `Undefined function 'load_config'` | `startup` wasn't run yet, or wasn't run from the project root. |
| `db_config_local.m not found` | Copy the `.template` file (Part 5). |
| `Failed to establish database connection` | Check DSN name matches `config.db.DataSource` exactly; check `Test Data Source` succeeds in ODBC Administrator; check `sa`/login credentials. |
| Schema scripts fail on script 6 | The `<FILL_IN>` path placeholder wasn't replaced, or the SQL Server service account can't read that path. |
| ODBC driver not listed in DSN setup | Confirm you're in the **64-bit** ODBC Data Source Administrator, and that "ODBC Driver 17/18 for SQL Server" installed successfully. |
| `Master table not found` (via `test_connection`) | Schema scripts 01–02 haven't been run yet against this database. |
| Step 2 rejects surveys you expected to pass | Check `reports/batches/<batch_id>/report.md` and the survey's file in `data/surveys/rejected/` — the reason is in there. Compare against `config/overrides/migration_overrides.csv` and `PROJECT_STATUS.md §8.5` for whether it's a known, already-triaged issue. |

---

## Reference

- `docs/troubleshooting_connection.md` — full connection troubleshooting, including ODBC/DSN detail
- `docs/pipeline_walkthrough.md` — deep-dive on validation + the warning-override workflow (per-row vs. per-survey)
- `docs/warning_overrides.md` — override CSV semantics and rule IDs
- `docs/database_schema.md` — full column list, types, FK design rationale
- `PROJECT_STATUS.md §8.4–§8.6` — current lookup-table gaps and per-survey corrections blocking a full clean migration
- `scripts/sql/README.md` — full SQL script reference
