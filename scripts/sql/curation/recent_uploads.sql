/*
 * recent_uploads.sql
 *
 * Purpose:    List the most recently uploaded surveys.
 * Depends on: Master table with an uploaded_at column.
 * Last modified: 2026-06-26
 *
 * TODO: This query requires an uploaded_at column that Master does NOT
 *       currently have. To enable it:
 *         1. Add the column to 02_create_master_table.sql:
 *              uploaded_at DATETIME NOT NULL DEFAULT GETDATE()
 *         2. Apply to an existing table with:
 *              ALTER TABLE Master ADD uploaded_at DATETIME NOT NULL DEFAULT GETDATE();
 *            Note: DEFAULT GETDATE() will set all existing rows to the current
 *            timestamp at ALTER time, not their original upload time — this only
 *            becomes meaningful for rows inserted after the column is added.
 *
 * Placeholder query (will error until uploaded_at is added):
 *
 *   DECLARE @n INT = 20;   -- number of recent FILEIDs to return
 *
 *   SELECT TOP (@n)
 *       FILEID,
 *       MIN(uploaded_at) AS first_uploaded,
 *       COUNT(*)         AS row_count
 *   FROM Master
 *   GROUP BY FILEID
 *   ORDER BY MIN(uploaded_at) DESC;
 */
