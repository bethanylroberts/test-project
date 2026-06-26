/*
 * 04_create_indexes.sql
 *
 * Purpose:    Create non-clustered indexes on Master for common query paths.
 * Depends on: 02_create_master_table.sql (Master must exist).
 *             Run after 03_create_lookup_tables.sql and before or after
 *             05_add_foreign_keys.sql — FKs benefit from existing indexes on
 *             the referenced key columns (FILEID, SPECCODE, PLATFORM, etc.),
 *             so this order is recommended.
 * Reversal:   DROP INDEX IX_Master_<name> ON Master;
 * Last modified: 2026-06-26
 *
 * Master_ID is the clustered primary key — already indexed; omit here.
 * Add more indexes as query patterns emerge. Over-indexing hurts INSERT
 * performance during batch migration; keep this list conservative.
 */

USE NARWCDB;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- ── FILEID (survey-level queries) ──────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.indexes
        WHERE name = N'IX_Master_FILEID' AND object_id = OBJECT_ID('Master')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_Master_FILEID
            ON Master (FILEID ASC);
        PRINT 'Index IX_Master_FILEID created.';
    END

    -- ── YEAR (date-range queries) ──────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.indexes
        WHERE name = N'IX_Master_YEAR' AND object_id = OBJECT_ID('Master')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_Master_YEAR
            ON Master (YEAR ASC);
        PRINT 'Index IX_Master_YEAR created.';
    END

    -- ── SPECCODE (species-level queries) ──────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.indexes
        WHERE name = N'IX_Master_SPECCODE' AND object_id = OBJECT_ID('Master')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_Master_SPECCODE
            ON Master (SPECCODE ASC);
        PRINT 'Index IX_Master_SPECCODE created.';
    END

    -- ── LAT_DD / LONG_DD (bounding-box spatial queries) ───────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.indexes
        WHERE name = N'IX_Master_LAT_LONG' AND object_id = OBJECT_ID('Master')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_Master_LAT_LONG
            ON Master (LAT_DD ASC, LONG_DD ASC);
        PRINT 'Index IX_Master_LAT_LONG created.';
    END

    -- ── PLATFORM (platform-filtered queries) ──────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.indexes
        WHERE name = N'IX_Master_PLATFORM' AND object_id = OBJECT_ID('Master')
    )
    BEGIN
        CREATE NONCLUSTERED INDEX IX_Master_PLATFORM
            ON Master (PLATFORM ASC);
        PRINT 'Index IX_Master_PLATFORM created.';
    END

    COMMIT TRANSACTION;
    PRINT 'Index creation complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'ERROR creating indexes: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO
