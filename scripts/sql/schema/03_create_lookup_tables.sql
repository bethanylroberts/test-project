/*
 * 03_create_lookup_tables.sql
 *
 * Purpose:    Create all 23 lookup tables referenced by the Master table.
 *             Table structures are derived from the recovered 2025-06-16 SSMS
 *             export, with corrected Value column types, PRIMARY KEY on each
 *             Value, and sane varchar widths sized to actual CSV data.
 * Depends on: 01_create_database.sql (NARWCDB must exist).
 * Reversal:   Must run 05_add_foreign_keys.sql reversal first to drop FKs,
 *             then: DROP TABLE <TableName>; for each table listed below.
 * Last modified: 2026-06-26
 *
 * Value column types are chosen to match Master column types exactly so that
 * FK constraints in 05_add_foreign_keys.sql will succeed without implicit
 * conversion. See the Master column type table in 02_create_master_table.sql.
 *
 * Description widths are standardized to varchar(255) for short text.
 * Beaufort uses varchar(500) because entries can exceed 300 characters.
 * Block uses varchar(255); longest observed description is ~115 characters.
 *
 * Tables not FK'd from Master (Contrib, DType, LEGGOOD, OLDVIZ) are included
 * because they exist in the legacy database and may be referenced externally.
 */

USE NARWCDB;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- ── ANHEAD ────────────────────────────────────────────────────────────────
    -- Value type varchar(4) matches Master.ANHEAD
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'ANHEAD' AND type = 'U')
    BEGIN
        CREATE TABLE ANHEAD (
            Value       varchar(4)      NOT NULL,
            Direction   varchar(50)     NULL,       -- compass direction label (e.g., "NNE")
            LowDeg      numeric(18,0)   NULL,       -- low end of degree range
            HighDeg     numeric(18,0)   NULL,       -- high end of degree range
            CONSTRAINT PK_ANHEAD PRIMARY KEY (Value)
        );
        PRINT 'Table ANHEAD created.';
    END

    -- ── Beaufort ──────────────────────────────────────────────────────────────
    -- Value type varchar(4) matches Master.BEAUFORT
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'Beaufort' AND type = 'U')
    BEGIN
        CREATE TABLE Beaufort (
            Value       varchar(4)      NOT NULL,
            lWind       int             NULL,       -- lower wind speed bound (knots)
            hWind       int             NULL,       -- upper wind speed bound (knots)
            Waves       numeric(18,2)   NULL,       -- typical wave height (meters)
            Description varchar(500)    NULL,       -- 500 chars; Beaufort descriptions exceed 255
            CONSTRAINT PK_Beaufort PRIMARY KEY (Value)
        );
        PRINT 'Table Beaufort created.';
    END

    -- ── Behave ────────────────────────────────────────────────────────────────
    -- Value type varchar(4) matches Master.BEHAV1-15
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'Behave' AND type = 'U')
    BEGIN
        CREATE TABLE Behave (
            Value       varchar(4)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_Behave PRIMARY KEY (Value)
        );
        PRINT 'Table Behave created.';
    END

    -- ── Block ─────────────────────────────────────────────────────────────────
    -- Value type varchar(4) matches Master.BLOCK
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'Block' AND type = 'U')
    BEGIN
        CREATE TABLE Block (
            Value       varchar(4)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_Block PRIMARY KEY (Value)
        );
        PRINT 'Table Block created.';
    END

    -- ── Cloud ─────────────────────────────────────────────────────────────────
    -- Value type int matches Master.CLOUD
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'Cloud' AND type = 'U')
    BEGIN
        CREATE TABLE Cloud (
            Value       int             NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_Cloud PRIMARY KEY (Value)
        );
        PRINT 'Table Cloud created.';
    END

    -- ── Confidnc ──────────────────────────────────────────────────────────────
    -- Value type int matches Master.CONFIDNC
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'Confidnc' AND type = 'U')
    BEGIN
        CREATE TABLE Confidnc (
            Value       int             NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_Confidnc PRIMARY KEY (Value)
        );
        PRINT 'Table Confidnc created.';
    END

    -- ── Contrib ───────────────────────────────────────────────────────────────
    -- Not currently FK'd from Master; retained for legacy reference
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'Contrib' AND type = 'U')
    BEGIN
        CREATE TABLE Contrib (
            Value       varchar(2)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_Contrib PRIMARY KEY (Value)
        );
        PRINT 'Table Contrib created.';
    END

    -- ── DDSOURCE ──────────────────────────────────────────────────────────────
    -- Value type varchar(4) matches Master.DDSOURCE
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'DDSOURCE' AND type = 'U')
    BEGIN
        CREATE TABLE DDSOURCE (
            Value       varchar(4)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_DDSOURCE PRIMARY KEY (Value)
        );
        PRINT 'Table DDSOURCE created.';
    END

    -- ── DType ─────────────────────────────────────────────────────────────────
    -- Not currently FK'd from Master; retained for legacy reference
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'DType' AND type = 'U')
    BEGIN
        CREATE TABLE DType (
            Value       varchar(2)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_DType PRIMARY KEY (Value)
        );
        PRINT 'Table DType created.';
    END

    -- ── GLARE ─────────────────────────────────────────────────────────────────
    -- Value type varchar(4) matches Master.GLAREL and Master.GLARER
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'GLARE' AND type = 'U')
    BEGIN
        CREATE TABLE GLARE (
            Value       varchar(4)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_GLARE PRIMARY KEY (Value)
        );
        PRINT 'Table GLARE created.';
    END

    -- ── IDREL ─────────────────────────────────────────────────────────────────
    -- Value type int matches Master.IDREL
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'IDREL' AND type = 'U')
    BEGIN
        CREATE TABLE IDREL (
            Value       int             NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_IDREL PRIMARY KEY (Value)
        );
        PRINT 'Table IDREL created.';
    END

    -- ── IDSOURCE ──────────────────────────────────────────────────────────────
    -- Value type varchar(4) matches Master.IDSOURCE
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'IDSOURCE' AND type = 'U')
    BEGIN
        CREATE TABLE IDSOURCE (
            Value       varchar(4)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_IDSOURCE PRIMARY KEY (Value)
        );
        PRINT 'Table IDSOURCE created.';
    END

    -- ── LEGGOOD ───────────────────────────────────────────────────────────────
    -- Not currently FK'd from Master; retained for legacy reference
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'LEGGOOD' AND type = 'U')
    BEGIN
        CREATE TABLE LEGGOOD (
            Value       varchar(2)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_LEGGOOD PRIMARY KEY (Value)
        );
        PRINT 'Table LEGGOOD created.';
    END

    -- ── LEGSTAGE ──────────────────────────────────────────────────────────────
    -- Value type varchar(4) matches Master.LEGSTAGE
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'LEGSTAGE' AND type = 'U')
    BEGIN
        CREATE TABLE LEGSTAGE (
            Value       varchar(4)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_LEGSTAGE PRIMARY KEY (Value)
        );
        PRINT 'Table LEGSTAGE created.';
    END

    -- ── LEGTYPE ───────────────────────────────────────────────────────────────
    -- Value type varchar(4) matches Master.LEGTYPE
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'LEGTYPE' AND type = 'U')
    BEGIN
        CREATE TABLE LEGTYPE (
            Value       varchar(4)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_LEGTYPE PRIMARY KEY (Value)
        );
        PRINT 'Table LEGTYPE created.';
    END

    -- ── OLDVIZ ────────────────────────────────────────────────────────────────
    -- Not currently FK'd from Master; retained for legacy reference
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'OLDVIZ' AND type = 'U')
    BEGIN
        CREATE TABLE OLDVIZ (
            Value       varchar(2)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_OLDVIZ PRIMARY KEY (Value)
        );
        PRINT 'Table OLDVIZ created.';
    END

    -- ── PHOTOS ────────────────────────────────────────────────────────────────
    -- Value type varchar(4) matches Master.PHOTOS
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'PHOTOS' AND type = 'U')
    BEGIN
        CREATE TABLE PHOTOS (
            Value       varchar(4)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_PHOTOS PRIMARY KEY (Value)
        );
        PRINT 'Table PHOTOS created.';
    END

    -- ── PLATFORM ──────────────────────────────────────────────────────────────
    -- Value type int matches Master.PLATFORM
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'PLATFORM' AND type = 'U')
    BEGIN
        CREATE TABLE PLATFORM (
            Value       int             NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_PLATFORM PRIMARY KEY (Value)
        );
        PRINT 'Table PLATFORM created.';
    END

    -- ── SPECCODE ──────────────────────────────────────────────────────────────
    -- Value type varchar(8) matches Master.SPECCODE; extra columns from recovered export
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'SPECCODE' AND type = 'U')
    BEGIN
        CREATE TABLE SPECCODE (
            Value       varchar(8)      NOT NULL,
            SPECNAME    varchar(255)    NULL,       -- full species name
            SPECCHAR    varchar(2)      NULL,       -- species character code
            SPECNUM     varchar(4)      NULL,       -- species number code
            Type        varchar(20)     NULL,       -- type category (e.g., BIR, CETACEAN)
            TAXCODE     varchar(4)      NULL,       -- taxonomic code (links to TAXCODE table)
            CONSTRAINT PK_SPECCODE PRIMARY KEY (Value)
        );
        PRINT 'Table SPECCODE created.';
    END

    -- ── STRATUM ───────────────────────────────────────────────────────────────
    -- Value type varchar(4) matches Master.STRATUM; values include digits and letters (e.g., "A", "I")
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'STRATUM' AND type = 'U')
    BEGIN
        CREATE TABLE STRATUM (
            Value       varchar(4)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_STRATUM PRIMARY KEY (Value)
        );
        PRINT 'Table STRATUM created.';
    END

    -- ── STRIP ─────────────────────────────────────────────────────────────────
    -- Value type varchar(4) matches Master.STRIP
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'STRIP' AND type = 'U')
    BEGIN
        CREATE TABLE STRIP (
            Value       varchar(4)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_STRIP PRIMARY KEY (Value)
        );
        PRINT 'Table STRIP created.';
    END

    -- ── TAXCODE ───────────────────────────────────────────────────────────────
    -- Value type varchar(4) matches Master.TAXCODE
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'TAXCODE' AND type = 'U')
    BEGIN
        CREATE TABLE TAXCODE (
            Value       varchar(4)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_TAXCODE PRIMARY KEY (Value)
        );
        PRINT 'Table TAXCODE created.';
    END

    -- ── WX ────────────────────────────────────────────────────────────────────
    -- Value type varchar(4) matches Master.WX
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'WX' AND type = 'U')
    BEGIN
        CREATE TABLE WX (
            Value       varchar(4)      NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_WX PRIMARY KEY (Value)
        );
        PRINT 'Table WX created.';
    END

    COMMIT TRANSACTION;
    PRINT 'Lookup table creation complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'ERROR creating lookup tables: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO
