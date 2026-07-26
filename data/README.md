# data/ — Directory Layout

This is the top-level map of `data/`. Almost everything under here is gitignored (runtime/working
data, much of it large or contributor-supplied); this README and `data/tables/` are the two
exceptions kept in version control. See the root `.gitignore` (`data/*` with `!data/tables` /
`!data/README.md` exceptions) if you're adding something new here and need to decide whether it
should be tracked.

```
data/
├── README.md                  # this file (tracked)
├── overrides.example.csv      # template for warning-override CSVs (see docs/warning_overrides.md)
├── tables/                    # lookup-table snapshots, tracked — see data/tables/README.md
├── surveys/                   # one unified ingestion pipeline, every source
│   ├── raw/                    #   untouched originals as delivered, never edited — see below
│   │   ├── legacy/              #     the monolithic legacy CSV (one-time historical migration)
│   │   ├── CCS/                 #     per-contributor raw files, each still in
│   │   ├── NEAQ & CWI (vessels)/ #    its own as-delivered internal layout
│   │   ├── NEAQ Aerial/
│   │   ├── NMFS-NEFSC/
│   │   └── SEUS EWS/
│   ├── pending/                #   convert_contributor_batch output; upload_contributor_batch input
│   ├── processed/               #   successfully uploaded surveys
│   ├── rejected/                #   failed validation/upload
│   ├── skipped/                 #   already existed in the DB, not re-uploaded
│   └── batch_log.csv            #   append-only ledger of every convert/upload/validate run — see below
├── exports/                   # generated reports/exports
└── archives/                  # miscellaneous archived data
```

There's a single pipeline now — **raw source → per-survey split → validate/upload** — for every
source, including the one-time legacy migration: the legacy monolith is just another raw source
(`surveys/raw/legacy/`) that happens to need chunked reading given its size (see CLAUDE.md's
"Ingestion Pipelines" section for the code path). `SurveyFileWriter` does the FILEID-based
splitting for every source; `BatchUploader`/`run_batch_upload` does the validate+upload for every
source, sharing one `data/surveys` base directory. `convert_contributor_batch('legacy', ...)`
dispatches internally to the chunked `SurveyExtractor`; every other contributor dispatches to the
single-pass core conversion path.

Nothing in this pipeline deletes files — `raw/` is never written to after delivery, and moving a
file from `pending/` to `processed/`/`rejected/`/`skipped/` relocates it, it doesn't remove it.
Disk space isn't a constraint here, so both the raw originals and every converted per-survey CSV
stick around indefinitely.

### Batch ledger (`batch_log.csv`)

`raw/` being untouched is exactly what makes it unclear, at a glance, whether a given raw source
has already been converted — there's no moved-file signal the way there is for `pending/`. Every
`convert_contributor_batch` run mints a `batch_id` (`<timestamp>_<source>`, e.g.
`2026-07-26_14-30-12_legacy`) and appends a row to `batch_log.csv`; later `upload_contributor_batch`
and `validate_batch` runs against that batch append their own rows too. This is what:

- Warns you (doesn't block you) if you re-run `convert_contributor_batch` against a raw input
  that's already in the ledger.
- Lets `upload_contributor_batch('BatchId', id)` scope an upload to just one batch's files, even if
  `pending/` currently holds more than one batch's worth.
- Lets `validate_batch` find "the current batch" (most recent `convert` entry, optionally narrowed
  by source) instead of guessing from file-modification times.

It's a plain CSV (`batch_id,stage,source,timestamp,input,output,total_surveys,total_rows,notes`) —
open it directly to see the full history of what's been converted/uploaded/validated and when.

---

## `surveys/raw/` — Untouched source data

This holds raw survey files exactly as delivered — by each contributor, and the legacy monolith
CSV — before any parsing or splitting. **These are untouched originals — never edit them in
place.** Only `legacy/` is wired into the pipeline today via the `StandardFormat` parser;
`convert_contributor_batch.m` expects to find one contributor's raw files at
`data/surveys/raw/<contributor>/` and run them through that contributor's parser, but most
contributor parsers don't exist yet (see "Next steps" below).

Five contributor folders, all still holding their as-delivered internal subfolder structure
(by year, then platform/survey type):

| Folder                  | Formats                                                        | Files | Coverage                               |
| ----------------------- | -------------------------------------------------------------- | ----- | -------------------------------------- |
| `CCS/`                  | csv (data) + docx (per-survey cover sheets)                    | 259   | 2023–2024, Aerial/Vessel/Opportunistic |
| `NEAQ & CWI (vessels)/` | csv (data) + docx (cover sheets + transmittal letters)         | ~93   | Jul–Nov 2023, Jun–Oct 2024, Fundy/GSL  |
| `NEAQ Aerial/`          | csv (data, two schemas per flight) + docx + pdf (cover sheets) | 140   | 2024, "Wind Energy Area 2024" project  |
| `NMFS-NEFSC/`           | xlsx + csv (data) + docx (cover letters)                       | 13    | 2023–2024                              |
| `SEUS EWS/`             | dbf (data) + docx (cover sheets + QAQC notes)                  | 26    | Winter 2021-22, Winter 2022-23         |

None of these folders contain their own consolidated documentation — provenance and methodology
notes are scattered as one docx/pdf per submission (cover sheets, transmittal letters, and, for
SEUS, separate "QAQC Comments" docs). The notes below were synthesized from sampling real files
directly; read the per-file cover sheets for anything not covered here.

### CCS (Center for Coastal Studies)

Subfolders: `2023 Aerial/`, `2023 Vessel/`, `2023 Opportunistic/`, `2024 Aerial/`, `2024 Vessel/`,
`2024 Opportunistic/`. Filenames are numeric survey IDs (`CCS1000.csv`, `SW1359.csv`), not dates.
Almost every csv has a matching `NARWC E- cover sheet (<ID>).docx` (a few mismatches exist — see
quirks below).

**Three distinct schemas, one per platform type** — a single CCS parser won't work across them:

- **Aerial** (`CCS####.csv`): `MONTH,DAY,YEAR,EVENTNO,TIME,LAT_DD,LONG_DD,LEGTYPE,LEGSTAGE,LEGNO,
  ALT,HEADING,SPEED,VISIBLTY,BEAUFORT,CLOUD,GLAREL,GLARER,WX,SIGHTNO,SPECCODE,NUMBER,NUMCALF,
  PHOTOS,IDREL,CONFIDNC,ANHEAD,B1..B15,NOTES,Comment,OBSSIGHT,CLOCK,DISTANCE,RELPOS`. Behavior
  columns are `B1`–`B15` (not `BEHAV1`–`BEHAV15`). Split `MONTH/DAY/YEAR` int columns.
- **Vessel** (`SW####.csv`): same general shape but a single text `DATE` column in `DD-Mon-YY`
  format instead of split M/D/Y, behavior columns named `BEHAV1`–`BEHAV15`, and `DEPTH`/`SURFTEMP`
  in place of `ALT`/`SPEED` (no altitude on a boat).
  - `2024 Vessel/` files (and 2024 Aerial) switched to a **quoted-CSV** style (`"DATE","EVENTNO",...`)
    with an extra leading blank/index column in Aerial's case — 2023 files are unquoted. A csv
    reader needs to tolerate both.
- **Opportunistic**: split `MONTH/DAY/YEAR` like Aerial, but adds a `PLATFORM` code column and
  drops the track-following fields (`LEGTYPE/ALT/HEADING`) since these are one-off sightings, not
  surveyed effort. 2024's folder has a single aggregated annual CSV rather than per-trip files.
  Also contains oddities: `CCSmap23.csv` (just `EVENTNO,LATITUDE,LONGITUDE` — a position-only
  extract) and `CCS985K.csv` (a `EVENTNO,TIME,LAT_DD,LONG_DD,SPEED,KNOTS` speed-log sidecar next to
  the full `CCS985.csv` for the same survey).

**Known quirks**: `2023 Vessel/` has 24 csv but 27 docx — two cover sheets (`SW1356`, `SW1365`)
have no matching data file, plus an extra "Habitat 2023 Season" cover sheet with no data file at
all; one docx/csv pair (`TB032223` vs `TB03222023`) doesn't match on filename.

### NEAQ & CWI (vessels)

New England Aquarium and Canadian Whale Institute's joint vessel program. Organized
`<year>/<region-or-vessel>/` (`Fundy`, `GSL`, and in 2024 specific vessel names like `Fundy - CWI
RHIB`, `GSL - FV Marie Caro`). One csv + one docx cover sheet per survey day, filenames as ISO
dates (`2023-08-27-CWI-V.csv` … `2024-10-01-CWI.csv`), plus one "URI Submission Cover Letter" docx
per batch — a transmittal letter to the URI/NARWC database manager describing methodology
(Mysticetus software, 30-second GPS interval, off-watch handling during high-speed transit).

Schema (consistent across all sampled files): `EVENTNO,MONTH,DAY,YEAR,TIME,LATITUDE,LONGITUDE,
HEADING,LEGTYPE,LEGSTAGE,WX,CLOUD,VISIBLTY,BEAUFORT,SIGHTNO,SPECCODE,IDREL,NUMBER,CONFIDNC,
NUMCALF,ANHEAD,PHOTOS,BEHAV1..BEHAV15,NOTES`. Note `LATITUDE`/`LONGITUDE` (not `LAT_DD`/`LONG_DD`
like most other sources), `EVENTNO` first instead of last-ish, and `BEHAV1..15` naming. Files have
a **UTF-8 BOM** at the start — a naive parser may see a mangled first column name.

### NEAQ Aerial

Single subfolder: `Wind Energy Area 2024/` — one 2024 aerial survey project. Lowercase column
headers, unlike every other contributor.

**Every flight ships two parallel CSV exports of the same data**, confirmed redundant by the cover
sheet text ("dBASE file name: NEAQ-A-20240112_URI / NLPSC441"):

- `NEAQ-A-YYYYMMDD_URI.csv` — full schema including nav/INS engineering fields: `rectype,month,day,
  year,eventno,time,lat,long,heading,alt,legtype,legstage,legno,visiblty,glarel,glarer,beaufort,
  cloud,wx,sightno,anglel,angler,speccode,number,numcalf,anhead,photos,idrel,confidnc,b1..b15,
  block,refno,stratum,utc,radalt,gpsspeed,setalt,setvel,lensfl,ggf,int,gpsq,gpssats,roll,pitch,yaw,
  maghead,notes,edits,glarev,ph_qual,TrackDist`. A few files are missing the trailing `TrackDist`
  column, and one has an extra `distance_col` instead — column set isn't 100% fixed.
- `NLPSC###.csv` — a reduced export of the same flight, dropping the nav-engineering columns and
  adding `stime,slat,slong` instead.

Both docx and pdf cover sheets exist per flight (`CoverSht a1######.pdf` etc. — largely redundant
duplicate documentation). Some flights are split into `_Directed` / `_General` variants for the
same date. **The parser phase needs to pick one canonical CSV schema per flight** (almost
certainly `NEAQ-A-*_URI.csv` — the richer one) rather than ingesting both.

### NMFS-NEFSC

Two kinds of data, and **the schema changed year-over-year** within one of them:

- `<year> JAN-DEC NEFSC Aerial Consortium data.xlsx` (sheet `Sheet1`) — effort/sightings.
  **2023**: `FILEID,DDSOURCE,MONTH,DAY,YEAR,EVENTNO,TIME,LATDEG,LATMIN,LONGDEG,LONGMIN,...`
  (degree/decimal-minute lat-long). **2024**: switched to `PLATFORM,RID,MONTH,DAY,YEAR,TIME,
  EVENTNO,LAT_DD,LONG_DD,...` (decimal degrees, drops FILEID/DDSOURCE). A single parser across
  both years will need to branch on this.
- `<year>-RWSAS-Sightings*.csv` — a completely different, sightings-only reconnaissance/network
  report table (not an effort/track table): `ID,SIGHTTIME,YEAR,MONTH,DAY,NUMBER,LAT,LON,CATEGORY,
  OBSERVER,OBSORG,OBSPLATFORM,REPORTER,REPPLATFORM,REPORG,CERTAINTY,MOMCALF,FEEDING,DEAD,SAG,
  ENTANGLED,DUPLICATE,OOD,OBSERVER_COMMENTS,ACTION`. 2023 has two copies —
  `2023-RWSAS-Sightings V2.csv` and `...(duplicated).csv` — the "(duplicated)" file genuinely
  contains duplicate `ID` rows; treat `V2` as authoritative unless a cover letter says otherwise.
- `<year>-Flights-Summary.xlsx` (sheet **`all fields`**) — a flight log, not sighting data. **The
  real header row is row 2, not row 1** — row 1 comes through as generic `Field1, Field2...` in a
  naive reader.
- `2024/` also has a one-off `June 22nd Aerial Consortium data-updated20250324.xlsx` — a
  late-updated single-day extract, separate from the full-year file.

### SEUS EWS (Southeast US Early Warning System)

By far the largest contributor (682 MB, 100K+ rows per file vs. hundreds–low-thousands elsewhere)
and the only one delivered purely as **dBASE (`.dbf`)** — no csv/xlsx at all. Four regional teams
per season: `FLWS` (Florida), `GAWS` (Georgia), `NCWS` (North Carolina), `SCWS` (South Carolina),
under `Winter 2021-22/` and `Winter 2022-23/`.

Schema (field names truncated to 10 chars, dBASE convention): `FILEID,DDSOURCE,MONTH,DAY,YEAR,
EVENTNO,TIME,LATDEG,LATMIN,LONGDEG,LONGMIN,LEGTYPE,LEGSTAGE,ALT,HEADING,WX,VISIBLTY,BEAUFORT,
CLOUD,GLAREL,GLARER,SIGHTNO,SPECCODE,IDREL,NUMBER,CONFIDNC,NUMCALF,ANHEAD,PHOTOS,BEHAV1..BEHAV15,
COMMENTS,NOTES,RECTYPE`. Degree/decimal-minute lat-long like NMFS's 2023 format. `FILEID`/
`DDSOURCE` are already present in the source file (unusual — most contributors don't supply
these). `RECTYPE` (A–J, S, T) and the split `COMMENTS`+`NOTES` fields are documented in the
per-team cover sheets and are unique to this contributor.

Two files per season have a `v2` sibling (`FLWS2122.dbf`/`FLWS2122v2.dbf`,
`SCWS2223.dbf`/`SCWS23v2.dbf`) — presumably a later revision, but this isn't documented anywhere;
confirm with the cover letter or contributor before treating either as authoritative.

The separate **"QAQC Comments" docx** per team/season (distinct from the cover sheet) documents
specific data-cleaning edits already applied by the contributor (e.g. "HEADING values of 360 were
changed to 0", ascent/descent-rate thresholds) — read these before writing this parser, since they
explain otherwise-odd values in the data.

No `.dbf` reader is available in this MATLAB environment yet — parsing will need a `.dbf` library
(MATLAB's Database Toolbox can read dBASE via `database()`, or convert via `ogr2ogr`/GDAL, which
was used to inspect these files for this README).

### General inconsistencies across all five contributors

- Naming conventions vary per contributor: numeric IDs, ISO dates, compact dates, dBASE-style
  codes — no shared filename convention to parse survey identity from.
- Date representation varies: split `MONTH/DAY/YEAR` ints vs. a single `DD-Mon-YY` text field.
- Lat/long representation varies: decimal degrees (one column each) vs. split
  degrees+decimal-minutes (four columns).
- Column casing varies: NEAQ Aerial is lowercase; everyone else is uppercase.
- Behavior-code columns are named either `B1..B15` or `BEHAV1..BEHAV15` depending on contributor.

None of this needs to be reconciled here — it's exactly what each contributor's parser
(`src/+narwc/+io/+parsers/`) is responsible for normalizing into the canonical schema
(`narwc.db.FieldDefinitions`).

---

## Next steps: writing the parsers

This directory only holds and documents the raw files — no parser reads from these contributor
subfolders under `surveys/raw/` yet.
To add one, follow CLAUDE.md's "Adding a New Contributor Parser": copy
`src/+narwc/+io/+parsers/TemplateFormat.m`, fill in `FIELD_MAPPING` only for columns confirmed
against a real sample file (never invent unconfirmed mappings — see `NEAQFormat.m` for the
pattern of implementing only what's verified), implement `createImportOptions()`/`detectFormat()`
for that contributor's actual layout, and register it in `ParserFactory.getAvailableParsers()`.

A few things the schema notes above imply for that work:

- **CCS and NMFS-NEFSC need more than one parser each** (or a parser that branches internally) —
  CCS by platform type (Aerial/Vessel/Opportunistic), NMFS-NEFSC by year (2023 vs. 2024 schema)
  and by file kind (Aerial Consortium data vs. RWSAS sightings — genuinely different tables).
- **`convert_contributor_batch.m` currently does a flat, non-recursive directory listing**
  (`dir(fullfile(input_dir, '*.csv'))`), so it won't see files nested under these contributors'
  year/platform-type subfolders as-is. Either point `InputDir` at the specific leaf subfolder per
  invocation, or extend the scan to recurse — not yet decided.
  - Since contributor files here don't include their own source/contributor identification, this
    is also where `DDSOURCE`/`PLATFORM`/contributor code will need to be injected by the parser or
    conversion step (from `data/tables/Contrib.csv` / `PLATFORM.csv`), keyed off which subfolder
    the file came from — the source files can't tell you this themselves.
- **NEAQ Aerial**: pick one of the two per-flight CSV schemas (`NEAQ-A-*_URI.csv` recommended —
  richer field set) rather than parsing both.
- **SEUS EWS** needs a `.dbf` reader before anything else can happen.
