classdef test_config_loader < matlab.unittest.TestCase
    % TEST_CONFIG_LOADER Unit tests for config/load_config.m

    methods (Test)

        function testDefaultsReturnExpectedSections(testCase)
            config = load_config();
            testCase.verifyTrue(isfield(config, 'db'),         'config.db missing');
            testCase.verifyTrue(isfield(config, 'validation'), 'config.validation missing');
            testCase.verifyTrue(isfield(config, 'pipeline'),   'config.pipeline missing');
        end

        function testDefaultDbHasRequiredFields(testCase)
            config = load_config();
            testCase.verifyTrue(isfield(config.db, 'Type'));
            testCase.verifyTrue(isfield(config.db, 'Server'));
            testCase.verifyTrue(isfield(config.db, 'Username'));
            testCase.verifyTrue(isfield(config.db, 'Password'));
        end

        function testDefaultValidationHasDetailedSections(testCase)
            config = load_config();
            testCase.verifyTrue(isfield(config.validation, 'datetime'));
            testCase.verifyTrue(isfield(config.validation, 'coordinates'));
            testCase.verifyTrue(isfield(config.validation, 'species'));
            testCase.verifyTrue(isfield(config.validation, 'environmental'));
            testCase.verifyTrue(isfield(config.validation, 'behavioral'));
        end

        function testDefaultYearMin(testCase)
            config = load_config();
            testCase.verifyEqual(config.validation.datetime.year_min, 1970);
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
            testCase.verifyError(@() load_config('nonexistent'), ...
                'load_config:BatchNotFound');
        end

        function testNestedMergePreservesUnoverriddenFields(testCase)
            % Migration batch overrides some validation fields but not all;
            % unmentioned fields (e.g., pipeline.chunk_size) should survive.
            config = load_config('migration');
            testCase.verifyEqual(config.pipeline.chunk_size, 10000);
        end

        function testDefaultOverridesCsvPathIsEmpty(testCase)
            config = load_config();
            testCase.verifyEmpty(config.validation.overrides.csv_path);
        end

        function testMigrationDbSettingsInheritDefaults(testCase)
            % Migration batch does not touch db settings.
            config_default   = load_config();
            config_migration = load_config('migration');
            testCase.verifyEqual(config_migration.db.Type,   config_default.db.Type);
            testCase.verifyEqual(config_migration.db.Server, config_default.db.Server);
        end

    end
end
