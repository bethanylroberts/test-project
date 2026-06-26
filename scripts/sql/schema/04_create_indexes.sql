/*
 * 04_create_indexes.sql
 *
 * Purpose:    Create non-clustered indexes on Master for common query paths.
 * Depends on: 02_create_master_table.sql
 * Reversal:   DROP INDEX IX_Master_<name> ON Master;
 * Last modified: 2026-06-26
 *
 * (FILEID, EVENTNO) is already the clustered primary key — no additional index needed.
 * Add indexes here as query patterns emerge. Over-indexing hurts INSERT/UPDATE
 * performance during batch migration; keep this list conservative until production
 * query shapes are known.
 */

USE NARWC;
GO

-- ── Year (date-range queries) ──────────────────────────────────────────────────
IF NOT EXISTS (
    SELECT * FROM sys.indexes
    WHERE name = N'IX_Master_YEAR' AND object_id = OBJECT_ID('Master')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Master_YEAR
        ON Master (YEAR ASC);
    PRINT 'Index IX_Master_YEAR created.';
END
GO

-- ── Species (species-level queries) ───────────────────────────────────────────
IF NOT EXISTS (
    SELECT * FROM sys.indexes
    WHERE name = N'IX_Master_SPECCODE' AND object_id = OBJECT_ID('Master')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Master_SPECCODE
        ON Master (SPECCODE ASC);
    PRINT 'Index IX_Master_SPECCODE created.';
END
GO

-- ── Spatial (lat/long bounding-box queries) ────────────────────────────────────
-- Composite index on (LAT_DD, LONG_DD) supports bounding-box WHERE clauses.
-- For true spatial queries, consider SQL Server spatial types in a future migration.
IF NOT EXISTS (
    SELECT * FROM sys.indexes
    WHERE name = N'IX_Master_LAT_LONG' AND object_id = OBJECT_ID('Master')
)
BEGIN
    CREATE NONCLUSTERED INDEX IX_Master_LAT_LONG
        ON Master (LAT_DD ASC, LONG_DD ASC);
    PRINT 'Index IX_Master_LAT_LONG created.';
END
GO
