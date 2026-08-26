classdef test_batch_log < matlab.unittest.TestCase
    % TEST_BATCH_LOG Unit tests for the batch ledger helpers used by
    % convert_contributor_batch.m / upload_contributor_batch.m / validate_batch.m:
    %   narwc.ingestion.append_batch_log
    %   narwc.ingestion.read_batch_log
    %   narwc.ingestion.check_prior_conversion
    %
    % All tests point log_path at a temp file so nothing touches the real
    % project ledger (data/surveys/batch_log.csv).

    properties
        log_path
    end

    methods (TestMethodSetup)
        function setupLogPath(testCase)
            testCase.log_path = fullfile(tempname, 'batch_log.csv');
        end
    end

    methods (TestMethodTeardown)
        function cleanupLogPath(testCase)
            d = fileparts(testCase.log_path);
            if exist(d, 'dir')
                rmdir(d, 's');
            end
        end
    end

    methods (Test)

        function testReadReturnsEmptyTableWhenMissing(testCase)
            tbl = narwc.ingestion.read_batch_log(testCase.log_path);
            testCase.verifyEqual(height(tbl), 0);
            testCase.verifyEqual(tbl.Properties.VariableNames, ...
                {'batch_id', 'stage', 'source', 'timestamp', 'input', 'output', ...
                 'total_surveys', 'total_rows', 'notes'});
        end

        function testAppendCreatesFileWithHeaderAndRow(testCase)
            narwc.ingestion.append_batch_log(struct( ...
                'batch_id', 'B1', 'stage', 'convert', 'source', 'legacy', ...
                'input', 'in.csv', 'output', 'out.log', ...
                'total_surveys', 5, 'total_rows', 50), testCase.log_path);

            testCase.verifyTrue(exist(testCase.log_path, 'file') == 2);
            tbl = narwc.ingestion.read_batch_log(testCase.log_path);
            testCase.verifyEqual(height(tbl), 1);
            testCase.verifyEqual(tbl.batch_id{1}, 'B1');
            testCase.verifyEqual(tbl.stage{1}, 'convert');
            testCase.verifyEqual(tbl.source{1}, 'legacy');
            testCase.verifyEqual(tbl.total_surveys(1), 5);
            testCase.verifyEqual(tbl.total_rows(1), 50);
        end

        function testAppendAddsRowsAcrossCalls(testCase)
            narwc.ingestion.append_batch_log(struct('batch_id', 'B1', ...
                'stage', 'convert', 'source', 'legacy', 'input', 'in.csv'), testCase.log_path);
            narwc.ingestion.append_batch_log(struct('batch_id', 'B1', ...
                'stage', 'upload', 'source', 'legacy', 'notes', 'ok'), testCase.log_path);

            tbl = narwc.ingestion.read_batch_log(testCase.log_path);
            testCase.verifyEqual(height(tbl), 2);
            testCase.verifyEqual(tbl.stage, {'convert'; 'upload'});
        end

        function testAppendEscapesCommasInFreeTextFields(testCase)
            narwc.ingestion.append_batch_log(struct( ...
                'batch_id', 'B1', 'stage', 'upload', 'source', 'legacy', ...
                'notes', 'uploaded=4, rejected=1'), testCase.log_path);

            tbl = narwc.ingestion.read_batch_log(testCase.log_path);
            testCase.verifyEqual(height(tbl), 1);
            testCase.verifyEqual(tbl.notes{1}, 'uploaded=4; rejected=1');
        end

        function testCheckPriorConversionFindsMatch(testCase)
            narwc.ingestion.append_batch_log(struct( ...
                'batch_id', 'B1', 'stage', 'convert', 'source', 'legacy', ...
                'input', 'data/surveys/raw/legacy/RUSS_24_VALID.CSV', ...
                'total_surveys', 5, 'total_rows', 50), testCase.log_path);

            prior = narwc.ingestion.check_prior_conversion( ...
                'data/surveys/raw/legacy/RUSS_24_VALID.CSV', testCase.log_path);

            testCase.verifyEqual(height(prior), 1);
            testCase.verifyEqual(prior.batch_id{1}, 'B1');
        end

        function testCheckPriorConversionNoMatch(testCase)
            narwc.ingestion.append_batch_log(struct( ...
                'batch_id', 'B1', 'stage', 'convert', 'source', 'legacy', ...
                'input', 'data/surveys/raw/legacy/RUSS_24_VALID.CSV'), testCase.log_path);

            prior = narwc.ingestion.check_prior_conversion( ...
                'data/surveys/raw/CCS', testCase.log_path);

            testCase.verifyEqual(height(prior), 0);
        end

        function testCheckPriorConversionIgnoresNonConvertStage(testCase)
            narwc.ingestion.append_batch_log(struct( ...
                'batch_id', 'B1', 'stage', 'upload', 'source', 'legacy', ...
                'input', 'data/surveys/raw/legacy/RUSS_24_VALID.CSV'), testCase.log_path);

            prior = narwc.ingestion.check_prior_conversion( ...
                'data/surveys/raw/legacy/RUSS_24_VALID.CSV', testCase.log_path);

            testCase.verifyEqual(height(prior), 0);
        end

        function testCheckPriorConversionEmptyLedger(testCase)
            prior = narwc.ingestion.check_prior_conversion('anything', testCase.log_path);
            testCase.verifyEqual(height(prior), 0);
        end

    end
end
