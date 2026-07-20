/*
 * count_by_species.sql
 *
 * Purpose:    Row counts per species code, most frequent first.
 * Depends on: Master table populated.
 * Last modified: 2026-06-26
 *
 * Sanity check on species distribution. Right whale (RIWH) should dominate.
 * Unexpectedly absent codes may indicate a SPECCODE parsing issue.
 */

USE NARWC;
GO

SELECT
    SPECCODE,
    COUNT(*) AS row_count
FROM Master
GROUP BY SPECCODE
ORDER BY COUNT(*) DESC;
