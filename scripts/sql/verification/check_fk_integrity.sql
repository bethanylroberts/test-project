/*
 * check_fk_integrity.sql
 *
 * Purpose:    Verify referential integrity for FK-relevant fields in Master.
 *             Each query returns rows where Master contains a value not present
 *             in the corresponding lookup table. A clean migration returns 0 rows
 *             for all queries.
 * Depends on: Master and lookup tables populated.
 * Last modified: 2026-06-26
 *
 * This is the DB-side counterpart to src/+narwc/+validation/+rules/foreign_key_rules.m.
 * MATLAB enforces these rules during validation; this script confirms nothing
 * slipped through after upload.
 *
 * NULL values in Master are excluded from each check (NULL is always valid for
 * optional fields).
 */

USE NARWC;
GO

-- ── SPECCODE ──────────────────────────────────────────────────────────────────
SELECT 'SPECCODE' AS field, FILEID, EVENTNO, SPECCODE AS bad_value
FROM Master
WHERE SPECCODE IS NOT NULL
  AND SPECCODE NOT IN (SELECT Value FROM SPECCODE);

-- ── PLATFORM ──────────────────────────────────────────────────────────────────
SELECT 'PLATFORM' AS field, FILEID, EVENTNO, CAST(PLATFORM AS NVARCHAR) AS bad_value
FROM Master
WHERE PLATFORM IS NOT NULL
  AND PLATFORM NOT IN (SELECT Value FROM PLATFORM);

-- ── BEHAV1 ────────────────────────────────────────────────────────────────────
SELECT 'BEHAV1' AS field, FILEID, EVENTNO, CAST(BEHAV1 AS NVARCHAR) AS bad_value
FROM Master
WHERE BEHAV1 IS NOT NULL
  AND BEHAV1 NOT IN (SELECT Value FROM Behave);

-- ── BEHAV2 ────────────────────────────────────────────────────────────────────
SELECT 'BEHAV2' AS field, FILEID, EVENTNO, CAST(BEHAV2 AS NVARCHAR) AS bad_value
FROM Master
WHERE BEHAV2 IS NOT NULL
  AND BEHAV2 NOT IN (SELECT Value FROM Behave);

-- ── BEHAV3 ────────────────────────────────────────────────────────────────────
SELECT 'BEHAV3' AS field, FILEID, EVENTNO, CAST(BEHAV3 AS NVARCHAR) AS bad_value
FROM Master
WHERE BEHAV3 IS NOT NULL
  AND BEHAV3 NOT IN (SELECT Value FROM Behave);

-- ── BEHAV4 through BEHAV15 (abbreviated — expand as needed) ──────────────────
SELECT 'BEHAV4-15' AS field, FILEID, EVENTNO,
       COALESCE(CAST(BEHAV4 AS NVARCHAR), CAST(BEHAV5 AS NVARCHAR),
                CAST(BEHAV6 AS NVARCHAR), CAST(BEHAV7 AS NVARCHAR),
                CAST(BEHAV8 AS NVARCHAR), CAST(BEHAV9 AS NVARCHAR),
                CAST(BEHAV10 AS NVARCHAR), CAST(BEHAV11 AS NVARCHAR),
                CAST(BEHAV12 AS NVARCHAR), CAST(BEHAV13 AS NVARCHAR),
                CAST(BEHAV14 AS NVARCHAR), CAST(BEHAV15 AS NVARCHAR)) AS bad_value
FROM Master
WHERE (BEHAV4  IS NOT NULL AND BEHAV4  NOT IN (SELECT Value FROM Behave))
   OR (BEHAV5  IS NOT NULL AND BEHAV5  NOT IN (SELECT Value FROM Behave))
   OR (BEHAV6  IS NOT NULL AND BEHAV6  NOT IN (SELECT Value FROM Behave))
   OR (BEHAV7  IS NOT NULL AND BEHAV7  NOT IN (SELECT Value FROM Behave))
   OR (BEHAV8  IS NOT NULL AND BEHAV8  NOT IN (SELECT Value FROM Behave))
   OR (BEHAV9  IS NOT NULL AND BEHAV9  NOT IN (SELECT Value FROM Behave))
   OR (BEHAV10 IS NOT NULL AND BEHAV10 NOT IN (SELECT Value FROM Behave))
   OR (BEHAV11 IS NOT NULL AND BEHAV11 NOT IN (SELECT Value FROM Behave))
   OR (BEHAV12 IS NOT NULL AND BEHAV12 NOT IN (SELECT Value FROM Behave))
   OR (BEHAV13 IS NOT NULL AND BEHAV13 NOT IN (SELECT Value FROM Behave))
   OR (BEHAV14 IS NOT NULL AND BEHAV14 NOT IN (SELECT Value FROM Behave))
   OR (BEHAV15 IS NOT NULL AND BEHAV15 NOT IN (SELECT Value FROM Behave));

-- ── BLOCK ─────────────────────────────────────────────────────────────────────
SELECT 'BLOCK' AS field, FILEID, EVENTNO, BLOCK AS bad_value
FROM Master
WHERE BLOCK IS NOT NULL
  AND TRY_CAST(BLOCK AS INT) NOT IN (SELECT Value FROM Block);

-- ── ANHEAD ────────────────────────────────────────────────────────────────────
SELECT 'ANHEAD' AS field, FILEID, EVENTNO, CAST(ANHEAD AS NVARCHAR) AS bad_value
FROM Master
WHERE ANHEAD IS NOT NULL
  AND ANHEAD NOT IN (SELECT Value FROM ANHEAD);

-- ── DDSOURCE ──────────────────────────────────────────────────────────────────
SELECT 'DDSOURCE' AS field, FILEID, EVENTNO, DDSOURCE AS bad_value
FROM Master
WHERE DDSOURCE IS NOT NULL
  AND DDSOURCE NOT IN (SELECT Value FROM DDSOURCE);

-- ── IDSOURCE ──────────────────────────────────────────────────────────────────
SELECT 'IDSOURCE' AS field, FILEID, EVENTNO, IDSOURCE AS bad_value
FROM Master
WHERE IDSOURCE IS NOT NULL
  AND IDSOURCE NOT IN (SELECT Value FROM IDSOURCE);

-- ── TAXCODE ───────────────────────────────────────────────────────────────────
SELECT 'TAXCODE' AS field, FILEID, EVENTNO, CAST(TAXCODE AS NVARCHAR) AS bad_value
FROM Master
WHERE TAXCODE IS NOT NULL
  AND TAXCODE NOT IN (SELECT Value FROM TAXCODE);

-- ── WX ────────────────────────────────────────────────────────────────────────
SELECT 'WX' AS field, FILEID, EVENTNO, WX AS bad_value
FROM Master
WHERE WX IS NOT NULL
  AND WX NOT IN (SELECT Value FROM WX);
