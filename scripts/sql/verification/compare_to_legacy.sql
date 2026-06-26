/*
 * compare_to_legacy.sql
 *
 * Purpose:    Side-by-side comparison between the NARWC database and a
 *             known-good reference source (e.g., Bob's fresh export).
 * Depends on: Master populated; reference source identified.
 * Last modified: 2026-06-26
 *
 * TODO: Draft the actual comparison query once the reference source is identified.
 *
 * Likely approach:
 *   1. Import the legacy CSV (or Bob's export) into a temporary schema,
 *      e.g., CREATE TABLE legacy_compare.Master (...) in a separate database
 *      or a temp table.
 *   2. Row-count comparison per FILEID:
 *        SELECT a.FILEID, a.cnt AS narwc_count, b.cnt AS legacy_count
 *        FROM (SELECT FILEID, COUNT(*) cnt FROM Master GROUP BY FILEID) a
 *        FULL OUTER JOIN
 *             (SELECT FILEID, COUNT(*) cnt FROM legacy_compare.Master GROUP BY FILEID) b
 *          ON a.FILEID = b.FILEID
 *        WHERE a.cnt <> b.cnt OR a.cnt IS NULL OR b.cnt IS NULL;
 *   3. Field-level comparison on key columns for matching (FILEID, EVENTNO) pairs.
 *
 * Do not draft further until the comparison source is confirmed.
 */
