# Known Fixes — Category C Data Corrections

Category C corrections handle legitimate historical data-entry artifacts in the NARWC legacy database. These are not bugs in the pipeline; they are patterns that arose from evolving data-entry conventions, macro behavior, and sentinel values used before the current schema was standardised. The corrections are applied programmatically to each survey's CSV data before validation and upload.

**Primary path:** `src/+migration/apply_known_fixes.m`

**Fallback (post-upload):** `scripts/sql/migration/apply_known_fixes.sql`

Both files implement the same eight fixes. Keep them in sync when adding new corrections.

---

## Fix 1 — PHOTOS = 0 → 1 (sighting rows only)

**Rationale:** Bob's original data-entry macro recorded `PHOTOS = 0` as "no photos taken" before the PHOTOS code table was standardised. The lookup table now uses `1` for "no photos" (code `NO`). The value `0` does not appear in the lookup table and will fail FK validation.

**Effect:** For any row where `SPECCODE` is non-empty (a sighting event, not a pure-effort row) and `PHOTOS = 0`, sets `PHOTOS = 1`.

**Curator action if unwanted:** If a future survey legitimately records `PHOTOS = 0` (which is not a valid code), this fix will normalize it to `1`. Flag in code review and add an exception check keyed on FILEID if needed.

---

## Fix 2 — STRIP > 16 → NULL (NEAq 2021 only)

**Rationale:** Surveys with FILEID matching `a121*` (NEAq 2021 aerial surveys) used a non-standard strip-transect numbering convention that exceeded the defined range of 1–16. These values are not meaningful under the standard lookup and will fail range validation.

**Effect:** For surveys matching `FILEID LIKE 'a121%'`, any `STRIP` value greater than 16 is replaced with `NaN` (NULL in the database).

**Curator action if unwanted:** The fix is gated entirely on the `a121*` FILEID prefix. Surveys from other programs are never affected. To expand the prefix list, add a check in `apply_known_fixes.m` and a parallel block in the SQL script.

---

## Fix 3 — BEAUFORT = 99 → NULL

**Rationale:** A handful of surveys used `99` as a "not recorded" sentinel for BEAUFORT before the pipeline normalised missing values. Beaufort scale values range from 0–9 (or 0–12 in the full scale); `99` is not a valid entry.

**Effect:** Replaces `BEAUFORT = 99` with `NaN`.

---

## Fix 4 — CLOUD = 99 → NULL

**Rationale:** Same sentinel pattern as Fix 3. Valid CLOUD values are 0–10 (oktas); `99` was used as "not recorded".

**Effect:** Replaces `CLOUD = 99` with `NaN`.

---

## Fix 5 — GLAREL / GLARER = 99 → NULL

**Rationale:** Same sentinel pattern. Valid glare codes are 0–3; `9` (and by extension `99`) was used in some early files as "not recorded". The glossary notes that GLARE code `9` is a known legacy sentinel.

**Effect:** Replaces `GLAREL = 99` and `GLARER = 99` with `NaN`. The two sides are tracked separately in the fix report.

---

## Fix 6 — NUMCALF = 99 → NULL

**Rationale:** Ninety-nine calves is not a plausible sighting count and was used as a "not recorded" marker in early data entry. This will trigger a group-size warning under current validation thresholds.

**Effect:** Replaces `NUMCALF = 99` with `NaN`.

---

## Fix 7 — SPECCODE trailing whitespace trim

**Rationale:** Some legacy files have SPECCODE values with trailing spaces (e.g., `'RIWH '`). These do not match the lookup table entry `'RIWH'` and will fail FK validation.

**Effect:** Calls `strtrim` on all non-empty SPECCODE values. Only rows where the value actually changes are counted in the report.

**Curator action if unwanted:** Trimming is a safe normalisation — no information is lost. There is no scenario where a species code with trailing whitespace is intentional.

---

## Fix 8 — LEGTYPE = 99 → NULL

**Rationale:** Same sentinel pattern as BEAUFORT/CLOUD/GLARE. LEGTYPE is an FK-constrained field; `99` is not a valid code.

**Effect:** Replaces `LEGTYPE = 99` with `NaN`.

---

## Run summary output

At the end of each upload run, the `_errors.log` file includes a **Known Fixes Applied** section with per-fix row counts aggregated across all surveys processed:

```
=== Known Fixes Applied ===
PHOTOS = 0 -> 1 (sighting rows): 47 rows across 12 survey(s)
STRIP > 16 -> NULL (NEAq 2021): 18 rows across 2 survey(s)
BEAUFORT = 99 -> NULL: 23 rows across 9 survey(s)
CLOUD = 99 -> NULL: 11 rows across 4 survey(s)
GLAREL = 99 -> NULL: 8 rows across 6 survey(s)
GLARER = 99 -> NULL: 8 rows across 6 survey(s)
NUMCALF = 99 -> NULL: 4 rows across 2 survey(s)
SPECCODE trailing whitespace trim: 156 rows across 31 survey(s)
LEGTYPE = 99 -> NULL: 0 rows
```

Fixes with zero matches are included so future readers know each fix was active.

---

## Adding new fixes

1. Add a block to `src/+migration/apply_known_fixes.m` with a `report.<name>` field.
2. Add an equivalent `UPDATE` block to `scripts/sql/migration/apply_known_fixes.sql`.
3. Add the `report.<name>` field to `resetStats()` in `BatchUploader.m` (both `fix_totals` and `fix_survey_counts`).
4. Add a `fix_summary_line(...)` call to `writeErrorSummary()` in `BatchUploader.m`.
5. Add a label entry to `format_fix_summary()` in `BatchUploader.m`.
6. Add positive and negative test cases to `tests/unit/test_apply_known_fixes.m`.
