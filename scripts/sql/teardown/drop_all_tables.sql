/*
 * drop_all_tables.sql
 *
 * Purpose:    Drop all tables in the NARWC database.
 * Depends on: Nothing (other than the database existing).
 * Reversal:   Re-run schema/01 through schema/05.
 * Last modified: 2026-06-26
 *
 * WARNING: DEVELOPMENT USE ONLY.
 * This destroys all survey data and all lookup data. Do not run on a production
 * database without a verified backup. The transaction allows a final review
 * of the DROP statements before committing.
 *
 * Foreign keys are not enforced at the DB level, so tables may be dropped in
 * any order. Master is dropped first for explicitness.
 */

USE NARWC;
GO

BEGIN TRANSACTION;

-- ── Survey data ───────────────────────────────────────────────────────────────
IF OBJECT_ID('dbo.Master', 'U') IS NOT NULL
    DROP TABLE dbo.Master;

-- ── Lookup tables (alphabetical) ──────────────────────────────────────────────
IF OBJECT_ID('dbo.ANHEAD',      'U') IS NOT NULL DROP TABLE dbo.ANHEAD;
IF OBJECT_ID('dbo.Beaufort',    'U') IS NOT NULL DROP TABLE dbo.Beaufort;
IF OBJECT_ID('dbo.Behave',      'U') IS NOT NULL DROP TABLE dbo.Behave;
IF OBJECT_ID('dbo.Block',       'U') IS NOT NULL DROP TABLE dbo.Block;
IF OBJECT_ID('dbo.Cloud',       'U') IS NOT NULL DROP TABLE dbo.Cloud;
IF OBJECT_ID('dbo.Confidnc',    'U') IS NOT NULL DROP TABLE dbo.Confidnc;
IF OBJECT_ID('dbo.Contrib',     'U') IS NOT NULL DROP TABLE dbo.Contrib;
IF OBJECT_ID('dbo.DDSOURCE',    'U') IS NOT NULL DROP TABLE dbo.DDSOURCE;
IF OBJECT_ID('dbo.DType',       'U') IS NOT NULL DROP TABLE dbo.DType;
IF OBJECT_ID('dbo.GLARE',       'U') IS NOT NULL DROP TABLE dbo.GLARE;
IF OBJECT_ID('dbo.IDREL',       'U') IS NOT NULL DROP TABLE dbo.IDREL;
IF OBJECT_ID('dbo.IDSOURCE',    'U') IS NOT NULL DROP TABLE dbo.IDSOURCE;
IF OBJECT_ID('dbo.LEGGOOD',     'U') IS NOT NULL DROP TABLE dbo.LEGGOOD;
IF OBJECT_ID('dbo.LEGSTAGE',    'U') IS NOT NULL DROP TABLE dbo.LEGSTAGE;
IF OBJECT_ID('dbo.LEGTYPE',     'U') IS NOT NULL DROP TABLE dbo.LEGTYPE;
IF OBJECT_ID('dbo.MONTH',       'U') IS NOT NULL DROP TABLE dbo.MONTH;
IF OBJECT_ID('dbo.OLDVIZ',      'U') IS NOT NULL DROP TABLE dbo.OLDVIZ;
IF OBJECT_ID('dbo.PHOTOS',      'U') IS NOT NULL DROP TABLE dbo.PHOTOS;
IF OBJECT_ID('dbo.PLATFORM',    'U') IS NOT NULL DROP TABLE dbo.PLATFORM;
IF OBJECT_ID('dbo.SPECCODE',    'U') IS NOT NULL DROP TABLE dbo.SPECCODE;
IF OBJECT_ID('dbo.STRATUM',     'U') IS NOT NULL DROP TABLE dbo.STRATUM;
IF OBJECT_ID('dbo.STRIP',       'U') IS NOT NULL DROP TABLE dbo.STRIP;
IF OBJECT_ID('dbo.sysdiagrams', 'U') IS NOT NULL DROP TABLE dbo.sysdiagrams;
IF OBJECT_ID('dbo.TAXCODE',     'U') IS NOT NULL DROP TABLE dbo.TAXCODE;
IF OBJECT_ID('dbo.WX',          'U') IS NOT NULL DROP TABLE dbo.WX;

-- Review output above, then COMMIT or ROLLBACK:
-- COMMIT;
-- ROLLBACK;
