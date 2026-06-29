/*
 * truncate_master.sql
 *
 * Purpose:    Wipe all survey data from Master while keeping the schema and
 *             lookup tables intact.
 * Depends on: 02_create_master_table.sql
 * Reversal:   Re-run the migration pipeline to reload data.
 * Last modified: 2026-06-26
 *
 * Useful for repeat migration testing: drop all loaded surveys and start fresh
 * without having to recreate the schema or repopulate lookup tables.
 *
 * TRUNCATE is not transactional in SQL Server in the same way DELETE is, but
 * it is logged and can be rolled back within an explicit transaction.
 */

USE NARWC;
GO

BEGIN TRANSACTION;

    TRUNCATE TABLE Master;
    PRINT 'Master truncated.';

-- Review row count is 0, then COMMIT:
-- SELECT COUNT(*) AS remaining_rows FROM Master;
-- COMMIT;
-- ROLLBACK;
