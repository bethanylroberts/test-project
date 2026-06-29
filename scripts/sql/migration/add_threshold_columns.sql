/*
 * add_threshold_columns.sql
 *
 * Purpose:    Add typical_max_group and typical_max_calf columns to
 *             SPECCODE and TAXCODE lookup tables for species- and
 *             taxonomic-group-specific validation thresholds.
 * Depends on: NARWCDB exists; SPECCODE and TAXCODE tables exist.
 * Reversal:   ALTER TABLE SPECCODE DROP COLUMN typical_max_group, typical_max_calf;
 *             ALTER TABLE TAXCODE  DROP COLUMN typical_max_group, typical_max_calf;
 * Last modified: 2026-06-29
 */

USE NARWCDB;
GO

-- SPECCODE
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SPECCODE')
               AND name = 'typical_max_group')
BEGIN
    ALTER TABLE SPECCODE ADD typical_max_group int NULL;
    PRINT 'SPECCODE.typical_max_group added.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('SPECCODE')
               AND name = 'typical_max_calf')
BEGIN
    ALTER TABLE SPECCODE ADD typical_max_calf int NULL;
    PRINT 'SPECCODE.typical_max_calf added.';
END
GO

-- TAXCODE
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('TAXCODE')
               AND name = 'typical_max_group')
BEGIN
    ALTER TABLE TAXCODE ADD typical_max_group int NULL;
    PRINT 'TAXCODE.typical_max_group added.';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID('TAXCODE')
               AND name = 'typical_max_calf')
BEGIN
    ALTER TABLE TAXCODE ADD typical_max_calf int NULL;
    PRINT 'TAXCODE.typical_max_calf added.';
END
GO

PRINT 'Threshold columns added. Re-run push_lookup_tables.m to populate.';
