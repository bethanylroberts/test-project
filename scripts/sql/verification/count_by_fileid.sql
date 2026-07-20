/*
 * count_by_fileid.sql
 *
 * Purpose:    Row counts per survey file, ordered by FILEID.
 * Depends on: Master table populated.
 * Last modified: 2026-06-26
 *
 * Compare output against expected counts in the migration _split_summary.txt
 * file to verify all records were loaded for each survey.
 */

USE NARWC;
GO

SELECT
    FILEID,
    COUNT(*) AS row_count
FROM Master
GROUP BY FILEID
ORDER BY FILEID;
