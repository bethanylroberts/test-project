# NARWC Database Reference

*Sources: NARWC Reference Document 2023-01, Version 8 (R.D. Kenney, URI/GSO); `src/+narwc/+db/FieldDefinitions.m`; validation rule modules in `src/+narwc/+validation/+rules/`; lookup table snapshots in `data/tables/`.*

---

## 1. Database Overview

The North Atlantic Right Whale Consortium (NARWC) Sightings Database archives cetacean, sea turtle, and marine mammal sightings from aerial and shipboard surveys and opportunistic reports conducted in the western North Atlantic Ocean from the late 1970s to the present. The database contains approximately 10.8 million event records spanning systematic dedicated surveys, platforms-of-opportunity programs, citizen science reports, and historical literature records.

### 1.1 History and Lineage

The database structure originates with the **Cetacean and Turtle Assessment Program (CETAP)**, a large-scale systematic aerial and shipboard survey of the northeastern U.S. continental shelf conducted from 1978 to 1982 under contract with the U.S. Bureau of Land Management. When the NARWC was established in the mid-1980s and began consolidating right whale sighting data from multiple contributors, the CETAP database schema was adopted as the foundation. Legacy CETAP codes, field names, and conventions persist throughout the documentation and some lookup tables.

The database was originally implemented in dBASE and analyzed with SAS macros written at URI/GSO. A migration to SQL Server has since been completed. The MATLAB codebase on the `refactor` branch provides import, validation, and processing tools for the SQL Server database.

The current authoritative documentation is the **NARWC Reference Document**, maintained by R.D. Kenney (URI/GSO). This document synthesizes Version 8 (Reference Document 2023-01). Where the PDF and the codebase conflict, Section 6 records the discrepancy rather than resolving it unilaterally; the code is generally the ground truth for what is currently enforced.

### 1.2 Data Categories

| Category            | Description                                                                                              |
| ------------------- | -------------------------------------------------------------------------------------------------------- |
| Dedicated aerial    | Systematic line-transect surveys flown by fixed-wing aircraft or helicopter                              |
| Shipboard / POP     | Systematic surveys from vessels; includes Platforms of Opportunity programs                              |
| Intermediate format | Data submitted in a standardized intermediate format (e.g., CCS 2015+, MassCEC)                          |
| Opportunistic       | Ad hoc sightings from vessels, shore stations, other aircraft, citizen science, and published literature |

Each row in the database corresponds to a single **event**: a sighting, a non-sighting weather or effort record, a leg boundary marker, or a watch transition.

### 1.3 Version 8 Changes

Version 8 of the reference document (2023) introduced or formalized:

- **ANGLEL** and **ANGLER**: declination angles to sightings from the trackline, replacing STRIP for NEAQ aerial surveys beginning in 2022.
- **New SPECCODE values**: CV-C (construction barge – crane), CV-O (other construction), CV-P (pile-driver), CV-R (rock dumper), CREW (offshore wind support vessel), CABL (cable/pipe laying, reinstated after earlier discontinuation).
- **New BEHAV codes 73 and 74**: actively fishing, and actively fishing with deployed gear (for vessel sightings).
- **ANHEAD code 20**: 360° milling or circling (no consistent heading).
- **TAXCODE=0**: formalized for vessels, gear, human activities, and debris/pollution sightings.

---

## 2. Survey Types and FILEID Conventions

### 2.1 FILEID Structure

FILEID is an 8-character alphanumeric identifier unique to each submitted data file. The encoding:

| Position | Content                                                             |
| -------- | ------------------------------------------------------------------- |
| 1        | Survey type code (uppercase = pre-2000; lowercase = 2000 and later) |
| 2        | Contributor or program identifier                                   |
| 3–4      | Two-digit year of survey                                            |
| 5–7      | Julian date (day of year) of the first data day in the file         |
| 8        | Sequence or qualifier code                                          |

The case convention on position 1 is a date marker only: uppercase indicates the file contains data from before 2000; lowercase indicates 2000 or later. This applies to position 1 only.

### 2.2 Survey Type Codes (Position 1)

| Code (pre-2000 / 2000+) | Type                                     |
| ----------------------- | ---------------------------------------- |
| A / a                   | Dedicated aerial line-transect survey    |
| F / f                   | Shipboard survey (POP and similar)       |
| H / h                   | Intermediate format (e.g., CCS, MassCEC) |
| O / o                   | Opportunistic sightings                  |

The lookup table `data/tables/DType.csv` (5 rows) records the currently active survey type codes. The fifth row has not been fully documented in the available PDF content; see Section 6.4.

---

## 3. Field Reference

All 55 fields currently defined in `narwc.db.FieldDefinitions` are described below, grouped by function. Fields that appear in the PDF but are absent from `FieldDefinitions` are listed in Section 7.

Where a field is constrained by a lookup table, the table filename and current row count are given. FK validation against lookup tables is handled by `foreign_key_rules.m` and by field-specific rule modules.

---

### 3.1 Survey Identity and Structure

#### FILEID
|         |             |
| ------- | ----------- |
| Type    | `string`    |
| NULL    | Not allowed |
| Lookup  | —           |
| Surveys | All         |

8-character survey file identifier (see Section 2). All event records within a single submitted file share the same FILEID. Listed as required in `required_fields.m` (that rule file carries a FIXME noting the required-field list is incomplete).

#### EVENTNO
|         |             |
| ------- | ----------- |
| Type    | `double`    |
| NULL    | Not allowed |
| Lookup  | —           |
| Surveys | All         |

Sequential event number within a file, assigned by the data-logging program (Logger, D-Tracker, Mysticetus) or manually. Each keypress creating a record increments EVENTNO. Must be unique within a file; gaps are acceptable. Listed as required in `required_fields.m`.

#### SIGHTNO
|         |                                                          |
| ------- | -------------------------------------------------------- |
| Type    | `double`                                                 |
| NULL    | Required for sightings; must be absent for non-sightings |
| Lookup  | —                                                        |
| Surveys | All (sighting records only)                              |

Sighting number, sequential from 1 within a file. Required for all sighting records and prohibited for non-sighting records. Duplicate SIGHTNOs within a file are not allowed; gaps are acceptable. During CETAP, SIGHTNO=999 was assigned to non-target species (seals, sharks, sunfish) to facilitate removal. Datasets submitted in dBASE format use SIGHTNO=0 for non-sightings; these are converted to true NULLs during import.

The SIGHTNO/non-sighting mutual-exclusion rule is described in the PDF but is not enforced by any current rule module; see Section 6.2.

#### BLOCK
|         |                                   |
| ------- | --------------------------------- |
| Type    | `string`                          |
| NULL    | Allowed                           |
| Lookup  | `data/tables/Block.csv` (55 rows) |
| Surveys | Dedicated aerial; some shipboard  |

Alphanumeric code identifying the geographic survey block within a stratified or systematic survey design.

#### STRATUM
|         |                                     |
| ------- | ----------------------------------- |
| Type    | `string`                            |
| NULL    | Allowed                             |
| Lookup  | `data/tables/STRATUM.csv` (10 rows) |
| Surveys | Dedicated aerial (stratified)       |

One-character depth stratum or sub-block identifier. Valid values:

| Code | Meaning                                            |
| ---- | -------------------------------------------------- |
| X    | 0–20 fathoms                                       |
| Y    | 20–50 fathoms                                      |
| Z    | > 50 fathoms                                       |
| 0    | Non-stratified aerial survey block                 |
| A, B | Scotian Shelf block halves (1987+)                 |
| I    | Florida, inshore (1989–1992 MMS surveys)           |
| O    | Florida, offshore                                  |
| M    | NLPSC year 2+, Martha's Vineyard area              |
| R    | NLPSC year 2+, Rhode Island (expanded area, 2012+) |

#### LEGNO
|         |                                |
| ------- | ------------------------------ |
| Type    | `double`                       |
| NULL    | Allowed                        |
| Lookup  | —                              |
| Surveys | Dedicated aerial and shipboard |

Sequential leg number within a file. Increments each time a new effort leg begins. Gaps are permitted.

#### LEGTYPE
|         |                                    |
| ------- | ---------------------------------- |
| Type    | `double`                           |
| NULL    | Allowed                            |
| Lookup  | `data/tables/LEGTYPE.csv` (9 rows) |
| Surveys | Dedicated aerial and shipboard     |

Code for the structural type of a leg (transect, transit, circling, etc.). LEGTYPE=2 designates an on-effort transect leg. Combined with LEGSTAGE=2, it defines the "on-effort" condition that governs STRIP requirements.

#### LEGSTAGE
|         |                                     |
| ------- | ----------------------------------- |
| Type    | `double`                            |
| NULL    | Allowed                             |
| Lookup  | `data/tables/LEGSTAGE.csv` (9 rows) |
| Surveys | Dedicated aerial and shipboard      |

Code for the stage within a leg (e.g., beginning of watch, on watch, end of watch). LEGSTAGE=2 indicates observers are actively on watch. Together with LEGTYPE=2, defines on-effort status.

#### DDSOURCE
|         |                                      |
| ------- | ------------------------------------ |
| Type    | `string`                             |
| NULL    | Not allowed                          |
| Lookup  | `data/tables/DDSOURCE.csv` (48 rows) |
| Surveys | All                                  |

Data delivery source code, identifying the program or contributor that submitted the data. Listed as required in `required_fields.m`.

#### IDSOURCE
|         |                                      |
| ------- | ------------------------------------ |
| Type    | `string`                             |
| NULL    | Not allowed                          |
| Lookup  | `data/tables/IDSOURCE.csv` (53 rows) |
| Surveys | All                                  |

Identification source code, recording who or what made the species identification. Listed as required in `required_fields.m`.

---

### 3.2 Date and Time

#### YEAR
|         |             |
| ------- | ----------- |
| Type    | `double`    |
| NULL    | Not allowed |
| Lookup  | —           |
| Surveys | All         |

Four-digit calendar year. Required for all records. Formerly stored as two digits; expanded to four digits for Y2K. `datetime_rules.m` enforces range 1970–(current year + 1) and issues a warning for values before 1990.

#### MONTH
|         |                                   |
| ------- | --------------------------------- |
| Type    | `double`                          |
| NULL    | Allowed                           |
| Lookup  | `data/tables/MONTH.csv` (16 rows) |
| Surveys | All                               |

Calendar month (1–12). `datetime_rules.m` enforces 1 ≤ MONTH ≤ 12. The MONTH.csv lookup has 16 rows; the extra rows are for the seasons (winter, spring, summer, fall)

#### DAY
|         |          |
| ------- | -------- |
| Type    | `double` |
| NULL    | Allowed  |
| Lookup  | —        |
| Surveys | All      |

Day of month (1–31). `datetime_rules.m` enforces 1 ≤ DAY ≤ 31 and validates YEAR/MONTH/DAY as a legal calendar date.

#### TIME
|         |                                                                     |
| ------- | ------------------------------------------------------------------- |
| Type    | `double`                                                            |
| NULL    | Allowed (opportunistic records only)                                |
| Lookup  | —                                                                   |
| Surveys | All (required for aerial and shipboard; optional for opportunistic) |

Event clock time in HHMMSS format, 24-hour UTC. During a 2020 database update all archived times were converted from Eastern Standard Time to UTC. Legacy four-digit times (hhmm) are expanded to HHMMSS by appending "00" during archival; four-digit times are no longer accepted for new survey submissions.

`datetime_rules.m` validates HH < 24, MM < 60, SS < 60, and the full value < 240000.

---

### 3.3 Position and Geometry

#### LAT_DD
|         |                                                      |
| ------- | ---------------------------------------------------- |
| Type    | `double`                                             |
| NULL    | Required for sightings; allowed for some event types |
| Lookup  | —                                                    |
| Surveys | All                                                  |

Latitude of the **survey platform** at the moment of the event, in decimal degrees north (positive = north). `coordinate_rules.m` enforces −90 ≤ LAT_DD ≤ 90 and issues a warning for values outside approximately 35–50°N. LAT_DD and LONG_DD must both be present or both absent.

#### LONG_DD
|         |                                                      |
| ------- | ---------------------------------------------------- |
| Type    | `double`                                             |
| NULL    | Required for sightings; allowed for some event types |
| Lookup  | —                                                    |
| Surveys | All                                                  |

Longitude of the survey platform at the moment of the event, in decimal degrees (negative = west). Western Atlantic survey data will have negative values. `coordinate_rules.m` enforces −180 ≤ LONG_DD ≤ 180 and issues a warning for values outside approximately 60–75°W.

#### ALT
|         |                              |
| ------- | ---------------------------- |
| Type    | `double`                     |
| NULL    | Allowed (non-aerial records) |
| Lookup  | —                            |
| Surveys | Aerial only                  |

Flight altitude. Per the reference PDF, values are in **feet**. The description in `FieldDefinitions` ("Altitude in meters") is incorrect. No range validation is currently implemented.

#### HEADING
|         |          |
| ------- | -------- |
| Type    | `double` |
| NULL    | Allowed  |
| Lookup  | —        |
| Surveys | All      |

Compass heading of the survey platform in degrees (0–360). Not to be confused with ANHEAD, which records the observed animal's heading. No validation is currently implemented for this field.

#### STRIP
|         |                                                                                        |
| ------- | -------------------------------------------------------------------------------------- |
| Type    | `double`                                                                               |
| NULL    | Required for on-effort animal sightings (LEGTYPE=2, LEGSTAGE=2); not allowed otherwise |
| Lookup  | `data/tables/STRIP.csv` (16 rows)                                                      |
| Surveys | Aerial line-transect                                                                   |

Two-digit right-angle distance interval of the sighting from the survey trackline. Odd numbers indicate the left (port) side; even numbers indicate right (starboard). Code 0 (on trackline) applies only to the AT-11 aircraft.

CETAP and early NLPSC codes (1978–2011):

| Codes  | Interval                                 |
| ------ | ---------------------------------------- |
| 0      | Trackline (AT-11 only)                   |
| 1, 2   | 0–¼ n.mi.                                |
| 3, 4   | 0–⅛ n.mi.                                |
| 5, 6   | ⅛–¼ n.mi.                                |
| 7, 8   | ¼–½ n.mi.                                |
| 9, 10  | ½–¾ n.mi.                                |
| 11, 12 | ¾–1 n.mi.                                |
| 13, 14 | >1 n.mi. (AT-11) / 1–2 n.mi. (Skymaster) |
| 15, 16 | >2 n.mi. (Skymaster)                     |

NLPSC/MassCEC Skymaster codes (October 2011 onward):

| Codes  | Interval  |
| ------ | --------- |
| 1, 2   | <⅛ n.mi.  |
| 3, 4   | ⅛–¼ n.mi. |
| 5, 6   | ¼–½ n.mi. |
| 7, 8   | ½–1 n.mi. |
| 9, 10  | 1–2 n.mi. |
| 11, 12 | 2–4 n.mi. |
| 13, 14 | >4 n.mi.  |

In 2022 the NEAQ aerial survey team stopped recording STRIP and switched to declination angles (ANGLEL, ANGLER). The STRIP requirement for on-effort sightings is documented in the PDF but is not enforced by any current rule module; see Section 6.2.

#### ANGLEL
|         |                                    |
| ------- | ---------------------------------- |
| Type    | `double`                           |
| NULL    | Allowed                            |
| Lookup  | —                                  |
| Surveys | Aerial line-transect (NEAQ, 2022+) |

Declination angle (degrees below horizontal) to a sighting on the **left (port)** side of the trackline. Added in Version 8 to replace STRIP for the NEAQ aerial program. Provides more precise right-angle distances than strip codes and is less sensitive to changes in survey altitude.

#### ANGLER
|         |                                    |
| ------- | ---------------------------------- |
| Type    | `double`                           |
| NULL    | Allowed                            |
| Lookup  | —                                  |
| Surveys | Aerial line-transect (NEAQ, 2022+) |

Declination angle to a sighting on the **right (starboard)** side of the trackline. Companion to ANGLEL. Exactly one of ANGLEL/ANGLER should be populated for a given sighting; no rule currently enforces mutual exclusivity.

#### S_LAT
|         |                                            |
| ------- | ------------------------------------------ |
| Type    | `double`                                   |
| NULL    | Allowed                                    |
| Lookup  | —                                          |
| Surveys | Aerial line-transect (NLPSC/MassCEC 2011+) |

Latitude of the **exact position of the sighting** (not the platform) in decimal degrees north. Added for the 2011–12 NLPSC/MassCEC aerial surveys to support trigonometric calculation of right-angle distances and to verify STRIP estimates. Analogous to the retired CETAP fields ALATDEG/ALATMIN/ALATSEC. S_LAT and S_LONG should both be present or both absent (not currently enforced).

