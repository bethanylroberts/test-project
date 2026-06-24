classdef test_characterization_batch < matlab.unittest.TestCase
    % TEST_CHARACTERIZATION_BATCH Characterization tests for BatchConverter and
    % SurveyValidator.
    %
    % Two separate concerns:
    %
    %   1. BatchConverter guardrail path: uploadFromFolder must reject all
    %      T-FILEID fixtures before any DB call is attempted.
    %
    %   2. SurveyValidator smoke test: validate() must run to completion on a
    %      real fixture and return a well-formed result struct.  Exact error/
    %      warning counts are NOT asserted here -- update the baseline comment
    %      after the first real run.
    %
    % No database connection required.

    properties
        fixture_dir
    end

    methods (TestClassSetup)
        function setupPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            test_root = fileparts(here);
            fixtures_path = fullfile(test_root, 'fixtures');
            if ~contains(path, fixtures_path)
                addpath(fixtures_path);
            end
        end
    end

    methods (TestMethodSetup)
        function setFixtureDir(testCase)
            here = fileparts(mfilename('fullpath'));
            test_root = fileparts(here);
            testCase.fixture_dir = fullfile(test_root, 'fixtures', 'sample_data');
        end
    end

    % =====================================================================
    % BatchConverter guardrail
    % =====================================================================

    methods (Test)

        function testUploadFromFolderRejectsAllTestFixtures(testCase)
            % uploadFromFolder must reject every T-FILEID survey before any
            % DB operation.  Both files go to failed/.

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);

            base_dir = fullfile(pwd, 'staging');
            pending_dir = fullfile(base_dir, 'pending');
            mkdir(pending_dir);

            % Copy two small fixtures into pending/
            copyfile(fullfile(testCase.fixture_dir, 'fT00157.csv'), ...
                     fullfile(pending_dir, 'fT00157.csv'));
            copyfile(fullfile(testCase.fixture_dir, 'HT63070.csv'), ...
                     fullfile(pending_dir, 'HT63070.csv'));

            conn = MockBatchConn();
            converter = migration.BatchConverter(conn, base_dir);
            converter.uploadFromFolder('Validate', false);

            stats = converter.getStats();

            testCase.verifyEqual(stats.failed, 2, ...
                'Both T-FILEID files must be counted as failed');
            testCase.verifyEqual(conn.insert_call_count, 0, ...
                'No DB insert must occur for T-FILEID fixtures');

            testCase.verifyTrue( ...
                exist(fullfile(base_dir, 'failed', 'fT00157.csv'), 'file') == 2, ...
                'fT00157.csv must be moved to failed/');
            testCase.verifyTrue( ...
                exist(fullfile(base_dir, 'failed', 'HT63070.csv'), 'file') == 2, ...
                'HT63070.csv must be moved to failed/');
        end

        function testUploadFromFolderNoDbCallOnGuardrail(testCase)
            % Neither fetch nor insert must be called when the guardrail fires.

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);

            base_dir = fullfile(pwd, 'staging');
            pending_dir = fullfile(base_dir, 'pending');
            mkdir(pending_dir);

            copyfile(fullfile(testCase.fixture_dir, 'fT00157.csv'), ...
                     fullfile(pending_dir, 'fT00157.csv'));

            conn = MockBatchConn();
            converter = migration.BatchConverter(conn, base_dir);
            converter.uploadFromFolder('Validate', false);

            testCase.verifyEqual(conn.fetch_call_count, 0, ...
                'No DB fetch must occur when guardrail rejects file');
            testCase.verifyEqual(conn.insert_call_count, 0, ...
                'No DB insert must occur when guardrail rejects file');
        end

    end

    % =====================================================================
    % SurveyValidator smoke / characterization
    % =====================================================================

    methods (Test)

        function testValidatorRunsOnFixture(testCase)
            % validate() must complete without error on a real fixture and
            % return a struct with the required fields.
            %
            % BASELINE (update after first run):
            %   Record actual error/warning counts from aT11110 here so
            %   future refactors cannot silently change validation behaviour.

            fixture_path = fullfile(testCase.fixture_dir, 'aT11110.csv');
            data = readtable(fixture_path);

            validator = narwc.validation.SurveyValidator();
            [is_valid, results] = validator.validate(data);

            % Result must be a logical
            testCase.verifyClass(is_valid, 'logical');

            % Result struct must have the standard fields
            testCase.verifyTrue(isfield(results, 'errors'));
            testCase.verifyTrue(isfield(results, 'warnings'));
            testCase.verifyTrue(isfield(results, 'info'));
            testCase.verifyTrue(isfield(results, 'summary'));
            testCase.verifyTrue(isfield(results, 'error_details'));

            % Summary must have numeric counts
            testCase.verifyTrue(isfield(results.summary, 'errors'));
            testCase.verifyTrue(isfield(results.summary, 'warnings'));
            testCase.verifyClass(results.summary.errors, 'double');
            testCase.verifyClass(results.summary.warnings, 'double');
        end

        function testValidatorResultIsReproducible(testCase)
            % Running validate() twice on the same data must return the same
            % error and warning counts (no random or state-dependent behaviour).

            fixture_path = fullfile(testCase.fixture_dir, 'aT11110.csv');
            data = readtable(fixture_path);

            validator = narwc.validation.SurveyValidator();
            [~, r1] = validator.validate(data);
            [~, r2] = validator.validate(data);

            testCase.verifyEqual(r1.summary.errors, r2.summary.errors, ...
                'Error count must be reproducible');
            testCase.verifyEqual(r1.summary.warnings, r2.summary.warnings, ...
                'Warning count must be reproducible');
        end

        function testValidatorDifferentFixturesGiveDifferentCounts(testCase)
            % A large dense fixture (aT11110, 328 rows) and a tiny one
            % (HT63070, 12 rows) should not produce identical error counts,
            % which would suggest the counts are not actually computed.

            data_large = readtable(fullfile(testCase.fixture_dir, 'aT11110.csv'));
            data_small = readtable(fullfile(testCase.fixture_dir, 'HT63070.csv'));

            validator = narwc.validation.SurveyValidator();
            [~, r_large] = validator.validate(data_large);
            [~, r_small] = validator.validate(data_small);

            % Total issues must differ (different row counts guarantee this
            % unless validation is completely broken or data is identical).
            total_large = r_large.summary.errors + r_large.summary.warnings;
            total_small = r_small.summary.errors + r_small.summary.warnings;

            testCase.verifyNotEqual(total_large, total_small, ...
                'Validation counts for fixtures of very different sizes should differ');
        end

    end

end
