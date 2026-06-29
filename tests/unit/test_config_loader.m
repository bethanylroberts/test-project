classdef test_config_loader < matlab.unittest.TestCase
    % TEST_CONFIG_LOADER Unit tests for config/load_config.m

    methods (Test)

        function testDefaultsReturnExpectedSections(testCase)
            % load_config() with no batch returns a struct with db, validation, pipeline
            config = load_config();

            testCase.verifyTrue(isfield(config, 'db'), 'config.db missing');
            testCase.verifyTrue(isfield(config, 'validation'), 'config.validation missing');
            testCase.verifyTrue(isfield(config, 'pipeline'), 'config.pipeline missing');
        end

        function testDefaultDbHasRequiredFields(testCase)
            config = load_config();
            testCase.verifyTrue(isfield(config.db, 'Type'));
            testCase.verifyTrue(isfield(config.db, 'Server'));
            testCase.verifyTrue(isfield(config.db, 'Username'));
            testCase.verifyTrue(isfield(config.db, 'Password'));
        end

        function testDefaultYearMin(testCase)
            % Default year_min should be 1980 (tighter than migration's 1970)
            config = load_config();
            testCase.verifyEqual(config.validation.thresholds.year_min, 1980);
        end

        function testMigrationBatchOverridesYearMin(testCase)
            % load_config('migration') should set year_min to 1970
            config = load_config('migration');
            testCase.verifyEqual(config.validation.thresholds.year_min, 1970);
        end

        function testMigrationBatchSetsOverrideFilePath(testCase)
            config = load_config('migration');
            testCase.verifyFalse(isempty(config.validation.overrides.csv_path), ...
                'Migration batch should set a non-empty overrides csv_path');
        end

        function testMigrationBatchAllowsUnknownLookupCodes(testCase)
            config = load_config('migration');
            testCase.verifyTrue(config.validation.allow_unknown_lookup_codes);
        end

        function testNonexistentBatchErrors(testCase)
            % load_config('nonexistent') should error with BatchNotFound
            testCase.verifyError(@() load_config('nonexistent'), ...
                'load_config:BatchNotFound');
        end

        function testNestedMergePreservesUnoverriddenFields(testCase)
            % Migration batch only overrides some validation fields;
            % unmentioned nested fields (e.g., pipeline.chunk_size) survive.
            config = load_config('migration');
            testCase.verifyEqual(config.pipeline.chunk_size, 10000, ...
                'Unoverridden pipeline fields should keep their defaults');
        end

        function testDefaultOverridesCsvPathIsEmpty(testCase)
            % Without a batch, overrides.csv_path should be empty
            config = load_config();
            testCase.verifyEmpty(config.validation.overrides.csv_path, ...
                'Default overrides.csv_path should be empty (no batch)');
        end

        function testMigrationDbSettingsInheritDefaults(testCase)
            % Migration batch does not override db settings;
            % they should still come from defaults.
            config_default    = load_config();
            config_migration  = load_config('migration');
            testCase.verifyEqual(config_migration.db.Type, config_default.db.Type);
            testCase.verifyEqual(config_migration.db.Server, config_default.db.Server);
        end

    end
end
