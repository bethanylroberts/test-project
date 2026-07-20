/*
 * 05_add_foreign_keys.sql
 *
 * Purpose:    Add FOREIGN KEY constraints from Master to all lookup tables.
 *             This file is sequenced after both the Master table and the lookup
 *             tables exist. It cannot live in 02 (lookup tables not yet created)
 *             or in 03 (Master may not yet exist).
 * Depends on: 01_create_database.sql, 02_create_master_table.sql,
 *             03_create_lookup_tables.sql.
 *             04_create_indexes.sql is optional but recommended first:
 *             FK validation scans the referenced table, and indexes speed that up.
 * Reversal:
 *   DECLARE @sql nvarchar(max) = '';
 *   SELECT @sql = @sql + 'ALTER TABLE Master DROP CONSTRAINT '
 *       + QUOTENAME(name) + ';' + CHAR(13)
 *   FROM sys.foreign_keys WHERE parent_object_id = OBJECT_ID('Master');
 *   EXEC sp_executesql @sql;
 * Last modified: 2026-06-26
 *
 * WITH CHECK (default) verifies existing rows against lookup table values.
 * MATLAB validation rejects invalid codes before upload, so CHECK is safe.
 * If a constraint fails on an existing database, investigate the offending
 * rows before switching to WITH NOCHECK.
 *
 * FKs are added idempotently: each ALTER TABLE is wrapped in an existence
 * check so re-running the script is safe.
 *
 * Total FK constraints: 35
 *   ANHEAD(1), BEAUFORT(1), BEHAV1-15(15), BLOCK(1), CLOUD(1),
 *   CONFIDNC(1), DDSOURCE(1), GLAREL(1), GLARER(1), IDREL(1),
 *   IDSOURCE(1), LEGSTAGE(1), LEGTYPE(1), MONTH(1), PHOTOS(1), PLATFORM(1),
 *   SPECCODE(1), STRATUM(1), STRIP(1), TAXCODE(1), WX(1)
 */

