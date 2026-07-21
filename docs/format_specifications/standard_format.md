# Standard NARWC Survey Format

Reference: `src/+narwc/+io/+parsers/StandardFormat.m`.

## Overview

Comma-delimited CSV with 55 columns in a fixed legacy order (no header row
naming the columns — `StandardFormat` supplies the names itself from
`CSV_FIELD_ORDER`). This is the format of the historical monolithic legacy
CSV being migrated (Phase 1).

## File Format

- **Delimiter**: Comma (`,`)
- **Header Row**: None. Column names are not read from the file — they come
  from `StandardFormat.CSV_FIELD_ORDER`. Note: the parser's import options
  set `DataLines = [2, Inf]`, so the first line of the file is always
  skipped regardless of content.
- **Missing Values**: `NULL`, `.`, or empty string
- **Extra columns** beyond the 55 are ignored (`ExtraColumnsRule = 'ignore'`)

## Field Definitions

Column order and types below are read directly from `StandardFormat.CSV_FIELD_ORDER`
and `src/+narwc/+db/FieldDefinitions.m` (the canonical source of truth for
all 55 field names/types) — not hand-maintained, so re-generate this table
from those two files if either changes.

| Position | Field Name | Type | Description |
|----------|-----------|------|-------------|
| 1 | ALT | double | Altitude in meters |
| 2 | ANHEAD | double | Angle to head |
| 3 | BEAUFORT | double | Beaufort sea state (0-9) |
| 4 | BEHAV1 | double | Behavior code 1 |
| 5 | BEHAV2 | double | Behavior code 2 |
| 6 | BEHAV3 | double | Behavior code 3 |
| 7 | BEHAV4 | double | Behavior code 4 |
| 8 | BEHAV5 | double | Behavior code 5 |
| 9 | BEHAV6 | double | Behavior code 6 |
| 10 | BEHAV7 | double | Behavior code 7 |
| 11 | BEHAV8 | double | Behavior code 8 |
| 12 | BEHAV9 | double | Behavior code 9 |
| 13 | BEHAV10 | double | Behavior code 10 |
| 14 | BEHAV11 | double | Behavior code 11 |
| 15 | BEHAV12 | double | Behavior code 12 |
| 16 | BEHAV13 | double | Behavior code 13 |
| 17 | BEHAV14 | double | Behavior code 14 |
| 18 | BEHAV15 | double | Behavior code 15 |
| 19 | BLOCK | string | Survey block identifier |
| 20 | CLOUD | double | Cloud cover (0-10) |
| 21 | CONFIDNC | double | Confidence level |
| 22 | DAY | double | Day of month (1-31) |
| 23 | DDSOURCE | string | Data source code |
| 24 | EVENTNO | double | Event number |
| 25 | FILEID | string | File/Survey identifier |
| 26 | GLAREL | double | Glare level left |
| 27 | GLARER | double | Glare level right |
| 28 | HEADING | double | Ship/aircraft heading (degrees) |
| 29 | IDREL | double | ID reliability |
| 30 | IDSOURCE | string | ID source |
| 31 | LAT_DD | double | Latitude (decimal degrees) |
| 32 | LEGNO | double | Leg number |
| 33 | LEGSTAGE | double | Leg stage |
| 34 | LEGTYPE | double | Leg type |
| 35 | LONG_DD | double | Longitude (decimal degrees) |
| 36 | MONTH | double | Month (1-12) |
| 37 | NUMBER | double | Number of animals |
| 38 | NUMCALF | double | Number of calves |
| 39 | PHOTOS | double | Number of photos |
| 40 | PLATFORM | double | Platform code |
| 41 | S_LAT | double | Starting latitude |
| 42 | S_LONG | double | Starting longitude |
| 43 | S_TIME | double | Starting time |
| 44 | SIGHTNO | double | Sighting number |
| 45 | SPECCODE | string | Species code |
| 46 | STRATUM | string | Survey stratum |
| 47 | STRIP | double | Strip number |
| 48 | SURFTEMP | double | Surface temperature |
| 49 | TAXCODE | double | Taxonomic code |
| 50 | TIME | double | Time of observation (HHMMSS) |
| 51 | VISIBLTY | double | Visibility |
| 52 | WX | string | Weather code |
| 53 | YEAR | double | Year |
| 54 | ANGLEL | double | Angle left of trackline |
| 55 | ANGLER | double | Angle right of trackline |

## Example

```
244,NULL,4,...
244,NULL,4,...
```

(55 comma-separated values per row, in the position order above, no header
line — remember the parser always skips physical line 1.)

## Validation Notes

These are the actual configured defaults
(`config/defaults/validation_config_default.m`) as of this writing — always
verify against that file directly, since batch configs (e.g. `migration.m`)
can override them per run:

- `LAT_DD`/`LONG_DD` hard bounds (blocking error): ±90 / ±180 (physical
  validity only).
- `LAT_DD`/`LONG_DD` **survey-area** bounds (warning, not error): lat 20–55,
  lon -85 to -40 (`coordinate_rules.outside_survey_lat`/`outside_survey_lon`).
- `YEAR` hard bounds (blocking error): 1900 to current year + 1.
- `YEAR` **warning** threshold: below 1980 (`datetime_rules.year_too_old`).
- `SPECCODE` must match `data/tables/SPECCODE.csv` (see `species_rules.m`).
