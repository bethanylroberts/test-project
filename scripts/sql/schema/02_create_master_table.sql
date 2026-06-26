/*
 * 02_create_master_table.sql
 *
 * Purpose:    Create the Master survey-observation table.
 *             Column types are derived from src/+narwc/+db/FieldDefinitions.m
 *             and the recovered 2025-06-16 SSMS export, with appropriate SQL
 *             types replacing the numeric(38,16) / oversized varchar artifacts.
 * Depends on: 01_create_database.sql (NARWCDB must exist).
 *             Run 03_create_lookup_tables.sql before 05_add_foreign_keys.sql.
 *             FK constraints are added separately in 05_add_foreign_keys.sql
 *             because they depend on lookup tables existing.
 * Reversal:   DROP TABLE Master;
 * Last modified: 2026-06-26
 *
 * Master_ID is a surrogate primary key (IDENTITY). It provides a stable row
 * handle without enforcing (FILEID, EVENTNO) uniqueness at the DB level —
 * duplicate detection is handled by MATLAB validation before upload.
 *
 * All fields are nullable except FILEID and EVENTNO (required for every row).
 * ANGLEL/ANGLER are aerial-only geometry fields; NULL for ship surveys.
 */

USE NARWCDB;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS (
        SELECT * FROM sys.tables WHERE name = N'Master' AND type = 'U'
    )
    BEGIN
        CREATE TABLE Master (

            -- ── Surrogate PK ─────────────────────────────────────────────────
            Master_ID   int             NOT NULL IDENTITY(1,1),

            -- ── Identifiers ──────────────────────────────────────────────────
            FILEID      varchar(20)     NOT NULL,   -- file/survey code; 6-8 chars actual
            EVENTNO     int             NOT NULL,   -- sequential event number within file

            -- ── Date / Time ──────────────────────────────────────────────────
            YEAR        smallint        NULL,       -- 4-digit year
            MONTH       tinyint         NULL,       -- 1-12
            DAY         tinyint         NULL,       -- 1-31
            TIME        int             NULL,       -- HHMMSS integer
            S_TIME      int             NULL,       -- leg-start time, HHMMSS

            -- ── Position ─────────────────────────────────────────────────────
            LAT_DD      decimal(10,5)   NULL,       -- latitude, decimal degrees
            LONG_DD     decimal(10,5)   NULL,       -- longitude, decimal degrees
            S_LAT       decimal(10,5)   NULL,       -- leg-start latitude
            S_LONG      decimal(10,5)   NULL,       -- leg-start longitude
            ALT         decimal(8,2)    NULL,       -- altitude in feet (aerial only)
            HEADING     smallint        NULL,       -- aircraft/vessel heading 0-359

            -- ── Survey / Leg ─────────────────────────────────────────────────
            PLATFORM    int             NULL,       -- FK to PLATFORM.Value
            LEGNO       smallint        NULL,       -- leg number within survey
            LEGTYPE     varchar(4)      NULL,       -- FK to LEGTYPE.Value
            LEGSTAGE    varchar(4)      NULL,       -- FK to LEGSTAGE.Value
            DDSOURCE    varchar(4)      NULL,       -- FK to DDSOURCE.Value
            IDSOURCE    varchar(4)      NULL,       -- FK to IDSOURCE.Value
            BLOCK       varchar(4)      NULL,       -- FK to Block.Value
            STRATUM     varchar(4)      NULL,       -- FK to STRATUM.Value
            STRIP       varchar(4)      NULL,       -- FK to STRIP.Value

            -- ── Environmental ────────────────────────────────────────────────
            BEAUFORT    varchar(4)      NULL,       -- FK to Beaufort.Value (sea state 0-9)
            CLOUD       int             NULL,       -- FK to Cloud.Value
            GLAREL      varchar(4)      NULL,       -- FK to GLARE.Value (left)
            GLARER      varchar(4)      NULL,       -- FK to GLARE.Value (right)
            WX          varchar(4)      NULL,       -- FK to WX.Value
            VISIBLTY    decimal(8,2)    NULL,       -- visibility in nautical miles
            SURFTEMP    decimal(8,2)    NULL,       -- sea surface temperature

            -- ── Sighting ─────────────────────────────────────────────────────
            SIGHTNO     int             NULL,       -- sighting number; NULL on non-sighting rows
            SPECCODE    varchar(8)      NULL,       -- FK to SPECCODE.Value
            TAXCODE     varchar(4)      NULL,       -- FK to TAXCODE.Value
            NUMBER      int             NULL,       -- group size (best estimate)
            NUMCALF     int             NULL,       -- calf count within group
            CONFIDNC    int             NULL,       -- FK to Confidnc.Value (size-estimate confidence)
            IDREL       int             NULL,       -- FK to IDREL.Value (ID reliability)
            PHOTOS      varchar(4)      NULL,       -- FK to PHOTOS.Value

            -- ── Geometry ─────────────────────────────────────────────────────
            ANGLEL      smallint        NULL,       -- perpendicular angle left of trackline
            ANGLER      smallint        NULL,       -- perpendicular angle right of trackline
            ANHEAD      varchar(4)      NULL,       -- FK to ANHEAD.Value (animal heading code)

            -- ── Behavior codes (up to 15 per sighting) ───────────────────────
            BEHAV1      varchar(4)      NULL,       -- FK to Behave.Value
            BEHAV2      varchar(4)      NULL,
            BEHAV3      varchar(4)      NULL,
            BEHAV4      varchar(4)      NULL,
            BEHAV5      varchar(4)      NULL,
            BEHAV6      varchar(4)      NULL,
            BEHAV7      varchar(4)      NULL,
            BEHAV8      varchar(4)      NULL,
            BEHAV9      varchar(4)      NULL,
            BEHAV10     varchar(4)      NULL,
            BEHAV11     varchar(4)      NULL,
            BEHAV12     varchar(4)      NULL,
            BEHAV13     varchar(4)      NULL,
            BEHAV14     varchar(4)      NULL,
            BEHAV15     varchar(4)      NULL,

            CONSTRAINT PK_Master PRIMARY KEY CLUSTERED (Master_ID ASC)
        );

        PRINT 'Table Master created.';
    END
    ELSE
    BEGIN
        PRINT 'Table Master already exists; skipping creation.';
    END

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'ERROR creating Master table: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO
