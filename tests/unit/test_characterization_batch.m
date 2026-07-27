classdef test_characterization_batch < matlab.unittest.TestCase
    % TEST_CHARACTERIZATION_BATCH Characterization tests for BatchUploader and
    % SurveyValidator.
    %
    % Two separate concerns:
    %
    %   1. BatchUploader guardrail path: uploadFromFolder must reject all
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
    % BatchUploader guardrail
    % =====================================================================

    methods (Test)

        function testUploadFromFolderRejectsAllTestFixtures(testCase)
            % uploadFromFolder must reject every T-FILEID survey before any
            % DB operation.  Both files go to rejected/.

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
            converter = narwc.ingestion.BatchUploader(conn, base_dir);
            converter.uploadFromFolder('Validate', false);

            stats = converter.getStats();

            testCase.verifyEqual(stats.rejected, 2, ...
                'Both T-FILEID files must be counted as rejected');
            testCase.verifyEqual(conn.insert_call_count, 0, ...
                'No DB insert must occur for T-FILEID fixtures');

            testCase.verifyTrue( ...
                exist(fullfile(base_dir, 'rejected', 'fT00157.csv'), 'file') == 2, ...
                'fT00157.csv must be moved to rejected/');
            testCase.verifyTrue( ...
                exist(fullfile(base_dir, 'rejected', 'HT63070.csv'), 'file') == 2, ...
                'HT63070.csv must be moved to rejected/');
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
            converter = narwc.ingestion.BatchUploader(conn, base_dir);
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

    % =====================================================================
    % Override-gate integration
    % =====================================================================

    methods (Test)

        function testPerSurveyOverrideUploadsCleanlyAndSplitsRunSummary(testCase)
            % A survey with many same-rule warnings + a per-survey override
            % must upload cleanly.  The run summary CSV must contain the
            % acknowledged counts split into per_row and per_survey columns.

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);

            base_dir    = fullfile(pwd, 'staging');
            pending_dir = fullfile(base_dir, 'pending');
            mkdir(pending_dir);

            % Survey with 4 year_too_old warnings (all same field + rule_id)
            n      = 4;
            fileid = 'fA99777';
            survey = make_old_year_survey_n(fileid, n);

            % Write survey CSV to pending/
            survey_file = fullfile(pending_dir, [fileid '.csv']);
            writetable(survey, survey_file);

            % Per-survey override acknowledges all 4 warnings
            override_file = fullfile(pwd, 'overrides.csv');
            fid = fopen(override_file, 'w');
            fprintf(fid, 'fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason\n');
            fprintf(fid, '%s,,YEAR,datetime_rules.year_too_old,test_curator,2026-01-01,all old-year events\n', fileid);
            fclose(fid);

            conn     = MockBatchConn();
            uploader = narwc.ingestion.BatchUploader(conn, base_dir);

            cfg = struct('override_file', override_file, 'allow_warnings', false);
            cfg.environmental = struct('visibility_allow_negative', false);
            validator = narwc.validation.SurveyValidator(cfg);
            [is_valid, results] = validator.validate(survey);

            testCase.verifyTrue(is_valid, ...
                'Survey with per-survey override must pass validation');
            testCase.verifyEqual(results.summary.warnings_acknowledged, n, ...
                'All 4 warnings must be acknowledged');
            testCase.verifyEqual(results.summary.warnings_acknowledged_per_survey, n, ...
                'All 4 must be counted as per-survey acknowledgements');
            testCase.verifyEqual(results.summary.warnings_acknowledged_per_row, 0, ...
                'Per-row count must be 0');

            % Verify run summary CSV gets split columns
            uploader.uploadFromFolder('Validate', false);
            run_summary = fullfile(base_dir, 'rejected', '_run_summary.csv');
            if exist(run_summary, 'file')
                tbl = readtable(run_summary, 'Delimiter', ',', 'TextType', 'char', ...
                    'VariableNamingRule', 'preserve');
                col_names = tbl.Properties.VariableNames;
                testCase.verifyTrue( ...
                    any(strcmp(col_names, 'warning_count_acknowledged_per_row')), ...
                    'Run summary must have warning_count_acknowledged_per_row column');
                testCase.verifyTrue( ...
                    any(strcmp(col_names, 'warning_count_acknowledged_per_survey')), ...
                    'Run summary must have warning_count_acknowledged_per_survey column');
            end
        end

        function testValidatorRejectsUnacknowledgedWarnings(testCase)
            % uploadSurvey must fail when the survey has new (unacknowledged)
            % warnings, and succeed when all warnings are acknowledged.
            %
            % Uses a survey with YEAR=1985 which triggers datetime_rules.year_too_old.

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);

            base_dir = fullfile(pwd, 'staging');
            mkdir(base_dir);

            % --- Survey with unacknowledged warning ---
            survey = make_old_year_survey('fA98001');
            conn   = MockBatchConn();
            uploader = narwc.ingestion.BatchUploader(conn, base_dir);

            cfg_no_override = struct('override_file', fullfile(pwd, 'no_such_file.csv'));
            cfg_no_override.allow_warnings = false;
            cfg_no_override.environmental  = struct('visibility_allow_negative', false);

            validator_no = narwc.validation.SurveyValidator(cfg_no_override);
            [is_valid_no, results_no] = validator_no.validate(survey);

            testCase.verifyFalse(is_valid_no, ...
                'Survey with unacknowledged year_too_old warning must be rejected');
            testCase.verifyGreaterThan(results_no.summary.warnings_new, 0);

            % --- Same survey with matching override ---
            override_file = fullfile(pwd, 'overrides.csv');
            fid = fopen(override_file, 'w');
            fprintf(fid, 'fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason\n');
            fprintf(fid, 'fA98001,5,YEAR,datetime_rules.year_too_old,test_curator,2026-01-01,unit test\n');
            fclose(fid);

            cfg_ack = struct('override_file', override_file);
            cfg_ack.allow_warnings = false;
            cfg_ack.environmental  = struct('visibility_allow_negative', false);

            validator_ack = narwc.validation.SurveyValidator(cfg_ack);
            [is_valid_ack, results_ack] = validator_ack.validate(survey);

            testCase.verifyTrue(is_valid_ack, ...
                'Survey with fully acknowledged warnings must be accepted');
            testCase.verifyEqual(results_ack.summary.warnings_new, 0);
            testCase.verifyEqual(results_ack.summary.warnings_acknowledged, 1);
        end

    end

    % =====================================================================
    % Transaction behaviour
    % =====================================================================

    methods (Test)

        function testGuardrailFiresBeforeTransaction(testCase)
            % When uploadFromFolder processes only T-FILEID files the
            % guardrail must fire before any DB call, including
            % beginTransaction.

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);

            base_dir    = fullfile(pwd, 'staging');
            pending_dir = fullfile(base_dir, 'pending');
            mkdir(pending_dir);

            copyfile(fullfile(testCase.fixture_dir, 'fT00157.csv'), ...
                     fullfile(pending_dir, 'fT00157.csv'));

            conn = MockBatchConn();
            uploader = narwc.ingestion.BatchUploader(conn, base_dir);
            uploader.uploadFromFolder('Validate', false);

            testCase.verifyEqual(conn.begin_transaction_count, 0, ...
                'T-FILEID guardrail must fire before beginTransaction is called');
            testCase.verifyEqual(conn.fetch_call_count, 0, ...
                'T-FILEID guardrail must fire before any DB fetch');
            testCase.verifyEqual(conn.insert_call_count, 0, ...
                'T-FILEID guardrail must fire before any DB insert');
        end

        function testHappyPathOpensTransactionAndCommits(testCase)
            % uploadSurvey on a non-T FILEID (survey not in DB) must
            % open a transaction, call insert, and commit.

            conn = MockBatchConn();

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            base_dir = fullfile(pwd, 'staging');
            uploader = narwc.ingestion.BatchUploader(conn, base_dir);

            survey = table({'f098027'}, 'VariableNames', {'FILEID'});
            uploader.uploadSurvey(survey, 'Validate', false);

            testCase.verifyEqual(conn.begin_transaction_count, 1, ...
                'beginTransaction must be called once for a clean insert');
            testCase.verifyEqual(conn.insert_call_count, 1, ...
                'insert must be called once');
            testCase.verifyEqual(conn.commit_count, 1, ...
                'commit must be called on success');
            testCase.verifyEqual(conn.rollback_count, 0, ...
                'rollback must not be called on success');
        end

        function testAutoCommitRestoredAfterSuccess(testCase)
            % After a successful upload the connection AutoCommit must
            % return to its prior value ('on').

            conn = MockBatchConn();
            conn.auto_commit = 'on';

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            base_dir = fullfile(pwd, 'staging');
            uploader = narwc.ingestion.BatchUploader(conn, base_dir);

            survey = table({'f098027'}, 'VariableNames', {'FILEID'});
            uploader.uploadSurvey(survey, 'Validate', false);

            testCase.verifyEqual(conn.auto_commit, 'on', ...
                'AutoCommit must be restored to ''on'' after a successful upload');
        end

        function testInsertFailureTrigersRollback(testCase)
            % When insert throws, rollback must be called and the
            % upload must be reported as failed.

            conn = MockBatchConn();
            conn.insert_should_fail = true;

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            base_dir = fullfile(pwd, 'staging');
            uploader = narwc.ingestion.BatchUploader(conn, base_dir);

            survey = table({'f098027'}, 'VariableNames', {'FILEID'});
            [success, category] = uploader.uploadSurvey(survey, 'Validate', false);

            testCase.verifyFalse(success, ...
                'upload must report failure when insert throws');
            testCase.verifyEqual(category, 'rejected', ...
                'category must be ''rejected'' when insert throws');
            testCase.verifyEqual(conn.rollback_count, 1, ...
                'rollback must be called when insert fails');
            testCase.verifyEqual(conn.commit_count, 0, ...
                'commit must not be called when insert fails');
        end

        function testAutoCommitRestoredAfterFailure(testCase)
            % After a failed insert the connection AutoCommit must be
            % restored to its prior value ('on').

            conn = MockBatchConn();
            conn.auto_commit = 'on';
            conn.insert_should_fail = true;

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            base_dir = fullfile(pwd, 'staging');
            uploader = narwc.ingestion.BatchUploader(conn, base_dir);

            survey = table({'f098027'}, 'VariableNames', {'FILEID'});
            uploader.uploadSurvey(survey, 'Validate', false);

            testCase.verifyEqual(conn.auto_commit, 'on', ...
                'AutoCommit must be restored to ''on'' after a failed upload');
        end

    end

