/*
 * delete_survey.sql
 *
 * Purpose:    Delete all records for a single survey from Master.
 *             Used when re-running a survey after corrections or when
 *             a survey was uploaded in error.
 * Depends on: Master table populated.
 * Reversal:   Re-run the migration pipeline for the affected FILEID.
 * Last modified: 2026-06-26
 *
 * Instructions:
 *   1. Set @fileid to the target survey identifier.
 *   2. Run the script up through the DELETE.
 *   3. Review the printed row count.
 *   4. COMMIT if the count matches expectations; ROLLBACK otherwise.
 */

USE NARWC;
GO

DECLARE @fileid NVARCHAR(20) = N'PLACEHOLDER';   -- <FILL_IN> e.g. N'f098027'

BEGIN TRANSACTION;

    DELETE FROM Master
    WHERE FILEID = @fileid;

    DECLARE @deleted INT = @@ROWCOUNT;
    PRINT CONCAT('Deleted ', @deleted, ' row(s) for FILEID = ', @fileid);

-- Review @deleted. If correct, COMMIT; otherwise ROLLBACK.
-- COMMIT;
-- ROLLBACK;
