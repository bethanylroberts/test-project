/*
 * 01_create_database.sql
 *
 * Purpose:    Create the NARWCDB database on SQL Server.
 * Depends on: Nothing (run first). Connect to [master] before running.
 * Reversal:   DROP DATABASE NARWCDB;
 * Last modified: 2026-06-26
 *
 * Collation: SQL_Latin1_General_CP1_CI_AS
 *   CI = Case Insensitive (FILEID lookups are case-insensitive in practice)
 *   AS = Accent Sensitive
 *   CP1 = Code Page 1252 (Western European / Windows-1252)
 *   This matches the collation used in the legacy SQL Server instance and
 *   avoids collation conflicts when joining to linked servers or temp tables
 *   that default to the server collation.
 *
 * Credentials/connection strings are NOT embedded here. Connect externally
 * before running (SSMS, sqlcmd, or MATLAB Database Toolbox).
 */

BEGIN TRY
    IF NOT EXISTS (
        SELECT name FROM sys.databases WHERE name = N'NARWCDB'
    )
    BEGIN
        CREATE DATABASE NARWCDB
            COLLATE SQL_Latin1_General_CP1_CI_AS;
        PRINT 'Database NARWCDB created.';
    END
    ELSE
    BEGIN
        PRINT 'Database NARWCDB already exists; skipping creation.';
    END
END TRY
BEGIN CATCH
    PRINT 'ERROR creating database NARWCDB: ' + ERROR_MESSAGE();
    PRINT 'Check that the SQL Server service account has CREATE DATABASE permission.';
END CATCH
GO
