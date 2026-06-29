# Configuration System

The pipeline loads configuration from three layers, merged in order:

1. **Defaults** (`config/defaults/`) — version-controlled, baseline values for all settings
2. **Local** (`config/local/`) — gitignored, user-specific including credentials
3. **Batch** (`config/batches/`) — version-controlled, per-workflow overrides

## Setup

After cloning the repository:

1. Copy `config/local/db_config_local.m.template` to `config/local/db_config_local.m`
2. Edit `db_config_local.m` to add your database username and password
3. The file is gitignored and will not be committed

## Loading config in code

```matlab
config = load_config();              % defaults + local, no batch overrides
config = load_config('migration');   % adds migration batch overrides
```

## Available batches

- `migration` — permissive thresholds for legacy data import (year_min=1970,
  allows unknown lookup codes, points to migration_overrides.csv)

## Adding a new batch

1. Create `config/batches/<name>.m` returning a struct with override fields
2. Create `config/overrides/<name>_overrides.csv` for batch-specific warning overrides
3. Update this file to list the new batch

## Config struct sections

The merged config has three top-level sections:

| Section             | Description                                         |
|---------------------|-----------------------------------------------------|
| `config.db`         | Database connection settings (Type, Server, Port, …)|
| `config.validation` | Validator thresholds and override behavior           |
| `config.pipeline`   | Pipeline settings (chunk_size, logging, known_fixes)|

### config.db

| Field          | Default    | Description                               |
|----------------|------------|-------------------------------------------|
| `Type`         | `'MySQL'`  | Database driver type                      |
| `Server`       | `'localhost'` | Database host                          |
| `Port`         | `3306`     | Port number                               |
| `DatabaseName` | `'NARWCDB'` | Target database                          |
| `DataSource`   | `'NARWCDB_DSN'` | ODBC DSN (SQL Server)               |
| `Username`     | `''`       | Set in `local/db_config_local.m`          |
| `Password`     | `''`       | Set in `local/db_config_local.m`          |

### config.validation

| Field                                      | Default  | Notes                                      |
|--------------------------------------------|----------|--------------------------------------------|
| `datetime.year_min`                        | 1970     | Records below this year are errors         |
| `datetime.year_max`                        | now+1    |                                            |
| `datetime.year_warning`                    | 1980     | Records below this year trigger a warning  |
| `coordinates.lat_min/max`                  | -90/90   |                                            |
| `coordinates.study_area_lat_min/max`       | 20/55    | Warning if outside study area              |
| `coordinates.study_area_lon_min/max`       | -85/-40  |                                            |
| `species.thresholds.group_size_default`    | 100000   | Fallback when SPECCODE/TAXCODE have no threshold |
| `species.thresholds.calf_count_default`    | 100      |                                            |
| `environmental.visibility_allow_negative`  | false    | Set to true in `migration` batch (legacy data has negative visibility codes) |
| `warnings_become_errors`                   | false    |                                            |
| `allow_unknown_lookup_codes`               | false    | true in migration batch                    |
| `overrides.enabled`                        | true     |                                            |
| `overrides.csv_path`                       | `''`     | Set in batch config                        |

### config.pipeline

| Field                              | Default  | Description                               |
|------------------------------------|----------|-------------------------------------------|
| `chunk_size`                       | 10000    | Rows per processing chunk                 |
| `known_fixes.enabled`              | true     | Apply `apply_known_fixes.m` pre-validation |
| `logging.error_log_dir`            | `'logs/'`| Directory for log files                   |
| `logging.use_datetime_filenames`   | true     | Stamp log filenames with run start time   |
| `logging.level`                    | `'INFO'` | Logging verbosity                         |
| `format_definitions_path`          | `'config/format_definitions.json'` | Parser format map |
| `lookup_tables_dir`                | `'data/tables/'` | Lookup CSV directory            |
