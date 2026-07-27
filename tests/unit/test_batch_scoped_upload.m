classdef test_batch_scoped_upload < matlab.unittest.TestCase
    % TEST_BATCH_SCOPED_UPLOAD Unit tests for BatchUploader.uploadFromFolder's
    % 'SplitSummaryFile'/'BatchId' filtering (see BatchUploader.filterToBatch),
    % which narrows a folder-wide upload run down to one batch's FILEIDs.
    %
    % No database connection required (MockBatchConn stub).

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

        function testSplitSummaryFileFiltersToMatchingFileids(testCase)
            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);

            base_dir = fullfile(pwd, 'staging');
            pending_dir = fullfile(base_dir, 'pending');
            mkdir(pending_dir);

            % Two "batches" worth of files sitting in pending/ at once.
            writetable(make_survey('aA00001'), fullfile(pending_dir, 'aA00001.csv'));
            writetable(make_survey('aA00002'), fullfile(pending_dir, 'aA00002.csv'));
            writetable(make_survey('bB00001'), fullfile(pending_dir, 'bB00001.csv'));

            % A split-summary log describing only the 'A' batch.
            summary_path = fullfile(tempname, '_split_summary_20260101_000000.log');
            mkdir(fileparts(summary_path));
            fid = fopen(summary_path, 'w');
            fprintf(fid, 'Total surveys: 2\nTotal rows: 2\nTime elapsed: 0.1 minutes\n');
            fprintf(fid, '\nSurvey file row counts:\n-----------------------\n');
            fprintf(fid, 'aA00001: 1 rows\naA00002: 1 rows\n');
            fclose(fid);

            conn = MockBatchConn();
            uploader = narwc.ingestion.BatchUploader(conn, base_dir);
            uploader.uploadFromFolder('Validate', false, 'SplitSummaryFile', summary_path);

            testCase.verifyEqual(conn.insert_call_count, 2, ...
                'Only the 2 files belonging to the scoped batch should be uploaded');
            testCase.verifyTrue(exist(fullfile(base_dir, 'processed', 'aA00001.csv'), 'file') == 2);
            testCase.verifyTrue(exist(fullfile(base_dir, 'processed', 'aA00002.csv'), 'file') == 2);
            testCase.verifyTrue(exist(fullfile(pending_dir, 'bB00001.csv'), 'file') == 2, ...
                'The unscoped file must be left untouched in pending/');

            rmdir(fileparts(summary_path), 's');
        end

        function testUnknownBatchIdErrors(testCase)
            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);

            base_dir = fullfile(pwd, 'staging');
            mkdir(fullfile(base_dir, 'pending'));

            conn = MockBatchConn();
            uploader = narwc.ingestion.BatchUploader(conn, base_dir);

            testCase.verifyError( ...
                @() uploader.uploadFromFolder('Validate', false, ...
                    'BatchId', 'this-batch-id-does-not-exist-anywhere'), ...
                'narwc:ingestion:BatchUploader:UnknownBatchId');
        end

        function testNoFilterOptionsProcessesEverything(testCase)
            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);

            base_dir = fullfile(pwd, 'staging');
            pending_dir = fullfile(base_dir, 'pending');
            mkdir(pending_dir);

            writetable(make_survey('aA00001'), fullfile(pending_dir, 'aA00001.csv'));
            writetable(make_survey('bB00001'), fullfile(pending_dir, 'bB00001.csv'));

            conn = MockBatchConn();
            uploader = narwc.ingestion.BatchUploader(conn, base_dir);
            uploader.uploadFromFolder('Validate', false);

            testCase.verifyEqual(conn.insert_call_count, 2, ...
                'Default (no BatchId/SplitSummaryFile) must still process everything in pending/');
        end

    end
end


% =========================================================================
% Helpers
% =========================================================================

function data = make_survey(fileid)
data = table( ...
    {fileid}, ...
    41.5, -70.2, 2011, 10, 9, 1, {'RIWH'}, ...
    'VariableNames', {'FILEID','LAT_DD','LONG_DD','YEAR','MONTH','DAY','NUMBER','SPECCODE'});
end
