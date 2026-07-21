# NARWCDB Validation Reference

This document is the canonical reference for every data quality rule enforced by the
NARWCDB system. Rules are enforced at two layers:

1. **Schema constraints** — enforced by the SQL Server database at insert/update time.
   These are absolute hard stops; the database will reject any row that violates them.

2. **MATLAB validation rules** — run before upload by `narwc.validation.SurveyValidator`.
   These catch problems in the incoming CSV/data that the schema alone cannot express
   (range checks, cross-field logic, survey-type-specific rules).

At the end of this document is a complete SAS-to-new-system mapping showing which
legacy SAS quality checks have been ported and which are still gaps.

---

## 1. Schema-Level Constraints

Schema constraints are enforced unconditionally by SQL Server. They require no MATLAB
code and cannot be bypassed by the uploader.

### 1.1 NOT NULL columns

Only two columns in the Master table are declared NOT NULL (aside from the surrogate
primary key):

| Column      | Constraint              | Notes                                                         |
| ----------- | ----------------------- | ------------------------------------------------------------- |
| `Master_ID` | `int NOT NULL IDENTITY` | Auto-generated surrogate PK; never supplied by submitter      |
| `FILEID`    | `varchar(20) NOT NULL`  | Every row must identify the survey file it belongs to         |
| `EVENTNO`   | `int NOT NULL`          | Every row must have a sequential event number within its file |

All other columns are nullable. Required-field checks beyond FILEID and EVENTNO are
handled by MATLAB validation rather than schema constraints, because requirements
are survey-type-dependent.

### 1.2 Primary key

```
CONSTRAINT PK_Master PRIMARY KEY CLUSTERED (Master_ID ASC)
```

`(FILEID, EVENTNO)` is **not** enforced as unique at the database level because
legitimate surveys can produce multiple rows sharing the same EVENTNO (e.g., a
position event and a sighting event recorded at the same moment). Duplicate detection
is handled by MATLAB validation before upload.

### 1.3 Data type constraints

The column types implicitly enforce range and format:

| Column     | Type            | Implicit constraint                       |
| ---------- | --------------- | ----------------------------------------- |
| `YEAR`     | `smallint`      | Integer; range −32,768 to 32,767          |
| `MONTH`    | `tinyint`       | Integer; range 0–255                      |
| `DAY`      | `tinyint`       | Integer; range 0–255                      |
| `TIME`     | `int`           | Integer; no fractional seconds            |
| `S_TIME`   | `int`           | Integer                                   |
| `LAT_DD`   | `decimal(10,5)` | Max 5 decimal places; rejects non-numeric |
| `LONG_DD`  | `decimal(10,5)` | Max 5 decimal places                      |
| `S_LAT`    | `decimal(10,5)` | Max 5 decimal places                      |
| `S_LONG`   | `decimal(10,5)` | Max 5 decimal places                      |
| `ALT`      | `decimal(8,2)`  | Numeric; rejects text                     |
| `HEADING`  | `smallint`      | Integer                                   |
| `LEGNO`    | `smallint`      | Integer                                   |
| `ANGLEL`   | `smallint`      | Integer                                   |
| `ANGLER`   | `smallint`      | Integer                                   |
| `VISIBLTY` | `decimal(8,2)`  | Numeric                                   |
| `SURFTEMP` | `decimal(8,2)`  | Numeric                                   |
| `NUMBER`   | `int`           | Integer; no fractional counts             |
| `NUMCALF`  | `int`           | Integer                                   |

### 1.4 Foreign key constraints

35 FK constraints link Master columns to lookup table primary keys. A row will be
rejected if it supplies a non-NULL value that does not exist in the referenced lookup
table. NULL values are always allowed (FK constraints do not apply to NULLs).

| Master column      | References        | Lookup description                                           |
| ------------------ | ----------------- | ------------------------------------------------------------ |
| `ANHEAD`           | `ANHEAD(Value)`   | Animal heading code (0–15 compass octants, plus codes 21/22) |
| `BEAUFORT`         | `Beaufort(Value)` | Beaufort wind/sea-state scale                                |
| `BEHAV1`–`BEHAV15` | `Behave(Value)`   | Behavior codes (15 FK constraints, one per slot)             |
| `BLOCK`            | `Block(Value)`    | CCS aerial survey block code                                 |
| `CLOUD`            | `Cloud(Value)`    | Cloud cover (oktas)                                          |
| `CONFIDNC`         | `Confidnc(Value)` | Group-size estimate confidence level                         |
| `DDSOURCE`         | `DDSOURCE(Value)` | Decimal-degree position source                               |
| `GLAREL`           | `GLARE(Value)`    | Sun glare severity, left side                                |
| `GLARER`           | `GLARE(Value)`    | Sun glare severity, right side                               |
| `IDREL`            | `IDREL(Value)`    | Species identification reliability                           |
| `IDSOURCE`         | `IDSOURCE(Value)` | Species identification source                                |
| `LEGSTAGE`         | `LEGSTAGE(Value)` | Leg stage within a survey leg                                |
| `LEGTYPE`          | `LEGTYPE(Value)`  | Leg type (transit, census, etc.)                             |
| `MONTH`            | `[MONTH](Value)`  | Calendar month (1–12) or season code (13–16)                 |
| `PHOTOS`           | `PHOTOS(Value)`   | Photo/video documentation codes                              |
| `PLATFORM`         | `PLATFORM(Value)` | Aircraft or vessel identifier                                |
| `SPECCODE`         | `SPECCODE(Value)` | Species code (up to 8 characters)                            |
| `STRATUM`          | `STRATUM(Value)`  | Survey stratum code                                          |
| `STRIP`            | `STRIP(Value)`    | Distance-interval strip number                               |
| `TAXCODE`          | `TAXCODE(Value)`  | Taxonomic group code                                         |
| `WX`               | `WX(Value)`       | Weather code                                                 |

**Note on BEAUFORT:** The `Beaufort` lookup table is the authority for which Beaufort
values are valid. The legacy SAS system used 0–7 with 9 as a "missing" sentinel; the
current lookup table definition should be consulted to confirm the exact valid set.

**Note on CLOUD:** The `Cloud` lookup table covers the valid cloud cover codes. There
is a known discrepancy between the legacy SAS system (which flagged values 5–8 as
invalid, using 0–4 and 9) and the current lookup table; domain expert review is needed
to resolve this before finalizing the Cloud.csv contents.

---

## 2. MATLAB Validation Rules

MATLAB validation runs before any data reaches the database. Each rule is a
function in `src/+narwc/+validation/+rules/` with signature
`fn(data,collector,config)`. Rules add findings to an `ErrorCollector` with
severity `error` or `warning`. Only records that pass all error-severity checks
are uploaded.

### 2.1 `required_fields.m` — Required field presence

**Rule ID prefix:** `required_fields`

Checks that a configurable list of fields is not NULL or empty. The list is
supplied via `config.required_fields`. The default list (from
`get_config('validation')`) is the authoritative set; the stub
`default_config()` inside the file is marked as inaccurate and should not be
relied upon.

| Check                                                  | Severity | Rule ID                          |
| ------------------------------------------------------ | -------- | -------------------------------- |
| Required column is entirely absent from the data table | error    | `required_fields.column_missing` |
| Required field value is NULL/NaN/empty for a row       | error    | `required_fields.value_missing`  |

**Notes:** The schema enforces NOT NULL on FILEID and EVENTNO directly. This rule
extends the NOT NULL check to additional fields that are logically required for a given
survey type (e.g., YEAR, MONTH, DAY, LAT_DD, LONG_DD) but are nullable in the schema
because requirements vary by survey type.

---

### 2.2 `datetime_rules.m` — Date and time validation

**Rule ID prefix:** `datetime_rules`

Validates YEAR, MONTH, DAY, and TIME fields individually and as a calendar date.

#### YEAR

| Check                         | Severity | Rule ID                            | Threshold                         |
| ----------------------------- | -------- | ---------------------------------- | --------------------------------- |
| YEAR outside configured range | error    | `datetime_rules.year_out_of_range` | Default: 1900 to current year + 1 (`validation.datetime.year_min/year_max`) |
| YEAR before warning threshold | warning  | `datetime_rules.year_too_old`      | Default: before 1980 (`validation.datetime.year_warning`) |

#### MONTH

| Check              | Severity | Rule ID                             | Threshold                                    |
| ------------------ | -------- | ----------------------------------- | -------------------------------------------- |
| MONTH outside 1–16 | error    | `datetime_rules.month_out_of_range` | 1–12 = calendar months; 13–16 = season codes |

**Note:** MONTH is also enforced by the FK constraint to the `[MONTH]` lookup table,
which covers values 1–16.

#### DAY

| Check            | Severity | Rule ID                           | Threshold             |
| ---------------- | -------- | --------------------------------- | --------------------- |
| DAY outside 1–31 | error    | `datetime_rules.day_out_of_range` | Simple numeric bounds |

#### TIME

| Check                       | Severity | Rule ID                               | Threshold                               |
| --------------------------- | -------- | ------------------------------------- | --------------------------------------- |
| TIME outside 0–239999       | error    | `datetime_rules.time_out_of_range`    | Must represent a valid HHMMSS integer   |
| TIME hours component ≥ 24   | error    | `datetime_rules.time_invalid_hours`   | Extracted as floor(TIME/10000)          |
| TIME minutes component ≥ 60 | error    | `datetime_rules.time_invalid_minutes` | Extracted as floor(mod(TIME,10000)/100) |
| TIME seconds component ≥ 60 | error    | `datetime_rules.time_invalid_seconds` | Extracted as mod(TIME,100)              |

#### Calendar date combination

| Check                                                   | Severity | Rule ID                                   | Notes                                                                                 |
| ------------------------------------------------------- | -------- | ----------------------------------------- | ------------------------------------------------------------------------------------- |
| YEAR/MONTH/DAY combination is not a valid calendar date | error    | `datetime_rules.invalid_date_combination` | Uses MATLAB `datetime()` to catch e.g. Feb 30; skipped for season-code months (13–16) |

---

### 2.3 `coordinate_rules.m` — Position validation

**Rule ID prefix:** `coordinate_rules`

Validates LAT_DD and LONG_DD (decimal degrees). The schema stores these as
`decimal(10,5)`, which enforces numeric type; this rule checks logical bounds.

#### Latitude

| Check                              | Severity | Rule ID                               | Threshold            |
| ---------------------------------- | -------- | ------------------------------------- | -------------------- |
| LAT_DD is missing                  | error    | `coordinate_rules.lat_missing`        | —                    |
| LAT_DD outside global range        | error    | `coordinate_rules.lat_out_of_range`   | Default: −90 to 90   |
| LAT_DD outside typical survey area | warning  | `coordinate_rules.outside_survey_lat` | Default: 20 to 55 °N (`validation.coordinates.study_area_lat_min/max`) |

#### Longitude

