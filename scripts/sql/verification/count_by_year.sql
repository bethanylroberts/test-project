/*
 * count_by_year.sql
 *
 * Purpose:    Row counts per year, ordered chronologically.
 * Depends on: Master table populated.
 * Last modified: 2026-06-26
 *
 * Sanity check on year distribution. Gaps or implausible spikes indicate
 * a parsing or migration issue for surveys in that year.
 */

USE NARWC;
GO

SELECT
    YEAR,
    COUNT(*) AS row_count
FROM Master
GROUP BY YEAR
ORDER BY YEAR;
