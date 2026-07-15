/*
 * find_duplicates.sql
 *
 * Purpose:    Find (FILEID, EVENTNO) pairs that appear more than once in Master.
 * Depends on: Master table populated.
 * Last modified: 2026-06-26
 *
 * (FILEID, EVENTNO) is the canonical "duplicate" signal — it is the composite
 * primary key and should be unique. If this query returns rows, the upload
 * pipeline allowed duplicates past the PK constraint, which should not happen
 * under normal operation.
 *
 * Note from ChkDupes.sas context: EVENTNO duplicates within a file are allowed
 * only if all metadata fields match exactly (they represent the same observation
 * recorded twice). The PK constraint here is stricter; any hit is worth
 * investigating.
 */

USE NARWC;
GO

SELECT
    FILEID,
    EVENTNO,
    COUNT(*) AS occurrence_count
FROM Master
GROUP BY FILEID, EVENTNO
HAVING COUNT(*) > 1
ORDER BY FILEID, EVENTNO;
