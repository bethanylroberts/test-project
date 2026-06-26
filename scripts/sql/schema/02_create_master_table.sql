/*
 * 02_create_master_table.sql
 *
 * Purpose:    Create the Master survey-observation table.
 *             Schema is generated from src/+narwc/+db/FieldDefinitions.m (55 columns).
 * Depends on: 01_create_database.sql (USE NARWC must be in effect).
 * Reversal:   DROP TABLE Master;
 * Last modified: 2026-06-26
 *
 * Column type mapping from FieldDefinitions.m:
 *   double (lat/long)  -> DECIMAL(10,5)
 *   double (count/int) -> INT
 *   double (measure)   -> FLOAT
 *   string             -> NVARCHAR(N)  (N chosen to comfortably fit known values)
 *
 * Primary key: (FILEID, EVENTNO)  -- composite, matches NARWC canonical duplicate key.
 * Foreign keys: NOT enforced at DB level; FK validation is handled by MATLAB rules.
 *               See verification/check_fk_integrity.sql for post-migration checks.
 *
 * Future enhancement: add uploaded_at DATETIME DEFAULT GETDATE() to support
 *   curation/recent_uploads.sql. Not implemented in this version.
 */

USE NARWC;
GO

IF NOT EXISTS (
    SELECT * FROM sys.tables WHERE name = N'Master' AND type = 'U'
)
BEGIN
    CREATE TABLE Master (

        -- ── Identifiers ──────────────────────────────────────────────────────
        FILEID      NVARCHAR(20)    NOT NULL,   -- File/Survey identifier
        EVENTNO     INT             NOT NULL,   -- Event number

        -- ── Date / Time ──────────────────────────────────────────────────────
        YEAR        INT             NOT NULL,   -- Year
        MONTH       INT             NULL,       -- Month (1-12)
        DAY         INT             NULL,       -- Day of month (1-31)
        TIME        INT             NULL,       -- Time of observation (HHMMSS)
        S_TIME      INT             NULL,       -- Starting time

        -- ── Position ─────────────────────────────────────────────────────────
        LAT_DD      DECIMAL(10,5)   NOT NULL,   -- Latitude (decimal degrees)
        LONG_DD     DECIMAL(10,5)   NOT NULL,   -- Longitude (decimal degrees)
        S_LAT       DECIMAL(10,5)   NULL,       -- Starting latitude
        S_LONG      DECIMAL(10,5)   NULL,       -- Starting longitude
        ALT         FLOAT           NULL,       -- Altitude in meters

        -- ── Species / Sighting ───────────────────────────────────────────────
        SPECCODE    NVARCHAR(8)     NULL,       -- Species code
        TAXCODE     INT             NULL,       -- Taxonomic code
        SIGHTNO     INT             NULL,       -- Sighting number
        NUMBER      INT             NULL,       -- Number of animals
        NUMCALF     INT             NULL,       -- Number of calves
        PHOTOS      INT             NULL,       -- Number of photos (coded)
        IDREL       INT             NULL,       -- ID reliability
        IDSOURCE    NVARCHAR(8)     NULL,       -- ID source
        CONFIDNC    INT             NULL,       -- Confidence level

        -- ── Behavior codes (up to 15 per sighting) ───────────────────────────
        BEHAV1      INT             NULL,       -- Behavior code 1
        BEHAV2      INT             NULL,       -- Behavior code 2
        BEHAV3      INT             NULL,       -- Behavior code 3
        BEHAV4      INT             NULL,       -- Behavior code 4
        BEHAV5      INT             NULL,       -- Behavior code 5
        BEHAV6      INT             NULL,       -- Behavior code 6
        BEHAV7      INT             NULL,       -- Behavior code 7
        BEHAV8      INT             NULL,       -- Behavior code 8
        BEHAV9      INT             NULL,       -- Behavior code 9
        BEHAV10     INT             NULL,       -- Behavior code 10
        BEHAV11     INT             NULL,       -- Behavior code 11
        BEHAV12     INT             NULL,       -- Behavior code 12
        BEHAV13     INT             NULL,       -- Behavior code 13
        BEHAV14     INT             NULL,       -- Behavior code 14
        BEHAV15     INT             NULL,       -- Behavior code 15
        ANHEAD      INT             NULL,       -- Angle to head (coded, 0-15)

        -- ── Survey / Leg ─────────────────────────────────────────────────────
        PLATFORM    INT             NULL,       -- Platform code
        DDSOURCE    NVARCHAR(8)     NULL,       -- Data source code
        BLOCK       NVARCHAR(20)    NULL,       -- Survey block identifier
        STRATUM     NVARCHAR(8)     NULL,       -- Survey stratum
        STRIP       INT             NULL,       -- Strip number (1-16)
        LEGNO       INT             NULL,       -- Leg number
        LEGSTAGE    INT             NULL,       -- Leg stage
        LEGTYPE     INT             NULL,       -- Leg type

        -- ── Environmental ────────────────────────────────────────────────────
        BEAUFORT    INT             NULL,       -- Beaufort sea state (0-9)
        CLOUD       INT             NULL,       -- Cloud cover (0-10)
        GLAREL      INT             NULL,       -- Glare level left
        GLARER      INT             NULL,       -- Glare level right
        WX          NVARCHAR(4)     NULL,       -- Weather code
        VISIBLTY    FLOAT           NULL,       -- Visibility
        SURFTEMP    FLOAT           NULL,       -- Surface temperature

        -- ── Aircraft geometry ────────────────────────────────────────────────
        HEADING     INT             NULL,       -- Ship/aircraft heading (degrees)
        ANGLEL      FLOAT           NULL,       -- Angle left of trackline
        ANGLER      FLOAT           NULL,       -- Angle right of trackline

        -- ── Primary key ──────────────────────────────────────────────────────
        CONSTRAINT PK_Master PRIMARY KEY CLUSTERED (FILEID ASC, EVENTNO ASC)
    );

    PRINT 'Table Master created.';
END
ELSE
BEGIN
    PRINT 'Table Master already exists; skipping creation.';
END
GO