| Check                               | Severity | Rule ID                               | Threshold              |
| ----------------------------------- | -------- | ------------------------------------- | ---------------------- |
| LONG_DD is missing                  | error    | `coordinate_rules.lon_missing`        | —                      |
| LONG_DD outside global range        | error    | `coordinate_rules.lon_out_of_range`   | Default: −180 to 180   |
| LONG_DD outside typical survey area | warning  | `coordinate_rules.outside_survey_lon` | Default: −85 to −40 °W (`validation.coordinates.study_area_lon_min/max`) |

#### Coordinate pair consistency

| Check                                           | Severity | Rule ID                                     | Notes                               |
| ----------------------------------------------- | -------- | ------------------------------------------- | ----------------------------------- |
| One of LAT_DD/LONG_DD present but not the other | error    | `coordinate_rules.coordinate_pair_mismatch` | Both must be present or both absent |

---

### 2.4 `beaufort_rules.m` — Beaufort sea state

**Rule ID prefix:** `beaufort_rules`

Validates BEAUFORT against the configured set of valid values. The default valid set
is 0–12. Only non-NULL values are checked.

| Check                           | Severity | Rule ID                                | Threshold                                             |
| ------------------------------- | -------- | -------------------------------------- | ----------------------------------------------------- |
| BEAUFORT value not in valid set | error    | `beaufort_rules.beaufort_out_of_range` | Default: 0–12; configurable via `config.valid_values` |

**Note:** The schema FK constraint on BEAUFORT references the `Beaufort` lookup table
and provides a redundant hard stop. This MATLAB rule catches the problem before upload
with a more informative message.

---

### 2.5 `environmental_rules.m` — Environmental conditions

**Rule ID prefix:** `environmental_rules`

Validates VISIBLTY and SURFTEMP.

#### Visibility

| Check                   | Severity | Rule ID                                   | Threshold                                                |
| ----------------------- | -------- | ----------------------------------------- | -------------------------------------------------------- |
| VISIBLTY is negative    | error    | `environmental_rules.visibility_negative` | Applies when `config.visibility_allow_negative` is false |
| VISIBLTY unusually high | warning  | `environmental_rules.visibility_too_high` | Default: > 50 nautical miles                             |

#### Sea surface temperature

| Check                        | Severity | Rule ID                                 | Threshold        |
| ---------------------------- | -------- | --------------------------------------- | ---------------- |
| SURFTEMP below ocean minimum | warning  | `environmental_rules.surftemp_too_cold` | Default: < −2 °C |
| SURFTEMP above ocean maximum | warning  | `environmental_rules.surftemp_too_hot`  | Default: > 35 °C |

---

### 2.6 `foreign_key_rules.m` — Lookup-table validation

**Rule ID prefix:** `foreign_key_rules`

Validates 20 fields against their respective lookup tables loaded from `data/tables/`.
This is a general-purpose engine: it reads the lookup table, extracts the `Value`
column, and reports any non-NULL field values that are not in the valid set.

Fields and their lookup tables:

| Field      | Lookup table | Notes                                                    |
| ---------- | ------------ | -------------------------------------------------------- |
| `ANHEAD`   | `anhead`     | Animal heading direction code                            |
| `BLOCK`    | `block`      | CCS survey block; see note on missing code MB            |
| `CLOUD`    | `cloud`      | Cloud cover; see CLOUD scale discrepancy note above      |
| `CONFIDNC` | `confidnc`   | Group-size confidence (0–11)                             |
| `CONTRIB`  | `contrib`    | Contributing organization                                |
| `DDSOURCE` | `ddsource`   | Position source                                          |
| `DTYPE`    | `dtype`      | Record type (legacy reference table; not FK'd in schema) |
| `GLAREL`   | `glare`      | Left-side glare severity (0–3)                           |
| `GLARER`   | `glare`      | Right-side glare severity (0–3)                          |
| `IDREL`    | `idrel`      | Identification reliability                               |
| `IDSOURCE` | `idsource`   | Identification source                                    |
| `LEGGOOD`  | `leggood`    | Leg quality flag (legacy reference; not FK'd in schema)  |
| `LEGSTAGE` | `legstage`   | Leg stage code                                           |
| `LEGTYPE`  | `legtype`    | Leg type code                                            |
| `OLDVIZ`   | `oldviz`     | Legacy visibility code (not FK'd in schema)              |
| `PHOTOS`   | `photos`     | Photo/video documentation (1–5)                          |
| `PLATFORM` | `platform`   | Aircraft or vessel identifier                            |
| `STRATUM`  | `stratum`    | Survey stratum                                           |
| `STRIP`    | `strip`      | Distance-interval strip number                           |
| `WX`       | `wx`         | Weather code                                             |

For each field, the rule flags rows where the value is non-NULL and not present in
the lookup table.

**Rule ID pattern:** `foreign_key_rules.<fieldname>_invalid` (lower-cased field name)

---

### 2.7 `behavioral_rules.m` — Behavior code validation

**Rule ID prefix:** `behavioral_rules`

Validates BEHAV1–BEHAV15 codes against the `Behave.csv` lookup table and checks for
logical inconsistencies among recorded behaviors.

#### Code validity

| Check                          | Severity | Rule ID                                  | Notes                                       |
| ------------------------------ | -------- | ---------------------------------------- | ------------------------------------------- |
| BEHAVn value not in Behave.csv | error    | `behavioral_rules.invalid_behavior_code` | Applies to all 15 BEHAV slots independently |

**Note:** The schema FK constraints enforce the same rule at the database level for
all 15 slots (FK_Master_BEHAV1 through FK_Master_BEHAV15). The MATLAB check runs first
and provides row-level detail.

#### Behavior compatibility

| Check                                                         | Severity | Rule ID                                   | Notes                                                                         |
| ------------------------------------------------------------- | -------- | ----------------------------------------- | ----------------------------------------------------------------------------- |
| Dead/stranded behavior combined with active swimming behavior | error    | `behavioral_rules.incompatible_behaviors` | Configured via `config.dead_behaviors` and `config.active_swimming_behaviors` |
| Declared incompatible behavior pair both present              | error    | `behavioral_rules.incompatible_behaviors` | Configured via `config.incompatible_behavior_pairs`                           |

#### Taxcode-behavior compatibility

| Check                                            | Severity | Rule ID                                         | Notes                                                                                   |
| ------------------------------------------------ | -------- | ----------------------------------------------- | --------------------------------------------------------------------------------------- |
| Behavior code not valid for the recorded TAXCODE | warning  | `behavioral_rules.taxcode_behavior_restriction` | Driven by `config.taxcode_behavior_restrictions`; no restrictions configured by default |

#### Species-behavior compatibility

| Check                                               | Severity | Rule ID                                         | Notes                                                                                   |
| --------------------------------------------------- | -------- | ----------------------------------------------- | --------------------------------------------------------------------------------------- |
| Behavior code not typical for the recorded SPECCODE | warning  | `behavioral_rules.species_behavior_restriction` | Driven by `config.species_behavior_restrictions`; no restrictions configured by default |

#### Calf behavior consistency

| Check                                                        | Severity | Rule ID                                  | Notes                                                               |
| ------------------------------------------------------------ | -------- | ---------------------------------------- | ------------------------------------------------------------------- |
| Calf-associated behavior recorded but NUMCALF is 0 or absent | warning  | `behavioral_rules.calf_behavior_no_calf` | Configured via `config.calf_associated_behaviors`; empty by default |

---

### 2.8 `species_rules.m` — Species and sighting field validation

**Rule ID prefix:** `species_rules`

Validates SPECCODE, TAXCODE, NUMBER, NUMCALF, and cross-field consistency among them.

#### SPECCODE

| Check                                     | Severity | Rule ID                                       | Notes                                                             |
| ----------------------------------------- | -------- | --------------------------------------------- | ----------------------------------------------------------------- |
| SPECCODE has unexpected data type         | error    | `species_rules.speccode_wrong_type`           | Must be character/string                                          |
| SPECCODE exceeds 4 characters             | error    | `species_rules.speccode_too_long`             | Max 4 chars per domain standard                                   |
| SPECCODE missing on a sighting record     | error    | `species_rules.speccode_missing_for_sighting` | Only applies when `config.require_speccode_for_sightings` is true |
| SPECCODE not found in SPECCODE.csv lookup | error    | `species_rules.speccode_not_in_table`         | Requires `config.validate_speccode_lookup` = true                 |
| SPECCODE contains invalid characters      | error    | `species_rules.speccode_invalid_chars`        | Allowed: A–Z, a–z, 0–9, hyphen                                    |

**Note:** The schema FK on `SPECCODE` references `SPECCODE(Value)` as a hard stop.

#### TAXCODE

| Check                                   | Severity | Rule ID                                      | Notes                                                            |
| --------------------------------------- | -------- | -------------------------------------------- | ---------------------------------------------------------------- |
| TAXCODE value not in 0–9                | error    | `species_rules.taxcode_out_of_range`         | Valid codes per `config.valid_taxcodes` (default 0–9)            |
| TAXCODE missing on a sighting record    | error    | `species_rules.taxcode_missing_for_sighting` | Only applies when `config.require_taxcode_for_sightings` is true |
| TAXCODE not found in TAXCODE.csv lookup | warning  | `species_rules.taxcode_not_in_table`         | Softer check since 0–9 range is also enforced                    |

#### SPECCODE/TAXCODE cross-check

| Check                                                                           | Severity | Rule ID                                   | Notes                                     |
| ------------------------------------------------------------------------------- | -------- | ----------------------------------------- | ----------------------------------------- |
| TAXCODE does not match the TAXCODE associated with SPECCODE in the lookup table | error    | `species_rules.speccode_taxcode_mismatch` | Requires `TAXCODE` column in SPECCODE.csv |

#### NUMBER (group size)

| Check                               | Severity | Rule ID                                  | Notes                                  |
| ----------------------------------- | -------- | ---------------------------------------- | -------------------------------------- |
| NUMBER is negative                  | error    | `species_rules.number_negative`          | —                                      |
| NUMBER is 0 on a sighting record    | warning  | `species_rules.number_zero_for_sighting` | Sighting with no animals is suspicious |
| NUMBER exceeds threshold            | warning  | `species_rules.number_unusual`           | Data-driven SPECCODE → TAXCODE → global-default cascade (`typical_max_group`, default 1000); see `docs/validation_rules_guide.md`. Not a fixed number, and not a two-tier error/warning split — one warning-level check. |
| NUMBER is not an integer            | error    | `species_rules.number_not_integer`       | Fractional counts are not valid        |

#### NUMCALF (calf count)

| Check                                | Severity | Rule ID                               | Notes                                              |
| ------------------------------------ | -------- | ------------------------------------- | -------------------------------------------------- |
| NUMCALF is negative                  | error    | `species_rules.numcalf_negative`      | —                                                  |
| NUMCALF exceeds threshold            | warning  | `species_rules.numcalf_unusual`       | Same SPECCODE → TAXCODE → global-default cascade as NUMBER (`typical_max_calf`, default 100) |
| NUMCALF > 0 for a non-mammal taxcode | warning  | `species_rules.numcalf_non_mammal`    | Calves only valid for marine mammals (TAXCODE 1–4) |
| NUMCALF is not an integer            | error    | `species_rules.numcalf_not_integer`   | —                                                  |
| NUMCALF exceeds total NUMBER         | error    | `species_rules.numcalf_exceeds_total` | Calves cannot outnumber the group                  |
| NUMCALF exceeds half of NUMBER       | warning  | `species_rules.numcalf_exceeds_half`  | Unusually calf-heavy group                         |

#### Right whale specific

| Check                                  | Severity | Rule ID                                     | Notes                                      |
| -------------------------------------- | -------- | ------------------------------------------- | ------------------------------------------ |
| Right whale group size unusually large | warning  | `species_rules.right_whale_large_group`     | Applies to RIWH, NARW, SARW; default: > 50 |
| Right whale calf count unusually high  | warning  | `species_rules.right_whale_high_calf_count` | Default: > 5                               |

---

### 2.9 `platform_rules.m` — Platform code validation

**Rule ID prefix:** `platform_rules`

Validates PLATFORM against the `PLATFORM.csv` lookup table. Redundant with the schema
FK (FK_Master_PLATFORM) but catches the problem before upload with a descriptive
message listing the bad values.

| Check                                       | Severity | Rule ID                           |
| ------------------------------------------- | -------- | --------------------------------- |
| PLATFORM value not in PLATFORM lookup table | error    | `platform_rules.platform_invalid` |

---

### 2.10 `photos_rules.m` — Photo documentation validation

**Rule ID prefix:** `photos_rules`

Validates PHOTOS against the `photos` lookup table (values 1–5). Redundant with the
schema FK (FK_Master_PHOTOS).

| Check                                   | Severity | Rule ID                       |
| --------------------------------------- | -------- | ----------------------------- |
| PHOTOS value not in photos lookup table | error    | `photos_rules.photos_invalid` |

---

### 2.11 `temportal_rules.m` — Temporal sequence rules (stub)

This file exists but contains no implemented checks. It is a placeholder for
row-to-row time-sequence checks (times out of order, gaps between position records)
that have not yet been implemented.

---

## 3. SAS Legacy Coverage Mapping

The legacy SAS quality-control system comprised 11 check files. The table below lists
every check from each SAS file and maps it to the corresponding enforcement in the
new system (schema constraint, MATLAB rule, or gap).

Legend: **Schema** = enforced by SQL Server FK or NOT NULL constraint; **MATLAB** =
enforced by a MATLAB validation rule; **Gap** = not yet implemented.

---

### ChkBasic.sas — Universal checks (all survey types)

| SAS check                                                       | New system coverage                                                                                                                                                                            |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| FILEID missing                                                  | **Schema** — `FILEID NOT NULL`                                                                                                                                                                 |
| EVENTNO missing                                                 | **Schema** — `EVENTNO NOT NULL`                                                                                                                                                                |
| YEAR missing                                                    | **MATLAB** — `required_fields` (in configured field list)                                                                                                                                      |
| YEAR/FILEID cross-consistency (derives year from FILEID prefix) | **Gap** — not implemented                                                                                                                                                                      |
| MONTH missing                                                   | **MATLAB** — `required_fields`; also **Schema** FK to MONTH table                                                                                                                              |
| LATDEG/LATMIN missing (degree+minute form)                      | **MATLAB** — `coordinate_rules` checks LAT_DD missing; degree/minute components not validated separately                                                                                       |
| LONGDEG/LONGMIN missing (degree+minute form)                    | Same as above for LONG_DD                                                                                                                                                                      |
| BEAUFORT > 7 (9 = missing sentinel)                             | **Partial gap** — `beaufort_rules` validates against Beaufort lookup; SAS treated 8 as an error and 9 as a "missing" sentinel; current MATLAB/schema allow 8 and do not interpret 9 as missing |
| CLOUD out of range (SAS valid: 0–4 and 9)                       | **Schema** FK to Cloud table (pending CLOUD scale resolution); `foreign_key_rules` checks against Cloud.csv                                                                                    |
| DAY out of range (0, > 31, calendar invalids)                   | **MATLAB** — `datetime_rules.day_out_of_range` (bounds) + `datetime_rules.invalid_date_combination` (calendar)                                                                                 |
| HEADING > 359                                                   | **Gap** — not implemented in any MATLAB rule                                                                                                                                                   |
| LATDEG out of range (25–48)                                     | **MATLAB** — `coordinate_rules.outside_survey_lat` (warning) checks 20–55; exact SAS bounds (25–48) differ                                                                                     |
| LATMIN ≥ 60                                                     | **Gap** — MATLAB validates only decimal-degree LAT_DD; minute components not checked                                                                                                           |
| LONGDEG out of range (58–81)                                    | **MATLAB** — `coordinate_rules.outside_survey_lon` (warning) checks −85 to −40; exact SAS bounds differ                                                                                        |
| LONGMIN ≥ 60                                                    | **Gap** — same as LATMIN                                                                                                                                                                       |
| MONTH > 12                                                      | **MATLAB** — `datetime_rules.month_out_of_range` (1–16); **Schema** FK to MONTH table                                                                                                          |
| SURFTEMP out of range (−2 to 35 °C)                             | **MATLAB** — `environmental_rules` warnings at −2/35 °C (matches SAS thresholds)                                                                                                               |
| TIME missing except for opportunistic surveys                   | **Gap** — `datetime_rules` checks TIME format but does not implement the FILEID-based opportunistic exception                                                                                  |
| TIME ≥ 240000 or < 0                                            | **MATLAB** — `datetime_rules.time_out_of_range`                                                                                                                                                |
| TIME minutes ≥ 60                                               | **MATLAB** — `datetime_rules.time_invalid_minutes`                                                                                                                                             |
| TIME seconds ≥ 60                                               | **MATLAB** — `datetime_rules.time_invalid_seconds`                                                                                                                                             |
| WX invalid code                                                 | **Schema** FK to WX table; **MATLAB** — `foreign_key_rules.wx_invalid`                                                                                                                         |
| YEAR < 1990 or > 2018                                           | **MATLAB** — `datetime_rules.year_out_of_range` (range 1900 to current+1); `datetime_rules.year_too_old` warning before 1980; upper bound is now dynamic rather than 2018                      |

---

### ChkBehav.sas — Behavior code validation

| SAS check                                                                            | New system coverage                                                                                                                                                                                  |
| ------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Discontinued behavior code in BEHAV1–15 (codes 27, 29, 46, 47, 48, 64, 66)           | **Schema** FK to Behave table + **MATLAB** `behavioral_rules.invalid_behavior_code` — catches them if they are absent from Behave.csv; the "discontinued" vs. "unknown" distinction is not preserved |
| Unknown behavior code in BEHAV1–10, BEHAV12–15 (codes 31–33, 39, 49, 56, 57, 96, 99) | Same as above                                                                                                                                                                                        |
| Unknown code in BEHAV11 only (additionally 71–75)                                    | **Gap** — the BEHAV11-specific restriction on codes 71–75 is not implemented                                                                                                                         |

---

### ChkCCSA.sas — CCS aerial survey checks

| SAS check                                                                                                                      | New system coverage                                                                                                                      |
| ------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- |
| GLARE > 3                                                                                                                      | **Schema** FK to GLARE table; **MATLAB** `foreign_key_rules.glarel_invalid` / `foreign_key_rules.glarer_invalid`                         |
| BLOCK code invalid                                                                                                             | **Schema** FK to Block table; **MATLAB** `foreign_key_rules.block_invalid`                                                               |
| PORTOBS/STAROBS/SIGHTOBS observer codes                                                                                        | **Gap** — these fields are not in the 55-column MATLAB schema                                                                            |
| STRATUM code invalid                                                                                                           | **Schema** FK to STRATUM table; **MATLAB** `foreign_key_rules.stratum_invalid`                                                           |
| STRATUM on cross-leg or transit leg                                                                                            | **Gap** — survey-type cross-field check not implemented                                                                                  |
| STRIP missing when required                                                                                                    | **Gap** — conditional required-field check not implemented                                                                               |
| STRIP out of range (> 16, = 0, > 14 for non-626)                                                                               | **Schema** FK to STRIP table; **MATLAB** `foreign_key_rules.strip_invalid`; platform-specific upper bound (> 14 for non-626) is a gap    |
| Time format (invalid minutes or seconds)                                                                                       | **MATLAB** — `datetime_rules.time_invalid_minutes` / `datetime_rules.time_invalid_seconds`                                               |
| Times out of order (row-to-row)                                                                                                | **Gap** — `temportal_rules.m` is a stub; not implemented                                                                                 |
| > 2 minutes without a position                                                                                                 | **Gap** — not implemented                                                                                                                |
| Duplicate location and time                                                                                                    | **Gap** — not implemented                                                                                                                |
| Same location, different time                                                                                                  | **Gap** — not implemented                                                                                                                |
| Speed too high (> 225 knots)                                                                                                   | **Gap** — not implemented                                                                                                                |
| Speed too low (0.5–50 knots)                                                                                                   | **Gap** — not implemented                                                                                                                |
| ALT missing                                                                                                                    | **Gap** — not in configured required fields for aerial surveys                                                                           |
| ALT out of range (60–750 ft)                                                                                                   | **Gap** — not implemented                                                                                                                |
| ALT = 999 (bogus sentinel)                                                                                                     | **Gap** — not implemented                                                                                                                |
| Climb rate by platform                                                                                                         | **Gap** — not implemented                                                                                                                |
| Descent rate by platform                                                                                                       | **Gap** — not implemented                                                                                                                |
| Required fields missing (DAY, TIME, LEGTYPE, BEAUFORT, CLOUD, WX, VISIBLTY, HEADING, LEGSTAGE, LEGNO, STRATUM, GLAREL, GLARER) | **Partial** — `required_fields` checks what is in the configured list; not all of these are currently configured as required             |
| LEGTYPE out of range (valid: 1–4, 7)                                                                                           | **Schema** FK to LEGTYPE table; **MATLAB** `foreign_key_rules.legtype_invalid`; survey-type range restriction (CCS only 1–4, 7) is a gap |
| LEGTYPE=4 without preceding LEGSTAGE=3                                                                                         | **Gap** — state machine check not implemented                                                                                            |
| LEGSTAGE sequence state machine                                                                                                | **Gap** — not implemented                                                                                                                |
| Last record LEGSTAGE ≠ 5                                                                                                       | **Gap** — not implemented                                                                                                                |
| PLATFORM out of range (626–649)                                                                                                | **Schema** FK to PLATFORM table; **MATLAB** `platform_rules`; survey-type range check (626–649 for CCS) is a gap                         |
| LEGSTAGE=7 with PHOTOS=1                                                                                                       | **Gap** — not implemented                                                                                                                |
| SIGHTNO ≥ 300 but LEGSTAGE ≠ 7                                                                                                 | **Gap** — not implemented                                                                                                                |
| SIGHTNO ≥ 300 but PHOTOS=1                                                                                                     | **Gap** — not implemented                                                                                                                |

---

### ChkDair.sas — Daily aerial survey checks

All checks from ChkCCSA apply (see above), plus:

| SAS check                         | New system coverage                                          |
| --------------------------------- | ------------------------------------------------------------ |
| > 10 minutes without a position   | **Gap** — not implemented (different threshold than ChkCCSA) |
| LEGSTAGE=7 extended state machine | **Gap** — not implemented                                    |
| LEG STAGE on non-census leg       | **Gap** — not implemented                                    |

---

### ChkDupes.sas — Duplicate EVENTNO field consistency

| SAS check                                                                                                                                       | New system coverage                                                                                                                |
| ----------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Repeated EVENTNO within a file where metadata fields differ across rows (TIME, MONTH, DAY, YEAR, coordinates, leg fields, environmental fields) | **Gap** — not implemented. `remove_duplicates.m` is marked do-not-use; no rule checks for metadata-inconsistent duplicate ENTRYNOs |

---

### CHKDUPE2.sas — Duplicate SIGHTNO detection

| SAS check                                                              | New system coverage       |
| ---------------------------------------------------------------------- | ------------------------- |
| Duplicate SIGHTNO values within the same file (consecutive same value) | **Gap** — not implemented |

---

### ChkIShip.sas — Intermittent shipborne survey checks

| SAS check                                               | New system coverage                                                                           |
| ------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| MONTH/DAY change across consecutive records             | **Gap** — not implemented                                                                     |
| Time format (minutes, seconds out of range)             | **MATLAB** — `datetime_rules.time_invalid_minutes` / `datetime_rules.time_invalid_seconds`    |
| Times out of order (cross-day aware)                    | **Gap** — not implemented                                                                     |
| ALT > 0 for ship survey (vessel airborne check)         | **Gap** — not implemented                                                                     |
| DAY, TIME, LEGTYPE missing                              | **Partial** — `required_fields` checks configured fields; not all are configured              |
| BEAUFORT, CLOUD, VISIBLTY missing when LEGSTAGE present | **Gap** — conditional required-field check not implemented                                    |
| LEGSTAGE missing after active stage                     | **Gap** — not implemented                                                                     |
| LEGTYPE not 5 or 6 for intermittent ship                | **Schema** FK to LEGTYPE table catches invalid codes; survey-type restriction to 5/6 is a gap |
| LEGSTAGE sequence (valid: 1, 2, 5)                      | **Gap** — not implemented                                                                     |
| Speed > 25 knots                                        | **Gap** — not implemented                                                                     |

---

### ChkPair.sas — Paired aerial survey checks

| SAS check                                                                                                                        | New system coverage                                                                 |
| -------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Standard aerial checks (GLARE, STRATUM, STRIP, time format, times out of order, duplicate, speed, altitude, climb/descent rates) | **Gap** — see ChkCCSA gap entries above                                             |
| ALT = 999 bogus sentinel                                                                                                         | **Gap** — not implemented                                                           |
| LEGTYPE ≠ 7 and ≠ 9                                                                                                              | **Schema** FK catches invalid codes; restriction to 7/9 for paired surveys is a gap |
| LEGSTAGE sequence (valid: 1, 2, 5)                                                                                               | **Gap** — not implemented                                                           |
| > 15 minutes without a position (on-effort only)                                                                                 | **Gap** — not implemented                                                           |
| Speed > 200 (non-654) or > 130 (platform 654)                                                                                    | **Gap** — not implemented                                                           |
| Speed < 25                                                                                                                       | **Gap** — not implemented                                                           |
| SST gradient > 0.5 °C/nm with SSTDIFF > 1 °C                                                                                     | **Gap** — not implemented; no equivalent anywhere in MATLAB                         |
| PLATFORM 600–699 range                                                                                                           | **Schema** FK to PLATFORM table; paired-specific range check is a gap               |

---

### ChkShip.sas — Systematic shipborne survey checks

| SAS check                                                   | New system coverage                                                                                                |
| ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| MONTH/DAY change across consecutive records                 | **Gap** — not implemented                                                                                          |
| Time format and times out of order (cross-day)              | **Partial** / **Gap** — time format checked by `datetime_rules`; sequential check not implemented                  |
| ALT > 0 for ship survey                                     | **Gap** — not implemented                                                                                          |
| DAY, TIME, LEGTYPE missing                                  | **Partial** — `required_fields` covers configured fields                                                           |
| VISIBLTY > 20                                               | **MATLAB** — `environmental_rules.visibility_too_high` warns at > 50 (looser than SAS threshold of > 20 for ships) |
| BEAUFORT, CLOUD, WX, VISIBLTY missing when LEGSTAGE present | **Gap** — conditional required-field check not implemented                                                         |
| LEGSTAGE missing/sequence                                   | **Gap** — not implemented                                                                                          |
| LEGTYPE not 5 or 6                                          | **Schema** FK catches invalid codes; restriction is a gap                                                          |
| Speed > 20 knots                                            | **Gap** — not implemented                                                                                          |
| > 30 minutes without a position (on-effort)                 | **Gap** — not implemented                                                                                          |

---

### ChkSight.sas — Sighting field validation

| SAS check                                                                  | New system coverage                                                                                                                                                                                      |
| -------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| CONFIDNC missing                                                           | **MATLAB** — `required_fields` if configured; **Schema** FK allows NULL                                                                                                                                  |
| CONFIDNC > 11                                                              | **Schema** FK to Confidnc table; **MATLAB** `foreign_key_rules.confidnc_invalid`                                                                                                                         |
| CONFIDNC too large for NUMBER (matrix: group size → max confidence)        | **Gap** — not implemented                                                                                                                                                                                |
| CONFIDNC = 1 for NUMBER = 1 (±1 is illogical for a single animal)          | **Gap** — not implemented                                                                                                                                                                                |
| CONFIDNC = 11 with non-missing NUMBER (no-count code with an actual count) | **Gap** — not implemented                                                                                                                                                                                |
| NUMBER > 20 with CONFIDNC=0 for non-RECV/SPFV species                      | **Gap** — not implemented                                                                                                                                                                                |
| DEPTH > 2000 m                                                             | **Gap** — DEPTH field is not validated                                                                                                                                                                   |
| IDREL missing                                                              | **MATLAB** — `required_fields` if configured                                                                                                                                                             |
| IDREL = 0 or 4–8                                                           | **Schema** FK to IDREL table; **MATLAB** `foreign_key_rules.idrel_invalid`                                                                                                                               |
| IDREL = 1 for unidentified species (SPECCODE starts with 'UN')             | **Gap** — not implemented                                                                                                                                                                                |
| NUMBER missing when CONFIDNC ≠ 11                                          | **Gap** — conditional required-field check not implemented                                                                                                                                               |
| NUMBER = 0                                                                 | **MATLAB** — `species_rules.number_zero_for_sighting` (warning)                                                                                                                                          |
| NUMBER too high by TAXCODE (per-taxcode matrix)                            | **Partial gap** — `species_rules.number_unusual` flags NUMBER exceeding the SPECCODE/TAXCODE/global-default cascade threshold (warning-only, data-driven, not a fixed number); per-taxcode thresholds from SAS (TAXCODE 1/2: > 30; TAXCODE 5: > 5; etc.) are not implemented |
| NUMCALF ≥ 5                                                                | **Partial** — `species_rules.right_whale_high_calf_count` (warning at > 5 for right whales); generic `species_rules.numcalf_unusual` triggers at the SPECCODE/TAXCODE/global-default cascade threshold for all species                                |
| NUMCALF not less than NUMBER                                               | **MATLAB** — `species_rules.numcalf_exceeds_total` (error)                                                                                                                                               |
| PHOTOS missing                                                             | **MATLAB** — `required_fields` if configured                                                                                                                                                             |
| PHOTOS > 5                                                                 | **Schema** FK to PHOTOS table; **MATLAB** `foreign_key_rules.photos_invalid` and `photos_rules.photos_invalid`                                                                                           |

---

### ChkSpeci.sas — SPECCODE and TAXCODE validation

| SAS check                                   | New system coverage                                                                                                                                        |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SPECCODE missing                            | **MATLAB** — `species_rules.speccode_missing_for_sighting`                                                                                                 |
| SPECCODE not in hardcoded 2015 species list | **Schema** FK to SPECCODE table; **MATLAB** `species_rules.speccode_not_in_table` — lookup-table approach is more maintainable than the hardcoded SAS list |
| TAXCODE missing                             | **MATLAB** — `species_rules.taxcode_missing_for_sighting`                                                                                                  |

---

## 4. Open Issues Affecting Coverage

1. **CLOUD scale** — ChkBasic.sas treats only 0–4 and 9 as valid; Cloud.csv currently
   covers 0–9. Domain expert review required to determine correct valid set before
   either approach can be declared authoritative.

2. **HEADING range** — ChkBasic flags HEADING > 359 as an error. No MATLAB rule or
   schema constraint enforces this. Should be added to an existing rule (e.g.,
   `environmental_rules.m` or a new `platform_rules` check).

3. **YEAR/FILEID mismatch** — ChkBasic derives an expected year from the FILEID
   prefix character and digits and flags a mismatch. This cross-field check has no
   MATLAB equivalent.

4. **PORTOBS/STAROBS/SIGHTOBS** — ChkCCSA validates these observer code fields.
   They are not present in the 55-column MATLAB schema; confirm whether they should
   be added.

5. **Row-to-row temporal and spatial continuity** — ChkCCSA, ChkDair, ChkPair,
   ChkShip, and ChkIShip all rely on comparing consecutive rows (times out of order,
   position gaps, speed). These require a different computation pattern (sorted,
   grouped iteration) and have no equivalent anywhere in the current MATLAB rules.
   They represent the largest class of unported checks.

6. **LEGSTAGE state machine** — ChkCCSA and ChkDair validate that LEGSTAGE transitions
   follow a legal sequence within a file. This is a row-to-row check and is also not
   implemented.

7. **Conditional required fields** — Several SAS checks require fields only when
   certain conditions are met (ALT required for aerial, BEAUFORT/CLOUD/VISIBLTY
   required when LEGSTAGE is non-missing, TIME required except for opportunistic
   surveys). The `required_fields` rule is not yet parameterized for these conditions.

8. **CONFIDNC/NUMBER matrix** — ChkSight.sas validates that the confidence level is
   appropriate for the group size (e.g., CONFIDNC cannot be 8 for a group of 1). This
   cross-field check is not implemented.

9. **Duplicate SIGHTNO and metadata-inconsistent duplicate EVENTNO** — ChkDupes.sas
   and CHKDUPE2.sas are entirely unimplemented in the MATLAB system.

10. **BEHAV11 asymmetry** — ChkBehav.sas applies an extra restriction on codes 71–75
    specifically for the BEHAV11 slot. This is not implemented and may or may not be
    intentional domain logic.