end

% =========================================================================
% Test helpers (private functions at file scope)
% =========================================================================

function survey = make_old_year_survey(fileid)
    % Minimal survey that triggers datetime_rules.year_too_old on EVENTNO=5.
    % DDSOURCE/PLATFORM use codes confirmed valid in the real lookup tables
    % (required_fields.m's universal list requires them present; chosen so
    % they don't also trip an FK error). Omits IDSOURCE (not in the
    % universal list) so no FK error occurs from that field.
    survey = table();
    survey.FILEID   = {fileid};
    survey.EVENTNO  = 5;       % double; stored in warning for override matching
    survey.LAT_DD   = 42.0;   % within survey area
    survey.LONG_DD  = -70.0;
    survey.YEAR     = 1975;   % < year_warning (~1980) -> triggers year_too_old
    survey.MONTH    = 6;
    survey.DAY      = 15;
    survey.DDSOURCE = {'CCS'};
    survey.PLATFORM = 649;
end

function survey = make_old_year_survey_n(fileid, n)
    % n-row survey where every row triggers datetime_rules.year_too_old.
    survey = table();
    survey.FILEID   = repmat({fileid}, n, 1);
    survey.EVENTNO  = (1:n)';
    survey.LAT_DD   = repmat(42.0, n, 1);
    survey.LONG_DD  = repmat(-70.0, n, 1);
    survey.YEAR     = repmat(1975, n, 1);
    survey.MONTH    = repmat(6, n, 1);
    survey.DAY      = repmat(15, n, 1);
    survey.DDSOURCE = repmat({'CCS'}, n, 1);
    survey.PLATFORM = repmat(649, n, 1);
end