#### S_LONG
|         |                                            |
| ------- | ------------------------------------------ |
| Type    | `double`                                   |
| NULL    | Allowed                                    |
| Lookup  | —                                          |
| Surveys | Aerial line-transect (NLPSC/MassCEC 2011+) |

Longitude of the exact sighting position in decimal degrees (negative = west). Companion to S_LAT. Analogous to the retired CETAP fields ALONDEG/ALONMIN/ALONSEC.

#### S_TIME
|         |                                            |
| ------- | ------------------------------------------ |
| Type    | `double`                                   |
| NULL    | Allowed                                    |
| Lookup  | —                                          |
| Surveys | Aerial line-transect (NLPSC/MassCEC 2012+) |

Clock time (HHMMSS, UTC) at which the exact-position sighting (S_LAT/S_LONG) was recorded during circling. Added after the first year of NLPSC surveys to assess elapsed time between initial trackline detection and the circling position. May differ from TIME, which records the initial detection moment.

---

### 3.4 Species and Count

#### SPECCODE
|         |                                                         |
| ------- | ------------------------------------------------------- |
| Type    | `string`                                                |
| NULL    | Required for sightings; must be blank for non-sightings |
| Lookup  | `data/tables/SPECCODE.csv` (317 rows)                   |
| Surveys | All (sighting records only)                             |

Four-letter species or category code. Required for all sighting records and prohibited for non-sighting records. Contributors may not create new codes; additions require approval from the database manager. The legacy dBASE field name is CETSPPCD.

SPECCODE.csv contains all 317 active codes. Key codes by taxonomic group:

**TAXCODE=1 (large cetaceans):** BLWH, BOWH, BRWH, FIWH, GRWH, HUWH, RIWH *(North Atlantic right whale)*, SEWH, SPWH, SRWH, UNBA, UNBS, UNFS, UNLW, UNRO, UNWH

**TAXCODE=2 (medium cetaceans):** BEWH, BLBW, GEBW, GOBW, KIWH, MIWH, NBWH, SOBW, TRBW, UNBW, UNMW

**TAXCODE=3 (small cetaceans):** ASDO, BELU, BODO, CLDO, DSWH, FKWH, FRDO, GRAM, HAPO, LFPW, MHWH, NARW *(narwhal)*, OBDO, PIWH, PSDO, PSWH, PYKW, RTDO, SADO, SFPW, SNDO, SPDO, STDO, TADO, UNBD, UNBF, UNCW, UNDO, UNGD, UNKO, UNLD, UNSB, UNST, WBDO, WSDO

**TAXCODE=4 (other marine mammals):** BESE, GRSE, HASE, HGSE, HOSE, HPSE, MANA, PINN, POBE, RISE, UNCE, UNMM, UNSE, WALR

**TAXCODE=5 (sea turtles):** GRTU, HATU, LETU, LOTU, ORTU, RITU, UNTU

**TAXCODE=6 (sharks):** ANSH, BASH, BLSH, DUSH, GHSH, HHSH, LMSH, MKSH, SDOG, SMSH, THSH, TISH, UNSH, WHSH, WTSH

**TAXCODE=7 (other fish):** BFTU, BLFI, CDRA, CNRA, FLFI, MAHI, MARA, MOBU, OCSU, OTBI, SCFI, SCRA, SWFI, TUNS, UNFI, UNRA, WHMA, YFTU

**TAXCODE=8 (birds):** ~50+ codes; see SPECCODE.csv. Includes NOGA, GRSH, NOFU, HERG, GBBG, ATPU, COMU, and many others.

**TAXCODE=9 (other):** AMAL, JELL, LMJE, PMOW, UNID, ZOOP

**TAXCODE=0 (vessels, gear, human activity, debris):** Active codes include CABL, CG-B, CG-C, CG-S, CG-U, CREW, CRSH, CV-C, CV-O, CV-P, CV-R, DE-B through DE-W, DR-D through DR-W, ECOT, EXPL, FE-H/S/U, FG-A through FG-U, FRNT, FV-C through FV-Z, HELO, JETS, KAYK, LE-V, METT, MV-B through MV-U, MY-L/S, NV-L/S/U, OI-D/L/P/S, OW-B, PIBO, RECV, RV-G/L/S/U/W, SONO, SPFV, SV-L/S/U, UNVE, WHAL, and others. Italicized CETAP codes (*AC-J, AC-P, AC-S, AC-T, BT-H, BT-L, BT-M, DIVE, DU-G, DU-T, MULT, SONR, SWIM*) are obsolete and **must not be used**.

`species_rules.m` validates SPECCODE values against SPECCODE.csv.

#### TAXCODE
|         |                                     |
| ------- | ----------------------------------- |
| Type    | `double`                            |
| NULL    | Required for sightings              |
| Lookup  | `data/tables/TAXCODE.csv` (10 rows) |
| Surveys | All (sighting records only)         |

One-digit taxonomic category. Values: 0=vessel/gear/human activity/debris, 1=large cetacean, 2=medium cetacean, 3=small cetacean, 4=other marine mammal, 5=sea turtle, 6=shark, 7=other fish, 8=bird, 9=other/unknown.

Per the reference PDF, TAXCODE is assigned automatically by a SAS macro during data entry at GSO and is therefore invisible to data contributors. In the MATLAB codebase, TAXCODE appears in `FieldDefinitions` as a standard field, but no rule module validates consistency between TAXCODE and SPECCODE; the two are kept consistent via the database import process.

#### NUMBER
|         |                        |
| ------- | ---------------------- |
| Type    | `double`               |
| NULL    | Allowed                |
| Lookup  | —                      |
| Surveys | All (sighting records) |

Best estimate of the number of animals in the sighting group. Should be ≥ NUMCALF. This constraint is not currently enforced in code.

#### NUMCALF
|         |                        |
| ------- | ---------------------- |
| Type    | `double`               |
| NULL    | Allowed                |
| Lookup  | —                      |
| Surveys | All (sighting records) |

Number of calves observed within the sighting group. Must be ≤ NUMBER (not enforced in code). Both zero and NULL are acceptable when no calves were observed.

---

### 3.5 Sighting Characteristics

#### BEHAV1–BEHAV15
|         |                                                                     |
| ------- | ------------------------------------------------------------------- |
| Type    | `double` (each field)                                               |
| NULL    | Allowed for BEHAV2–15; BEHAV1 is expected when behavior is observed |
| Lookup  | `data/tables/Behave.csv` (90 rows)                                  |
| Surveys | All (sighting records)                                              |

Up to 15 simultaneous behavioral observation codes per sighting. Slots are filled left to right; unused slots are NULL. No duplicate codes within a single sighting are expected. `behavioral_rules.m` validates all populated BEHAV slots against the 90 codes in Behave.csv.

Behavior codes cover general locomotion states (traveling, milling, logging, breaching), feeding behaviors, social behaviors, injury/mortality indicators, and vessel interaction codes. Codes 73 (actively fishing) and 74 (actively fishing with deployed gear) were added in Version 8 for vessel sightings (TAXCODE=0).

The following synthetic variables are derived from BEHAVn fields by SAS macros and are not stored in the database: CALF, DEAD, FEED, FISHING, GEAR, HURT, JELL, MILL, POOP, SAG, STRK, WAKE, WHLR.

#### ANHEAD
|         |                                       |
| ------- | ------------------------------------- |
| Type    | `double`                              |
| NULL    | Allowed                               |
| Lookup  | `data/tables/ANHEAD.csv` (20 rows)    |
| Surveys | Aerial and some shipboard (sightings) |

Coded compass heading of the observed animal's head at the time of sighting, recorded as a directional interval rather than an exact bearing. The 20 codes represent compass segments; code 20 (added in Version 8) indicates 360° milling or circling with no consistent heading. Used in computing the synthetic variable MILL.

#### IDREL
|         |                                  |
| ------- | -------------------------------- |
| Type    | `double`                         |
| NULL    | Allowed                          |
| Lookup  | `data/tables/IDREL.csv` (4 rows) |
| Surveys | All                              |

Identification reliability code (4 levels: sure/positive, probable, possible, not recorded). Used to generate the synthetic variable ID during data delivery.

#### CONFIDNC
|         |                                      |
| ------- | ------------------------------------ |
| Type    | `double`                             |
| NULL    | Allowed                              |
| Lookup  | `data/tables/Confidnc.csv` (12 rows) |
| Surveys | All                                  |

Overall sighting confidence level.

#### PHOTOS
|         |                                   |
| ------- | --------------------------------- |
| Type    | `double`                          |
| NULL    | Allowed                           |
| Lookup  | `data/tables/PHOTOS.csv` (5 rows) |
| Surveys | All (sighting records)            |

Code indicating the type of photographic record obtained for the sighting (e.g., none, still photography, video, aerial imagery). A `photos_rules.m` module exists in the rules directory but is not confirmed as wired into `SurveyValidator.m`.

---

### 3.6 Platform

#### PLATFORM
|         |                                       |
| ------- | ------------------------------------- |
| Type    | `double`                              |
| NULL    | Allowed                               |
| Lookup  | `data/tables/PLATFORM.csv` (283 rows) |
| Surveys | All                                   |

Numeric code identifying the survey vessel or aircraft. The code space is divided into named ranges:

| Range   | Category                                                                   |
| ------- | -------------------------------------------------------------------------- |
| 001–019 | USCG vessels                                                               |
| 020–099 | NOAA and federal research vessels                                          |
| 100–199 | Foreign research and institutional vessels                                 |
| 200–299 | Sailing vessels and whale-watch boats                                      |
| 300–349 | CETAP charter vessels                                                      |
| 350–374 | Canadian and commercial platforms                                          |
| 375–424 | Charter fishing vessels                                                    |
| 425–474 | Passenger ferries                                                          |
| 475–525 | Tugs and work boats                                                        |
| 526–550 | BLM charter vessels                                                        |
| 551–599 | Miscellaneous vessels                                                      |
| 600–619 | Helicopters                                                                |
| 620–625 | Private aircraft                                                           |
| 626–639 | Dedicated survey aircraft                                                  |
| 640–644 | U.S. Coast Guard aircraft                                                  |
| 645–699 | Miscellaneous aircraft                                                     |
| 700–999 | Other (shore stations, internet sources, stranding data, literature, etc.) |

`platform_rules.m` validates PLATFORM values against PLATFORM.csv.

---

### 3.7 Environmental Conditions

#### BEAUFORT
|         |                                                             |
| ------- | ----------------------------------------------------------- |
| Type    | `double`                                                    |
| NULL    | Allowed                                                     |
| Lookup  | `data/tables/Beaufort.csv` (13 rows)                        |
| Surveys | All (required for on-watch records in aerial and shipboard) |

Beaufort sea state (0–12). Beaufort.csv covers the full 0–12 scale (13 entries). The description in `FieldDefinitions` ("Beaufort sea state (0-9)") is incorrect; see Section 6.3. BEAUFORT and VISIBLTY together define acceptable survey effort; the standard on-effort threshold is Beaufort ≤ 3 and VISIBLTY ≥ 2 n.mi. `beaufort_rules.m` validates against the lookup table.

#### VISIBLTY
|         |                                                             |
| ------- | ----------------------------------------------------------- |
| Type    | `double`                                                    |
| NULL    | Allowed                                                     |
| Lookup  | —                                                           |
| Surveys | All (required for on-watch records in aerial and shipboard) |

