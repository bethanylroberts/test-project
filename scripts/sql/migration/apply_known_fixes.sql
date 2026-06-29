/*
 * apply_known_fixes.sql
 *
 * Purpose:    Apply Category C known data-quality corrections to Master in-place.
 *             These are corrections for legitimate historical data issues, not bugs
 *             in the pipeline. Each block is labeled with a fix number, description,
 *             rationale, and affected surveys.
 * Depends on: Master table populated.
 * Reversal:   No automatic reversal; take a backup before running. The corrections
 *             are deterministic but not easily reversible without the original data.
 * Last modified: 2026-06-26
 *
 * This is the SQL counterpart to src/+migration/apply_known_fixes.m.
 * The MATLAB function applies these corrections to the CSV staging area before upload;
 * this SQL script applies them post-upload if a survey is already in Master.
 * Generally prefer the MATLAB path; this script exists for in-place correction.
 *
 * Keep this file in sync with apply_known_fixes.m. Add a parallel block to both
 * when a new Category C fix is identified.
 *
 * All fixes are wrapped in a single transaction. Review the PRINT output before
 * committing.
 */

USE NARWC;
GO

BEGIN TRANSACTION;

-- ── Fix 1: PHOTOS=0 → 1 (Bob's macro mirror issue) ───────────────────────────
-- Many legacy surveys recorded PHOTOS=0, which is not a valid PHOTOS code (valid
-- values start at 1). Bob's original macro used 0 as a "no photos" sentinel before
-- the code table was standardized. Map 0 → 1 ("NO") only for sighting rows
-- (SPECCODE IS NOT NULL), not for effort-only rows.
UPDATE Master
    SET PHOTOS = 1
WHERE PHOTOS = 0
  AND SPECCODE IS NOT NULL;
PRINT CONCAT('Fix 1 (PHOTOS 0→1): ', @@ROWCOUNT, ' row(s) updated.');

-- ── Fix 2: STRIP > 16 → NULL for NEAq 2021 surveys ───────────────────────────
-- NEAq 2021 aerial surveys (FILEID LIKE 'a121%') used a non-standard strip
-- numbering convention that exceeded the defined range (1-16). These values are
-- not meaningful under the standard lookup and should be treated as missing.
UPDATE Master
    SET STRIP = NULL
WHERE STRIP > 16
  AND FILEID LIKE N'a121%';
PRINT CONCAT('Fix 2 (STRIP>16 NEAq 2021): ', @@ROWCOUNT, ' row(s) updated.');

-- ── Fix 3: BEAUFORT = 99 → NULL (placeholder sentinel) ───────────────────────
-- A handful of surveys used 99 as a "not recorded" sentinel for BEAUFORT before
-- the pipeline normalized missing values. 99 is not a valid Beaufort value (0-9).
UPDATE Master
    SET BEAUFORT = NULL
WHERE BEAUFORT = 99;
PRINT CONCAT('Fix 3 (BEAUFORT 99→NULL): ', @@ROWCOUNT, ' row(s) updated.');

-- ── Fix 4: CLOUD = 99 → NULL (placeholder sentinel) ──────────────────────────
-- Same sentinel pattern as Fix 3, applied to CLOUD (valid range 0-10).
UPDATE Master
    SET CLOUD = NULL
WHERE CLOUD = 99;
PRINT CONCAT('Fix 4 (CLOUD 99→NULL): ', @@ROWCOUNT, ' row(s) updated.');

-- ── Fix 5: GLAREL / GLARER = 99 → NULL ───────────────────────────────────────
UPDATE Master
    SET GLAREL = NULL
WHERE GLAREL = 99;
PRINT CONCAT('Fix 5a (GLAREL 99→NULL): ', @@ROWCOUNT, ' row(s) updated.');

UPDATE Master
    SET GLARER = NULL
WHERE GLARER = 99;
PRINT CONCAT('Fix 5b (GLARER 99→NULL): ', @@ROWCOUNT, ' row(s) updated.');

-- ── Fix 6: NUMCALF = 99 → NULL (data entry artifact) ─────────────────────────
-- 99 calves is not a plausible count and was used as a "not recorded" marker
-- in some early data entry. Normalize to NULL.
UPDATE Master
    SET NUMCALF = NULL
WHERE NUMCALF = 99;
PRINT CONCAT('Fix 6 (NUMCALF 99→NULL): ', @@ROWCOUNT, ' row(s) updated.');

-- ── Fix 7: Normalize SPECCODE trailing whitespace ─────────────────────────────
-- Some legacy files have SPECCODE values with trailing spaces (e.g., 'RIWH ')
-- that do not match the lookup table ('RIWH'). Trim in-place.
UPDATE Master
    SET SPECCODE = RTRIM(SPECCODE)
WHERE SPECCODE <> RTRIM(SPECCODE);
PRINT CONCAT('Fix 7 (SPECCODE trim): ', @@ROWCOUNT, ' row(s) updated.');

-- ── Fix 8: LEGTYPE = 99 → NULL ────────────────────────────────────────────────
-- Same sentinel pattern as BEAUFORT/CLOUD/GLARE, applied to LEGTYPE.
UPDATE Master
    SET LEGTYPE = NULL
WHERE LEGTYPE = 99;
PRINT CONCAT('Fix 8 (LEGTYPE 99→NULL): ', @@ROWCOUNT, ' row(s) updated.');

-- Review PRINT output above, then COMMIT or ROLLBACK:
-- COMMIT;
-- ROLLBACK;
