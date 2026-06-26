# tests/fixtures/sample_data

Test fixture CSV files for the NARWC database unit and integration tests.

## Origin

Fixtures in this directory are derived from real survey CSVs using
`tests/fixtures/anonymize_surveys.m`. Each fixture has had:

- **Coordinates shifted**: a single random offset (±0.1–1.0°) applied uniformly
  to all latitude and longitude fields (`LAT_DD`, `LONG_DD`, `S_LAT`, `S_LONG`).
- **Dates shifted**: a single random offset (±30–365 days) applied to `YEAR`,
  `MONTH`, and `DAY`. Times (`TIME`) are not shifted.
- **FILEID replaced**: the original survey identifier is replaced with a
  computed synthetic identifier (see FILEID convention below).

Species codes, behavior codes, platform codes, counts, and all other fields
are unchanged.

**This data is not real.** Coordinates and dates do not correspond to actual
survey positions or times and must not be treated as such. Do not use these
files for scientific analysis.

The anonymization seed and per-survey offsets are recorded in the manifest
file (kept outside the repository; see `source_list.template.txt` for the
recommended location).

## Test FILEID convention

Test FILEIDs follow the standard 7–8 character NARWC FILEID structure but
with position 2 set to `T`:

| Position | Content                                                  |
| -------- | -------------------------------------------------------- |
| 1        | Preserved from source (survey type + era case)           |
| 2        | `T` — marks this as a test fixture                       |
| 3–4      | Two-digit year of first shifted data date                |
| 5–7      | Julian day of first shifted date (zero-padded)           |
| 8        | Preserved from source (if source FILEID is 8 characters) |

Position 2 = `T` is the canonical marker for synthetic fixture data.
Real contributor codes in the production database never use `T`.
`narwc.ingestion.BatchUploader.uploadSurvey()` rejects any FILEID with position 2 = `T`
before attempting a database write.
