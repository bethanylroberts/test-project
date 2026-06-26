/*
 * 05_populate_lookup_tables.sql
 *
 * Purpose:    Populate all lookup tables from data/tables/*.csv.
 * Depends on: 03_create_lookup_tables.sql (tables must exist)
 * Reversal:   TRUNCATE TABLE <TableName>; (one per table)
 * Last modified: 2026-06-26
 *
 * Path placeholder: Replace <FILL_IN> with the absolute Windows path to the
 * data/tables/ directory as accessible from the SQL Server host.
 * Example:  C:\NARWC-DB\data\tables\
 *
 * BULK INSERT notes:
 *   - FIRSTROW = 2 skips the CSV header row.
 *   - CODEPAGE = 'ACP' handles Windows-1252 encoded files.
 *   - ROWTERMINATOR handles Windows line endings.
 *   - FIELDTERMINATOR = ',' with FIELDQUOTE = '"' for quoted fields.
 *   - The SQL Server service account must have read access to the file path.
 *
 * Tables with non-standard columns (SPECCODE, Beaufort, MONTH, sysdiagrams)
 * use a format file or a staging table approach; see inline comments.
 *
 * Credentials/connection strings are NOT embedded here.
 */

USE NARWC;
GO

DECLARE @data_root NVARCHAR(260) = N'<FILL_IN>';   -- e.g. N'C:\NARWC-DB\data\tables\'

-- ── ANHEAD ────────────────────────────────────────────────────────────────────
TRUNCATE TABLE ANHEAD;
BULK INSERT ANHEAD
    FROM @data_root + 'ANHEAD.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'ANHEAD populated.';
GO

-- ── Beaufort ──────────────────────────────────────────────────────────────────
-- Beaufort.csv has columns: Value, lWind, hWind, Waves, Description
-- The Description field contains commas inside quotes; use FIELDQUOTE.
TRUNCATE TABLE Beaufort;
BULK INSERT Beaufort
    FROM '<FILL_IN>Beaufort.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'Beaufort populated.';
GO

-- ── Behave ────────────────────────────────────────────────────────────────────
TRUNCATE TABLE Behave;
BULK INSERT Behave
    FROM '<FILL_IN>Behave.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'Behave populated.';
GO

-- ── Block ─────────────────────────────────────────────────────────────────────
TRUNCATE TABLE Block;
BULK INSERT Block
    FROM '<FILL_IN>Block.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'Block populated.';
GO

-- ── Cloud ─────────────────────────────────────────────────────────────────────
TRUNCATE TABLE Cloud;
BULK INSERT Cloud
    FROM '<FILL_IN>Cloud.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'Cloud populated.';
GO

-- ── Confidnc ──────────────────────────────────────────────────────────────────
TRUNCATE TABLE Confidnc;
BULK INSERT Confidnc
    FROM '<FILL_IN>Confidnc.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'Confidnc populated.';
GO

-- ── Contrib ───────────────────────────────────────────────────────────────────
TRUNCATE TABLE Contrib;
BULK INSERT Contrib
    FROM '<FILL_IN>Contrib.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'Contrib populated.';
GO

-- ── DDSOURCE ──────────────────────────────────────────────────────────────────
TRUNCATE TABLE DDSOURCE;
BULK INSERT DDSOURCE
    FROM '<FILL_IN>DDSOURCE.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'DDSOURCE populated.';
GO

-- ── DType ─────────────────────────────────────────────────────────────────────
TRUNCATE TABLE DType;
BULK INSERT DType
    FROM '<FILL_IN>DType.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'DType populated.';
GO

-- ── GLARE ─────────────────────────────────────────────────────────────────────
TRUNCATE TABLE GLARE;
BULK INSERT GLARE
    FROM '<FILL_IN>GLARE.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'GLARE populated.';
GO

-- ── IDREL ─────────────────────────────────────────────────────────────────────
TRUNCATE TABLE IDREL;
BULK INSERT IDREL
    FROM '<FILL_IN>IDREL.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'IDREL populated.';
GO

-- ── IDSOURCE ──────────────────────────────────────────────────────────────────
TRUNCATE TABLE IDSOURCE;
BULK INSERT IDSOURCE
    FROM '<FILL_IN>IDSOURCE.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'IDSOURCE populated.';
GO

-- ── LEGGOOD ───────────────────────────────────────────────────────────────────
TRUNCATE TABLE LEGGOOD;
BULK INSERT LEGGOOD
    FROM '<FILL_IN>LEGGOOD.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'LEGGOOD populated.';
GO

-- ── LEGSTAGE ──────────────────────────────────────────────────────────────────
TRUNCATE TABLE LEGSTAGE;
BULK INSERT LEGSTAGE
    FROM '<FILL_IN>LEGSTAGE.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'LEGSTAGE populated.';
GO

-- ── LEGTYPE ───────────────────────────────────────────────────────────────────
TRUNCATE TABLE LEGTYPE;
BULK INSERT LEGTYPE
    FROM '<FILL_IN>LEGTYPE.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'LEGTYPE populated.';
GO

-- ── MONTH ─────────────────────────────────────────────────────────────────────
-- MONTH.csv uses MonthID / MonthName instead of Value / Description.
-- Load via a staging table and then INSERT with column remapping.
IF OBJECT_ID('tempdb..#month_stage') IS NOT NULL DROP TABLE #month_stage;
CREATE TABLE #month_stage (MonthID INT, MonthName NVARCHAR(32));
BULK INSERT #month_stage
    FROM '<FILL_IN>MONTH.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
TRUNCATE TABLE MONTH;
INSERT INTO MONTH (Value, Description)
    SELECT MonthID, MonthName FROM #month_stage;
DROP TABLE #month_stage;
PRINT 'MONTH populated.';
GO

-- ── OLDVIZ ────────────────────────────────────────────────────────────────────
TRUNCATE TABLE OLDVIZ;
BULK INSERT OLDVIZ
    FROM '<FILL_IN>OLDVIZ.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'OLDVIZ populated.';
GO

-- ── PHOTOS ────────────────────────────────────────────────────────────────────
TRUNCATE TABLE PHOTOS;
BULK INSERT PHOTOS
    FROM '<FILL_IN>PHOTOS.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'PHOTOS populated.';
GO

-- ── PLATFORM ──────────────────────────────────────────────────────────────────
TRUNCATE TABLE PLATFORM;
BULK INSERT PLATFORM
    FROM '<FILL_IN>PLATFORM.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'PLATFORM populated.';
GO

-- ── SPECCODE ──────────────────────────────────────────────────────────────────
-- SPECCODE.csv has 6 columns: Value, SPECNAME, SPECCHAR, SPECNUM, Type, TAXCODE
TRUNCATE TABLE SPECCODE;
BULK INSERT SPECCODE
    FROM '<FILL_IN>SPECCODE.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'SPECCODE populated.';
GO

-- ── STRATUM ───────────────────────────────────────────────────────────────────
TRUNCATE TABLE STRATUM;
BULK INSERT STRATUM
    FROM '<FILL_IN>STRATUM.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'STRATUM populated.';
GO

-- ── STRIP ─────────────────────────────────────────────────────────────────────
TRUNCATE TABLE STRIP;
BULK INSERT STRIP
    FROM '<FILL_IN>STRIP.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'STRIP populated.';
GO

-- ── sysdiagrams ───────────────────────────────────────────────────────────────
-- sysdiagrams.csv is exported from the legacy instance for reference; the
-- definition column (VARBINARY) is not directly bulk-insertable from CSV.
-- Skip auto-population; restore from a database backup if needed.
PRINT 'sysdiagrams: skipped (binary definition column cannot be loaded from CSV).';
GO

-- ── TAXCODE ───────────────────────────────────────────────────────────────────
TRUNCATE TABLE TAXCODE;
BULK INSERT TAXCODE
    FROM '<FILL_IN>TAXCODE.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'TAXCODE populated.';
GO

-- ── WX ────────────────────────────────────────────────────────────────────────
TRUNCATE TABLE WX;
BULK INSERT WX
    FROM '<FILL_IN>WX.csv'
    WITH (
        FIRSTROW        = 2,
        FIELDTERMINATOR = ',',
        FIELDQUOTE      = '"',
        ROWTERMINATOR   = '\n',
        CODEPAGE        = 'ACP',
        TABLOCK
    );
PRINT 'WX populated.';
GO

PRINT 'Lookup table population complete.';
