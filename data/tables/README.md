# data/tables — Lookup Table Snapshots

These CSV files are snapshots exported from the production SQL database via
`scripts/setup/pull_lookup_tables.m`. They are committed to the repository
to enable validation-rule development and testing on machines that do not have
direct database access.

**The production database is authoritative.** These files may drift from the
live DB as codes are added or retired. Refresh them by running
`pull_lookup_tables.m` (database → CSV direction).

## Files

| File            | Constrains field(s) | Notes                                               |
| --------------- | ------------------- | --------------------------------------------------- |
| ANHEAD.csv      | ANHEAD              | Compass heading quadrants (0–22) with degree ranges |
| Beaufort.csv    | BEAUFORT            | Sea-state scale 0–12 with wind/wave descriptions    |
| Behave.csv      | BEHAV1–BEHAV15      | Behavior codes                                      |
| Block.csv       | BLOCK               | Survey block identifiers                            |
| Cloud.csv       | CLOUD               | Cloud-cover categories (0–8)                        |
| Confidnc.csv    | CONFIDNC            | Sighting confidence levels                          |
| Contrib.csv     | (contributor codes) | Data-contributor lookup                             |
| DDSOURCE.csv    | DDSOURCE            | Data-delivery source codes                          |
| DType.csv       | (survey type)       | Survey type codes (A/F/H/O)                         |
| GLARE.csv       | GLAREL, GLARER      | Glare severity (0–3)                                |
| IDREL.csv       | IDREL               | Identification reliability                          |
| IDSOURCE.csv    | IDSOURCE            | Identification source codes                         |
| LEGGOOD.csv     | (leg quality flag)  | Whether a leg is usable                             |
| LEGSTAGE.csv    | LEGSTAGE            | Leg-stage codes                                     |
| LEGTYPE.csv     | LEGTYPE             | Leg-type codes                                      |
| MONTH.csv       | MONTH               | Month names for display                             |
| OLDVIZ.csv      | (legacy visibility) | Legacy visibility scale — superseded by VISIBLTY    |
| PHOTOS.csv      | PHOTOS              | Photo-type codes                                    |
| PLATFORM.csv    | PLATFORM            | Vessel/aircraft platform codes                      |
| SPECCODE.csv    | SPECCODE            | Species codes with taxonomic group and TAXCODE      |
| STRATUM.csv     | STRATUM             | Survey stratum identifiers                          |
| STRIP.csv       | STRIP               | Strip-transect width codes                          |
| sysdiagrams.csv | —                   | SQL Server system table snapshot; no validation use |
| TAXCODE.csv     | TAXCODE             | Taxonomic-group codes                               |
| WX.csv          | WX                  | Weather codes                                       |

**`contributor_defaults.csv` is not a DB snapshot** — unlike everything else in this table, it's
hand-curated ingestion config (contributor + raw-file-subfolder → DDSOURCE/IDSOURCE/PLATFORM
defaults), sourced from real contributor cover sheets rather than `pull_lookup_tables.m`. Edit it
directly; `push_lookup_tables.m`/`pull_lookup_tables.m` don't touch it. See `data/README.md` and
`narwc.ingestion.lookup_contributor_defaults`.