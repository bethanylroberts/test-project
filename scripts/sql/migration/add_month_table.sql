/*
 * add_month_table.sql
 *
 * Purpose:    Apply the MONTH lookup table addition to an existing NARWCDB
 *             that was built before MONTH was part of the schema.
 * Depends on: NARWCDB exists with Master and other lookup tables.
 * Reversal:   ALTER TABLE Master DROP CONSTRAINT FK_Master_MONTH;
 *             DROP TABLE MONTH;
 * Last modified: 2026-06-28
 *
 * Uses INSERT rather than BULK INSERT so it works without bulkadmin
 * server permission. Values 13-16 are season codes (Winter/Spring/Summer/Fall).
 */

USE NARWCDB;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    -- Create MONTH table
    IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = N'MONTH' AND type = 'U')
    BEGIN
        CREATE TABLE MONTH (
            Value       tinyint         NOT NULL,
            Description varchar(255)    NULL,
            CONSTRAINT PK_MONTH PRIMARY KEY CLUSTERED (Value ASC)
        );
        PRINT 'Table MONTH created.';
    END
    ELSE
        PRINT 'Table MONTH already exists; skipping creation.';

    -- Populate
    TRUNCATE TABLE MONTH;
    INSERT INTO MONTH (Value, Description) VALUES
        (1,  'January'),
        (2,  'February'),
        (3,  'March'),
        (4,  'April'),
        (5,  'May'),
        (6,  'June'),
        (7,  'July'),
        (8,  'August'),
        (9,  'September'),
        (10, 'October'),
        (11, 'November'),
        (12, 'December'),
        (13, 'Winter'),
        (14, 'Spring'),
        (15, 'Summer'),
        (16, 'Fall');
    PRINT 'MONTH populated with 16 rows (12 months + 4 seasons).';

    -- Add FK constraint
    IF NOT EXISTS (
        SELECT * FROM sys.foreign_keys
        WHERE name = N'FK_Master_MONTH'
          AND parent_object_id = OBJECT_ID('Master')
    )
    BEGIN
        ALTER TABLE Master ADD CONSTRAINT FK_Master_MONTH
            FOREIGN KEY (MONTH) REFERENCES MONTH(Value);
        PRINT 'FK_Master_MONTH added.';
    END
    ELSE
        PRINT 'FK_Master_MONTH already exists; skipping.';

    COMMIT TRANSACTION;
    PRINT 'MONTH table addition complete.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'ERROR in add_month_table: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO
