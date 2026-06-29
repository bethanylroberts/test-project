classdef test_upload_guardrail < matlab.unittest.TestCase
    % TEST_UPLOAD_GUARDRAIL Verify BatchUploader rejects test-fixture FILEIDs.
    %
    % These tests do not require a database connection. The guardrail check
    % fires before any DB call, so a mock connection object is sufficient.

    methods (TestClassSetup)
        function setupPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            fixtures_path = fullfile(fileparts(here), 'fixtures');
            if ~contains(path, fixtures_path)
                addpath(fixtures_path);
            end
        end
    end

    methods (Test)

        function testUploadSurveyRejectsTestFileid(testCase)
            % uploadSurvey must refuse a survey whose FILEID has 'T' in position 2.
            conn = MockConnection();
            converter = narwc.ingestion.BatchUploader(conn, tempdir());

            data = make_survey('aT11282');

            [success, category] = converter.uploadSurvey(data);

            testCase.verifyFalse(success, ...
                'uploadSurvey should return success=false for a T-position-2 FILEID');
            testCase.verifyEqual(category, 'failed', ...
                'uploadSurvey should categorize T-FILEID surveys as failed');

            % Confirm no DB write was attempted
            testCase.verifyEqual(conn.insert_call_count, 0, ...
                'No DB insert should occur when FILEID has position 2 = T');
        end

        function testUploadSurveyAcceptsNormalFileid(testCase)
            % Surveys without 'T' in position 2 must not be rejected by the guardrail.
            % (The mock connection will fail on the actual DB call, but that is
            %  separate from the guardrail — so we only check the guardrail did not
            %  set success=false before the DB call is reached.)
            conn = MockConnection();
            converter = narwc.ingestion.BatchUploader(conn, tempdir());

            data = make_survey('a111282');

            % The mock connection will throw on fetch (surveyExists), causing an
            % error path, but the guardrail should NOT have fired.
            [~, category] = converter.uploadSurvey(data, 'Validate', false);

            testCase.verifyNotEqual(category, 'guardrail_rejected', ...
                'Normal FILEID should not be rejected by the T-position-2 guardrail');
            testCase.verifyGreaterThanOrEqual(conn.fetch_call_count, 1, ...
                'DB fetch (surveyExists) must have been attempted for a normal FILEID');
        end

        function testUploadFromFolderRejectsTestFileid(testCase)
            % uploadFromFolder must also reject T-position-2 FILEIDs before
            % calling uploadSurvey, and move the file to the failed folder.
            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);

            base_dir = fullfile(pwd, 'survey_staging');
            pending_dir = fullfile(base_dir, 'pending');
            mkdir(pending_dir);

            % Write a fixture-flagged survey CSV into pending/
            data = make_survey('fT00007');
            writetable(data, fullfile(pending_dir, 'fT00007.csv'));

            conn = MockConnection();
            converter = narwc.ingestion.BatchUploader(conn, base_dir);
            converter.uploadFromFolder('Validate', false);

            stats = converter.getStats();
            testCase.verifyEqual(stats.failed, 1, ...
                'uploadFromFolder should count the T-FILEID survey as failed');
            testCase.verifyEqual(conn.insert_call_count, 0, ...
                'No DB insert should occur for a T-FILEID survey in uploadFromFolder');

            failed_file = fullfile(base_dir, 'failed', 'fT00007.csv');
            testCase.verifyTrue(exist(failed_file, 'file') == 2, ...
                'Rejected survey file should be moved to the failed/ folder');
        end

    end

end


% =========================================================================
% Helpers
% =========================================================================

function data = make_survey(fileid)
% Build a minimal survey table with one event row.
data = table( ...
    {fileid}, ...
    41.5, ...
    -70.2, ...
    2011, ...
    10, ...
    9, ...
    1, ...
    {'RIWH'}, ...
    'VariableNames', {'FILEID','LAT_DD','LONG_DD','YEAR','MONTH','DAY','NUMBER','SPECCODE'});
end


% MockConnection is defined in tests/fixtures/MockConnection.m
