/*
 * 03_create_lookup_tables.sql
 *
 * Purpose:    Create all lookup tables referenced in data/tables/.
 *             Tables are in alphabetical order by table name.
 * Depends on: 01_create_database.sql
 * Reversal:   DROP TABLE <TableName>; (one per table, in any order — no FKs enforced)
 * Last modified: 2026-06-26
 *
 * Standard schema for simple lookup tables:
 *   Value       NVARCHAR(N) or INT  PRIMARY KEY
 *   Description NVARCHAR(255)
 *
 * Non-standard tables (SPECCODE, Beaufort, MONTH, sysdiagrams) have additional
 * columns documented inline.
 *
 * Value column type:
 *   INT    where all observed values are integers (ANHEAD, Behave, Block, Cloud,
 *          Confidnc, GLARE, IDREL, LEGGOOD, LEGSTAGE, LEGTYPE, OLDVIZ, PHOTOS,
 *          STRIP, TAXCODE)
 *   NVARCHAR where values contain letters (DDSOURCE, DType, IDSOURCE, STRATUM,
 *          WX, SPECCODE, Contrib, PLATFORM is INT)
 */

USE NARWC;
GO

-- ── ANHEAD ────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'ANHEAD' AND type = 'U')
BEGIN
    CREATE TABLE ANHEAD (
        Value       INT             NOT NULL,   -- Coded angle-to-head value (0-15)
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_ANHEAD PRIMARY KEY (Value)
    );
    PRINT 'Table ANHEAD created.';
END
GO

-- ── Beaufort ──────────────────────────────────────────────────────────────────
-- Extra columns: lWind, hWind, Waves (from Beaufort.csv)
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'Beaufort' AND type = 'U')
BEGIN
    CREATE TABLE Beaufort (
        Value       INT             NOT NULL,   -- Beaufort scale value (0-9)
        lWind       FLOAT           NULL,       -- Lower wind speed bound (knots)
        hWind       FLOAT           NULL,       -- Upper wind speed bound (knots)
        Waves       FLOAT           NULL,       -- Typical wave height (meters)
        Description NVARCHAR(1000)  NULL,       -- Longer description; 1000 chars for verbose entries
        CONSTRAINT PK_Beaufort PRIMARY KEY (Value)
    );
    PRINT 'Table Beaufort created.';
END
GO

-- ── Behave ────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'Behave' AND type = 'U')
BEGIN
    CREATE TABLE Behave (
        Value       INT             NOT NULL,   -- Behavior code (0-99)
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_Behave PRIMARY KEY (Value)
    );
    PRINT 'Table Behave created.';
END
GO

-- ── Block ─────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'Block' AND type = 'U')
BEGIN
    CREATE TABLE Block (
        Value       INT             NOT NULL,   -- Block code
        Description NVARCHAR(512)   NULL,       -- 512 chars; block descriptions can be long
        CONSTRAINT PK_Block PRIMARY KEY (Value)
    );
    PRINT 'Table Block created.';
END
GO

-- ── Cloud ─────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'Cloud' AND type = 'U')
BEGIN
    CREATE TABLE Cloud (
        Value       INT             NOT NULL,   -- Cloud cover code (0-10)
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_Cloud PRIMARY KEY (Value)
    );
    PRINT 'Table Cloud created.';
END
GO

-- ── Confidnc ──────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'Confidnc' AND type = 'U')
BEGIN
    CREATE TABLE Confidnc (
        Value       INT             NOT NULL,   -- Confidence code
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_Confidnc PRIMARY KEY (Value)
    );
    PRINT 'Table Confidnc created.';
END
GO

-- ── Contrib ───────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'Contrib' AND type = 'U')
BEGIN
    CREATE TABLE Contrib (
        Value       INT             NOT NULL,   -- Contributor code
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_Contrib PRIMARY KEY (Value)
    );
    PRINT 'Table Contrib created.';
END
GO

-- ── DDSOURCE ──────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'DDSOURCE' AND type = 'U')
BEGIN
    CREATE TABLE DDSOURCE (
        Value       NVARCHAR(8)     NOT NULL,   -- Data source abbreviation
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_DDSOURCE PRIMARY KEY (Value)
    );
    PRINT 'Table DDSOURCE created.';
END
GO

-- ── DType ─────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'DType' AND type = 'U')
BEGIN
    CREATE TABLE DType (
        Value       NVARCHAR(4)     NOT NULL,   -- Survey type code (e.g., 'A', 'F')
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_DType PRIMARY KEY (Value)
    );
    PRINT 'Table DType created.';
END
GO

-- ── GLARE ─────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'GLARE' AND type = 'U')
BEGIN
    CREATE TABLE GLARE (
        Value       INT             NOT NULL,   -- Glare level code (0-n)
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_GLARE PRIMARY KEY (Value)
    );
    PRINT 'Table GLARE created.';
END
GO

-- ── IDREL ─────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'IDREL' AND type = 'U')
BEGIN
    CREATE TABLE IDREL (
        Value       INT             NOT NULL,   -- ID reliability code
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_IDREL PRIMARY KEY (Value)
    );
    PRINT 'Table IDREL created.';
END
GO

-- ── IDSOURCE ──────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'IDSOURCE' AND type = 'U')
BEGIN
    CREATE TABLE IDSOURCE (
        Value       NVARCHAR(8)     NOT NULL,   -- ID source abbreviation
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_IDSOURCE PRIMARY KEY (Value)
    );
    PRINT 'Table IDSOURCE created.';
END
GO