Estimated clear visibility in nautical miles, to the nearest 0.1 n.mi. Required for all on-watch records in aerial and shipboard data; optional elsewhere.

Legacy negative values persist in the archived database (migrated from the old OLDVIZ field during the 2020 update): −1 = clear ≥2 n.mi., −2 = <2 n.mi. fog, −3 = <2 n.mi. haze, −4 = <2 n.mi. rain, −5 = <2 n.mi. snow. **No new data should use negative VISIBLTY values.** `environmental_rules.m` currently permits negative values (`visibility_allow_negative = true`) but carries a FIXME indicating that this should be restricted.

#### SURFTEMP
|         |                |
| ------- | -------------- |
| Type    | `double`       |
| NULL    | Allowed        |
| Lookup  | —              |
| Surveys | All (optional) |

Sea surface temperature in degrees Celsius. Optional for all record types. Formerly called WTEMP during CETAP. Can be measured by airborne radiometer (aerial surveys) or shipboard instruments. SST data from airborne radiometers have been erratic in some datasets; users should apply caution. `environmental_rules.m` issues warnings for values outside −2 to 35°C.

#### CLOUD
|         |                                  |
| ------- | -------------------------------- |
| Type    | `double`                         |
| NULL    | Allowed                          |
| Lookup  | `data/tables/Cloud.csv` (6 rows) |
| Surveys | All (optional)                   |

Cloud cover in oktas (eighths of sky covered). The standard scale is 0–8. The description in `FieldDefinitions` ("Cloud cover (0-10)") is incorrect; see Section 6.3. Cloud.csv has only 6 rows, which may indicate an incomplete or stale snapshot (see Section 6.4). Cloud cover validation has been commented out in `environmental_rules.m` pending review.

#### WX
|         |                                     |
| ------- | ----------------------------------- |
| Type    | `string`                            |
| NULL    | Allowed                             |
| Lookup  | `data/tables/WX.csv` (12 rows)      |
| Surveys | All (optional; strongly encouraged) |

One-character weather condition code. Added in 2004 alongside the redesigned VISIBLTY field. Valid values:

| Code | Condition                               |
| ---- | --------------------------------------- |
| B    | Rain (or other precipitation) and fog   |
| C    | Clear                                   |
| D    | Drizzle                                 |
| F    | Fog                                     |
| G    | Gray (heavy overcast, no precipitation) |
| H    | Haze                                    |
| L    | Light rain / intermittent showers       |
| P    | Patchy fog                              |
| R    | Rain                                    |
| S    | Snow                                    |
| T    | Thunderstorms / squalls                 |
| X    | Not recorded                            |

WX validation was implemented in `environmental_rules.m` but has been commented out with a FIXME noting that validation should be done via the lookup table through `foreign_key_rules.m`.

#### GLAREL
|         |                                  |
| ------- | -------------------------------- |
| Type    | `double`                         |
| NULL    | Allowed                          |
| Lookup  | `data/tables/GLARE.csv` (4 rows) |
| Surveys | All (optional)                   |

Glare severity on the left (port) side of the platform (0=none, 1=light, 2=moderate, 3=severe).

#### GLARER
|         |                                  |
| ------- | -------------------------------- |
| Type    | `double`                         |
| NULL    | Allowed                          |
| Lookup  | `data/tables/GLARE.csv` (4 rows) |
| Surveys | All (optional)                   |

Glare severity on the right (starboard) side. Same scale as GLAREL.

---

## 4. Cross-Field Rules

### 4.1 Rules Enforced in Code

The following rules are checked by validation modules in `src/+narwc/+validation/+rules/`. `SurveyValidator.m` orchestrates all modules.

| Rule                                                                          | Fields involved  | Module                  | Severity |
| ----------------------------------------------------------------------------- | ---------------- | ----------------------- | -------- |
| LAT_DD and LONG_DD must both be present or both absent                        | LAT_DD, LONG_DD  | `coordinate_rules.m`    | error    |
| LAT_DD must be in range −90 to 90                                             | LAT_DD           | `coordinate_rules.m`    | error    |
| LONG_DD must be in range −180 to 180                                          | LONG_DD          | `coordinate_rules.m`    | error    |
| Coordinates outside typical survey area (~35–50°N, 60–75°W)                   | LAT_DD, LONG_DD  | `coordinate_rules.m`    | warning  |
| YEAR in range 1970 to current year + 1                                        | YEAR             | `datetime_rules.m`      | error    |
| YEAR before 1990                                                              | YEAR             | `datetime_rules.m`      | warning  |
| MONTH must be 1–12                                                            | MONTH            | `datetime_rules.m`      | error    |
| DAY must be 1–31                                                              | DAY              | `datetime_rules.m`      | error    |
| YEAR/MONTH/DAY must form a valid calendar date                                | YEAR, MONTH, DAY | `datetime_rules.m`      | error    |
| TIME must be valid HHMMSS (HH < 24, MM < 60, SS < 60)                         | TIME             | `datetime_rules.m`      | error    |
| BEAUFORT must be in Beaufort.csv                                              | BEAUFORT         | `beaufort_rules.m`      | error    |
| BEHAV1–15 codes must be in Behave.csv                                         | BEHAV1–BEHAV15   | `behavioral_rules.m`    | error    |
| SPECCODE must be in SPECCODE.csv                                              | SPECCODE         | `species_rules.m`       | error    |
| PLATFORM must be in PLATFORM.csv                                              | PLATFORM         | `platform_rules.m`      | error    |
| VISIBLTY must be ≥ 0 (configuration dependent; currently allow_negative=true) | VISIBLTY         | `environmental_rules.m` | error    |
| VISIBLTY > 50 n.mi. is unusually high                                         | VISIBLTY         | `environmental_rules.m` | warning  |
| SURFTEMP outside −2 to 35°C                                                   | SURFTEMP         | `environmental_rules.m` | warning  |
| Required fields (DDSOURCE, EVENTNO, FILEID, IDSOURCE, YEAR) non-NULL          | multiple         | `required_fields.m`     | error    |

The required-fields list in `required_fields.m` is marked with a FIXME noting it is incomplete and not fully accurate.

### 4.2 Rules Documented in PDF but Not Enforced in Code

| Rule                                                                | Fields                   | Assessment                                  |
| ------------------------------------------------------------------- | ------------------------ | ------------------------------------------- |
| SIGHTNO required for sightings; absent for non-sightings            | SIGHTNO                  | Possibly unimplemented                      |
| SPECCODE required for sightings; absent for non-sightings           | SPECCODE                 | Possibly unimplemented                      |
| SIGHTNO must be unique within a file                                | SIGHTNO, FILEID          | Possibly unimplemented                      |
| STRIP required when LEGTYPE=2 and LEGSTAGE=2; not allowed otherwise | STRIP, LEGTYPE, LEGSTAGE | Possibly unimplemented                      |
| ANGLEL/ANGLER replace STRIP for NEAQ 2022+; not mixed with STRIP    | ANGLEL, ANGLER, STRIP    | No mutual-exclusion rule                    |
| TAXCODE must be consistent with SPECCODE                            | TAXCODE, SPECCODE        | Likely intentional — TAXCODE is DB-assigned |
| NUMBER must be ≥ NUMCALF                                            | NUMBER, NUMCALF          | Possibly unimplemented                      |
| S_LAT and S_LONG must both be present or both absent                | S_LAT, S_LONG            | Possibly unimplemented                      |
| ALT should be within reasonable range for survey aircraft           | ALT                      | Possibly unimplemented                      |
| HEADING must be 0–360°                                              | HEADING                  | Possibly unimplemented                      |
| LEGNO is sequential within a file                                   | LEGNO, FILEID            | Likely intentional — gaps are permitted     |

---

## 5. Lookup Table Inventory

All files are in `data/tables/`. They are CSV snapshots exported from the production SQL Server database via `scripts/setup/pull_lookup_tables.m`. The production database is authoritative; these snapshots may drift from the live database as codes are added or retired.

| File            | Rows | Constrains field(s) | Notes                                                                    |
| --------------- | ---- | ------------------- | ------------------------------------------------------------------------ |
| ANHEAD.csv      | 20   | ANHEAD              | Codes 1–20; code 20 (milling) added in Version 8                         |
| Beaufort.csv    | 13   | BEAUFORT            | Full scale 0–12; `FieldDefinitions` description of 0–9 is incorrect      |
| Behave.csv      | 90   | BEHAV1–BEHAV15      | 90 distinct behavior codes; codes 73–74 added in Version 8               |
| Block.csv       | 55   | BLOCK               | Survey block identifiers                                                 |
| Cloud.csv       | 6    | CLOUD               | Fewer than 9 rows expected for full 0–8 okta scale; possibly stale       |
| Confidnc.csv    | 12   | CONFIDNC            | Sighting confidence levels                                               |
| Contrib.csv     | 23   | —                   | Data contributor lookup; not a direct field FK constraint                |
| DDSOURCE.csv    | 48   | DDSOURCE            | Data delivery source codes                                               |
| DType.csv       | 5    | —                   | Survey type codes; fifth code not fully documented in PDF                |
| GLARE.csv       | 4    | GLAREL, GLARER      | Values 0–3                                                               |
| IDREL.csv       | 4    | IDREL               | Identification reliability (sure, probable, possible, not recorded)      |
| IDSOURCE.csv    | 53   | IDSOURCE            | Identification source codes                                              |
| LEGGOOD.csv     | 2    | —                   | Leg usability flag (2 values)                                            |
| LEGSTAGE.csv    | 9    | LEGSTAGE            | Stage-within-leg codes                                                   |
| LEGTYPE.csv     | 9    | LEGTYPE             | Leg-type codes                                                           |
| MONTH.csv       | 16   | MONTH               | 16 rows for 12 months; extra rows likely display metadata                |
| OLDVIZ.csv      | 5    | —                   | Legacy visibility codes −1 to −5; field retired; for reference only      |
| PHOTOS.csv      | 5    | PHOTOS              | Photo type codes                                                         |
| PLATFORM.csv    | 283  | PLATFORM            | Full platform enumeration consistent with PDF                            |
| SPECCODE.csv    | 317  | SPECCODE            | All active codes across all TAXCODE groups including TAXCODE=0 and birds |
| STRATUM.csv     | 10   | STRATUM             | X, Y, Z, 0, A, B, I, O, M, R                                             |
| STRIP.csv       | 16   | STRIP               | Distance interval codes                                                  |
| sysdiagrams.csv | 0    | —                   | SQL Server system table artifact; no validation use                      |
| TAXCODE.csv     | 10   | TAXCODE             | Values 0–9                                                               |
| WX.csv          | 12   | WX                  | Weather codes B, C, D, F, G, H, L, P, R, S, T, X                         |

---

## 6. PDF–Code Gaps

### 6.1 Likely Deprecated (CETAP-era or formally retired)

| Item                                | Description                                                                                                                                                                          |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Negative VISIBLTY values (−1 to −5) | Migrated from the retired OLDVIZ field during the 2020 database update. Exist in the archive for historical records only. The PDF explicitly prohibits their use in new submissions. |
| OLDVIZ.csv                          | Retained for reference; the OLDVIZ field has been retired and values folded into VISIBLTY.                                                                                           |
| HUMANACT and DEBRIS fields          | CETAP-era codes for human activities and debris. Replaced by TAXCODE=0 sightings with SPECCODE values.                                                                               |
| Italicized TAXCODE=0 SPECCODEs      | AC-J, AC-P, AC-S, AC-T, BT-H, BT-L, BT-M, DIVE, DU-G, DU-T, MULT, SONR, SWIM are obsolete CETAP HUMANACT codes explicitly prohibited in the NARWC database.                          |
| SIGHTNO=0 for non-sightings         | dBASE submission artifact; converted to NULL during archival.                                                                                                                        |
| Four-digit TIME (hhmm)              | No longer accepted for survey data; expanded to HHMMSS by appending "00".                                                                                                            |

### 6.2 Possibly Unimplemented

| Item                                | Fields                   | Description                                                                                                                          |
| ----------------------------------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| Sighting-record constraints         | SIGHTNO, SPECCODE        | Both fields have required/prohibited conditions based on whether a record is a sighting, but no rule module implements these checks. |
| STRIP conditional requirement       | STRIP, LEGTYPE, LEGSTAGE | The PDF requires STRIP for on-effort (LEGTYPE=2, LEGSTAGE=2) animal sightings. Not enforced.                                         |
| ANGLEL/ANGLER vs. STRIP exclusivity | ANGLEL, ANGLER, STRIP    | The two systems are mutually exclusive by survey program but not enforced in code.                                                   |
| NUMBER ≥ NUMCALF                    | NUMBER, NUMCALF          | Logical constraint; not enforced.                                                                                                    |
| S_LAT/S_LONG co-presence            | S_LAT, S_LONG            | Should follow the same both-present-or-both-absent rule as LAT_DD/LONG_DD; not implemented.                                          |
| SIGHTNO uniqueness within file      | SIGHTNO, FILEID          | Duplicate detection not implemented.                                                                                                 |
| VISIBLTY negative value restriction | VISIBLTY                 | `environmental_rules.m` has `visibility_allow_negative = true` with a FIXME noting this should be restricted to legacy records only. |

### 6.3 Known Errors in FieldDefinitions

| Field                | FieldDefinitions value     | Correct value      | Source                               |
| -------------------- | -------------------------- | ------------------ | ------------------------------------ |
| BEAUFORT description | "Beaufort sea state (0-9)" | Range is 0–12      | PDF §8.A.2; Beaufort.csv has 13 rows |
| CLOUD description    | "Cloud cover (0-10)"       | Scale is 0–8 oktas | PDF §8.A.4; standard okta scale      |
| ALT description      | "Altitude in meters"       | Values are in feet | PDF §8.A.1                           |

### 6.4 Unclear

| Item                | Description                                                                                                                                                                                                           |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MONTH.csv (16 rows) | The table has 16 rows; calendar months should yield 12. Extra rows may be display metadata or schema artifacts. No impact on validation since MONTH is validated by range check in `datetime_rules.m`, not by lookup. |
| Cloud.csv (6 rows)  | A complete 0–8 okta scale requires 9 rows. The 6-row table may be incomplete. Cloud validation is commented out, so this does not currently affect data quality checks.                                               |
| DType.csv (5th row) | The reference PDF describes four survey type codes (A, F, H, O). The fifth entry in DType.csv is undocumented in the PDF content reviewed.                                                                            |

---

## 7. Deprecated / Legacy Fields

The following fields are described in the reference PDF (Chapter 8, Part C: "Variables that no longer exist") or are otherwise known to be retired. They are absent from `narwc.db.FieldDefinitions` and should not appear in new data submissions.

| Field    | Former description                                                                | Replaced by                                         |
| -------- | --------------------------------------------------------------------------------- | --------------------------------------------------- |
| ADEPTH   | Water depth (meters) at exact sighting position. CETAP line-transect aerial only. | No direct replacement                               |
| ALATDEG  | Degrees of latitude at exact sighting position. CETAP line-transect aerial only.  | S_LAT                                               |
| ALATMIN  | Minutes of latitude at exact sighting position. CETAP only.                       | S_LAT                                               |
| ALATSEC  | Seconds of latitude at exact sighting position. CETAP only.                       | S_LAT                                               |
| ALONDEG  | Degrees of longitude at exact sighting position. CETAP only.                      | S_LONG                                              |
| ALONMIN  | Minutes of longitude at exact sighting position. CETAP only.                      | S_LONG                                              |
| ALONSEC  | Seconds of longitude at exact sighting position. CETAP only.                      | S_LONG                                              |
| CETSPPCD | Legacy dBASE name for the species code field.                                     | SPECCODE                                            |
| DEBRIS   | CETAP code for debris/pollution observations.                                     | SPECCODE with TAXCODE=0                             |
| HUMANACT | CETAP code for human activities observed.                                         | SPECCODE with TAXCODE=0                             |
| OLDVIZ   | Legacy one-digit visibility condition code (values −1 to −5).                     | VISIBLTY (negative values, historical records only) |
| WTEMP    | CETAP name for sea-surface temperature.                                           | SURFTEMP                                            |

Additional retired fields are documented in Part C of the reference PDF. The fields above are those with confirmed CETAP provenance or direct successors in the current schema.

### 7.1 Synthetic Variables (Part B)

The following variables are computed on demand from database fields by SAS macros and are not stored in the database. They appear in data deliveries but must not be submitted as input data: CALF, CANADA, DEAD, FEED, FISHING, GEAR, HURT, ID, JDATE, JELL, MILL, POOP, SAG, SEASON, SPECNAME, STRK, TAXTYPE, TYPE, WAKE, WHLR.
