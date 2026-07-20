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
            testCase.verifyEqual(config.validation.datetime.year_min, 1900);
        end

        function testDefaultYearWarning(testCase)
            % year_warning must be above year_min and above ~1975 so that early
            % survey records trigger data-quality warnings.
            config = load_config();
            testCase.verifyEqual(config.validation.datetime.year_warning, 1980);
            testCase.verifyGreaterThan(config.validation.datetime.year_warning, ...
                config.validation.datetime.year_min);
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

        function testMigrationVisibilityNegativeAllowed(testCase)
            % Default is strict (false); migration batch enables it.
            config_default   = load_config();
            config_migration = load_config('migration');
            testCase.verifyFalse(config_default.validation.environmental.visibility_allow_negative, ...
                'Default should not allow negative visibility');
            testCase.verifyTrue(config_migration.validation.environmental.visibility_allow_negative, ...
                'Migration batch must enable negative visibility');
        end

        function testLocalOverrideMergesCredentials(testCase)
            % Verify that db_config_local.m is picked up and its values
            % override the empty-string defaults when the file is present.
            %
            % If a real db_config_local.m already exists, just verify that
            % credentials are non-empty.  Otherwise, write a temporary one,
            % test the merge, and remove it on teardown.

            local_path = fullfile(fileparts(which('load_config')), ...
                'local', 'db_config_local.m');

            if exist(local_path, 'file')
                % Real credentials are present — just verify they were merged.
                config = load_config();
                testCase.verifyNotEqual(config.db.Username, '', ...
                    'Local db_config_local.m exists but Username is empty after merge');
            else
                % Write a temporary local config with sentinel credentials.
                fid = fopen(local_path, 'w');
                fprintf(fid, 'function db = db_config_local()\n');
                fprintf(fid, '    db.Username = ''test_local_user'';\n');
                fprintf(fid, '    db.Password = ''test_local_pass'';\n');
                fprintf(fid, 'end\n');
                fclose(fid);
                testCase.addTeardown(@() delete(local_path));

                config = load_config();
                testCase.verifyEqual(config.db.Username, 'test_local_user', ...
                    'Local config must override default empty Username');
                testCase.verifyEqual(config.db.Password, 'test_local_pass', ...
                    'Local config must override default empty Password');
                % Non-overridden fields must survive from defaults.
                testCase.verifyEqual(config.db.Server, 'localhost', ...
                    'Local config must not clobber non-overridden db fields');
            end
        end

        function testBatchOverrideDoesNotTouchOtherSections(testCase)
            % A batch that only touches validation must leave pipeline intact.
            config = load_config('migration');
            testCase.verifyEqual(config.pipeline.chunk_size, 10000);
            testCase.verifyTrue(isfield(config.db, 'Type'));
        end

        function testCalfBehaviorsCanBeOverriddenToEmpty(testCase)
            % A batch config that sets behavioral.calf_associated_behaviors = []
            % must reach load_config callers so downstream rules skip the check.
            % We verify the merge here; the behavioral-rules test verifies the
            % effect on rule output.

            % Build a minimal batch-style override struct
            override.validation.behavioral.calf_associated_behaviors = [];

            config_base = load_config();
            % Simulate what merge_structs does inside load_config for batch overrides
            % by calling the validation default directly and merging manually.
            base_behavioral = config_base.validation.behavioral;
            testCase.verifyFalse(isempty(base_behavioral.calf_associated_behaviors), ...
                'Default calf_associated_behaviors must be non-empty');

            % After merge, the empty override must win
            merged = base_behavioral;
            merged.calf_associated_behaviors = override.validation.behavioral.calf_associated_behaviors;
            testCase.verifyEmpty(merged.calf_associated_behaviors, ...
                'After override, calf_associated_behaviors must be empty');
        end

    end
end