-- ── LEGGOOD ───────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'LEGGOOD' AND type = 'U')
BEGIN
    CREATE TABLE LEGGOOD (
        Value       INT             NOT NULL,   -- Leg good code (1=No, 2=Yes)
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_LEGGOOD PRIMARY KEY (Value)
    );
    PRINT 'Table LEGGOOD created.';
END
GO

-- ── LEGSTAGE ──────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'LEGSTAGE' AND type = 'U')
BEGIN
    CREATE TABLE LEGSTAGE (
        Value       INT             NOT NULL,   -- Leg stage code
        Description NVARCHAR(512)   NULL,
        CONSTRAINT PK_LEGSTAGE PRIMARY KEY (Value)
    );
    PRINT 'Table LEGSTAGE created.';
END
GO

-- ── LEGTYPE ───────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'LEGTYPE' AND type = 'U')
BEGIN
    CREATE TABLE LEGTYPE (
        Value       INT             NOT NULL,   -- Leg type code
        Description NVARCHAR(512)   NULL,
        CONSTRAINT PK_LEGTYPE PRIMARY KEY (Value)
    );
    PRINT 'Table LEGTYPE created.';
END
GO

-- ── MONTH ─────────────────────────────────────────────────────────────────────
-- MONTH.csv uses MonthID / MonthName columns instead of Value / Description
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'MONTH' AND type = 'U')
BEGIN
    CREATE TABLE MONTH (
        Value       INT             NOT NULL,   -- Month number (1-12); mapped from MonthID
        Description NVARCHAR(32)    NULL,       -- Month name; mapped from MonthName
        CONSTRAINT PK_MONTH PRIMARY KEY (Value)
    );
    PRINT 'Table MONTH created.';
END
GO

-- ── OLDVIZ ────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'OLDVIZ' AND type = 'U')
BEGIN
    CREATE TABLE OLDVIZ (
        Value       INT             NOT NULL,   -- Old visibility code
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_OLDVIZ PRIMARY KEY (Value)
    );
    PRINT 'Table OLDVIZ created.';
END
GO

-- ── PHOTOS ────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'PHOTOS' AND type = 'U')
BEGIN
    CREATE TABLE PHOTOS (
        Value       INT             NOT NULL,   -- Photos code (1=No, 2=Yes, etc.)
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_PHOTOS PRIMARY KEY (Value)
    );
    PRINT 'Table PHOTOS created.';
END
GO

-- ── PLATFORM ──────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'PLATFORM' AND type = 'U')
BEGIN
    CREATE TABLE PLATFORM (
        Value       INT             NOT NULL,   -- Platform code
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_PLATFORM PRIMARY KEY (Value)
    );
    PRINT 'Table PLATFORM created.';
END
GO

-- ── SPECCODE ──────────────────────────────────────────────────────────────────
-- SPECCODE.csv has additional columns beyond Value/Description
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'SPECCODE' AND type = 'U')
BEGIN
    CREATE TABLE SPECCODE (
        Value       NVARCHAR(8)     NOT NULL,   -- Species code (up to 8 chars)
        SPECNAME    NVARCHAR(255)   NULL,       -- Full species name
        SPECCHAR    NVARCHAR(8)     NULL,       -- Species character code
        SPECNUM     NVARCHAR(8)     NULL,       -- Species number code
        Type        NVARCHAR(32)    NULL,       -- Type category (e.g., BIR, CETACEAN)
        TAXCODE     INT             NULL,       -- Taxonomic code link
        CONSTRAINT PK_SPECCODE PRIMARY KEY (Value)
    );
    PRINT 'Table SPECCODE created.';
END
GO

-- ── STRATUM ───────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'STRATUM' AND type = 'U')
BEGIN
    CREATE TABLE STRATUM (
        Value       NVARCHAR(8)     NOT NULL,   -- Stratum code (mix of int and alpha values)
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_STRATUM PRIMARY KEY (Value)
    );
    PRINT 'Table STRATUM created.';
END
GO

-- ── STRIP ─────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'STRIP' AND type = 'U')
BEGIN
    CREATE TABLE STRIP (
        Value       INT             NOT NULL,   -- Strip number (1-16)
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_STRIP PRIMARY KEY (Value)
    );
    PRINT 'Table STRIP created.';
END
GO

-- ── sysdiagrams ───────────────────────────────────────────────────────────────
-- Exported from legacy SQL Server; retained for reference only.
-- name, principal_id, diagram_id, version, definition
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'sysdiagrams' AND type = 'U')
BEGIN
    CREATE TABLE sysdiagrams (
        name            NVARCHAR(128)   NOT NULL,
        principal_id    INT             NOT NULL,
        diagram_id      INT             NOT NULL IDENTITY(1,1),
        version         INT             NULL,
        definition      VARBINARY(MAX)  NULL,
        CONSTRAINT PK_sysdiagrams PRIMARY KEY (diagram_id)
    );
    PRINT 'Table sysdiagrams created.';
END
GO

-- ── TAXCODE ───────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'TAXCODE' AND type = 'U')
BEGIN
    CREATE TABLE TAXCODE (
        Value       INT             NOT NULL,   -- Taxonomic code
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_TAXCODE PRIMARY KEY (Value)
    );
    PRINT 'Table TAXCODE created.';
END
GO

-- ── WX ────────────────────────────────────────────────────────────────────────
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'WX' AND type = 'U')
BEGIN
    CREATE TABLE WX (
        Value       NVARCHAR(4)     NOT NULL,   -- Weather code (single letter or short code)
        Description NVARCHAR(255)   NULL,
        CONSTRAINT PK_WX PRIMARY KEY (Value)
    );
    PRINT 'Table WX created.';
END
GO