USE NARWCDB;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- ── ANHEAD ────────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_ANHEAD'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_ANHEAD
            FOREIGN KEY (ANHEAD) REFERENCES ANHEAD(Value);
        PRINT 'FK FK_Master_ANHEAD added.';
    END

    -- ── BEAUFORT ──────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEAUFORT'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEAUFORT
            FOREIGN KEY (BEAUFORT) REFERENCES Beaufort(Value);
        PRINT 'FK FK_Master_BEAUFORT added.';
    END

    -- ── BEHAV1 - BEHAV15 ──────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV1'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV1
            FOREIGN KEY (BEHAV1) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV1 added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV2'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV2
            FOREIGN KEY (BEHAV2) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV2 added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV3'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV3
            FOREIGN KEY (BEHAV3) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV3 added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV4'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV4
            FOREIGN KEY (BEHAV4) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV4 added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV5'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV5
            FOREIGN KEY (BEHAV5) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV5 added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV6'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV6
            FOREIGN KEY (BEHAV6) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV6 added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV7'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV7
            FOREIGN KEY (BEHAV7) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV7 added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV8'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV8
            FOREIGN KEY (BEHAV8) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV8 added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV9'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV9
            FOREIGN KEY (BEHAV9) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV9 added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV10'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV10
            FOREIGN KEY (BEHAV10) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV10 added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV11'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV11
            FOREIGN KEY (BEHAV11) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV11 added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV12'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV12
            FOREIGN KEY (BEHAV12) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV12 added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV13'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV13
            FOREIGN KEY (BEHAV13) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV13 added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV14'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV14
            FOREIGN KEY (BEHAV14) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV14 added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BEHAV15'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BEHAV15
            FOREIGN KEY (BEHAV15) REFERENCES Behave(Value);
        PRINT 'FK FK_Master_BEHAV15 added.';
    END

    -- ── BLOCK ─────────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_BLOCK'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_BLOCK
            FOREIGN KEY (BLOCK) REFERENCES Block(Value);
        PRINT 'FK FK_Master_BLOCK added.';
    END

    -- ── CLOUD ─────────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_CLOUD'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_CLOUD
            FOREIGN KEY (CLOUD) REFERENCES Cloud(Value);
        PRINT 'FK FK_Master_CLOUD added.';
    END

    -- ── CONFIDNC ──────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_CONFIDNC'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_CONFIDNC
            FOREIGN KEY (CONFIDNC) REFERENCES Confidnc(Value);
        PRINT 'FK FK_Master_CONFIDNC added.';
    END

    -- ── DDSOURCE ──────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_DDSOURCE'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_DDSOURCE
            FOREIGN KEY (DDSOURCE) REFERENCES DDSOURCE(Value);
        PRINT 'FK FK_Master_DDSOURCE added.';
    END

    -- ── GLAREL / GLARER ───────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_GLAREL'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_GLAREL
            FOREIGN KEY (GLAREL) REFERENCES GLARE(Value);
        PRINT 'FK FK_Master_GLAREL added.';
    END

    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_GLARER'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_GLARER
            FOREIGN KEY (GLARER) REFERENCES GLARE(Value);
        PRINT 'FK FK_Master_GLARER added.';
    END

    -- ── IDREL ─────────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_IDREL'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_IDREL
            FOREIGN KEY (IDREL) REFERENCES IDREL(Value);
        PRINT 'FK FK_Master_IDREL added.';
    END

    -- ── IDSOURCE ──────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_IDSOURCE'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_IDSOURCE
            FOREIGN KEY (IDSOURCE) REFERENCES IDSOURCE(Value);
        PRINT 'FK FK_Master_IDSOURCE added.';
    END

    -- ── LEGSTAGE ──────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_LEGSTAGE'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_LEGSTAGE
            FOREIGN KEY (LEGSTAGE) REFERENCES LEGSTAGE(Value);
        PRINT 'FK FK_Master_LEGSTAGE added.';
    END

    -- ── LEGTYPE ───────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_LEGTYPE'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_LEGTYPE
            FOREIGN KEY (LEGTYPE) REFERENCES LEGTYPE(Value);
        PRINT 'FK FK_Master_LEGTYPE added.';
    END

    -- ── MONTH ─────────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_MONTH'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_MONTH
            FOREIGN KEY ([MONTH]) REFERENCES [MONTH](Value);
        PRINT 'FK_Master_MONTH added.';
    END

    -- ── PHOTOS ────────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_PHOTOS'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_PHOTOS
            FOREIGN KEY (PHOTOS) REFERENCES PHOTOS(Value);
        PRINT 'FK FK_Master_PHOTOS added.';
    END

    -- ── PLATFORM ──────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_PLATFORM'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_PLATFORM
            FOREIGN KEY (PLATFORM) REFERENCES PLATFORM(Value);
        PRINT 'FK FK_Master_PLATFORM added.';
    END

    -- ── SPECCODE ──────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_SPECCODE'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_SPECCODE
            FOREIGN KEY (SPECCODE) REFERENCES SPECCODE(Value);
        PRINT 'FK FK_Master_SPECCODE added.';
    END

    -- ── STRATUM ───────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_STRATUM'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_STRATUM
            FOREIGN KEY (STRATUM) REFERENCES STRATUM(Value);
        PRINT 'FK FK_Master_STRATUM added.';
    END

    -- ── STRIP ─────────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_STRIP'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_STRIP
            FOREIGN KEY (STRIP) REFERENCES STRIP(Value);
        PRINT 'FK FK_Master_STRIP added.';
    END

    -- ── TAXCODE ───────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_TAXCODE'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_TAXCODE
            FOREIGN KEY (TAXCODE) REFERENCES TAXCODE(Value);
        PRINT 'FK FK_Master_TAXCODE added.';
    END

    -- ── WX ────────────────────────────────────────────────────────────────────
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_WX'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_WX
            FOREIGN KEY (WX) REFERENCES WX(Value);
        PRINT 'FK FK_Master_WX added.';
    END

    COMMIT TRANSACTION;
    PRINT 'Foreign key constraint creation complete (35 constraints).';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'ERROR adding foreign keys: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO
