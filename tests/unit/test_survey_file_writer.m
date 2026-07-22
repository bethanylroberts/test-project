classdef test_survey_file_writer < matlab.unittest.TestCase
    % TEST_SURVEY_FILE_WRITER Unit tests for SurveyFileWriter.
    %
    % Covers the FILEID-grouping/writing behaviour extracted from
    % SurveyExtractor: header-on-first-write vs append-without-header,
    % dropped-FILEID row counting, filename sanitization, multi-chunk
    % accumulation, and the finalize() summary file.

    properties
        output_dir
    end

    methods (TestMethodSetup)
        function setupDir(testCase)
            testCase.output_dir = tempname;
            mkdir(testCase.output_dir);
        end
    end

    methods (TestMethodTeardown)
        function cleanupDir(testCase)
            if exist(testCase.output_dir, 'dir')
                rmdir(testCase.output_dir, 's');
            end
        end
    end

    methods (Test)

        function testCreatesOneFilePerFileid(testCase)
            data = table(["A001"; "A001"; "B002"], [1; 2; 3], ...
                'VariableNames', {'FILEID', 'VALUE'});

            writer = narwc.ingestion.SurveyFileWriter(testCase.output_dir);
            writer.writeChunk(data);

            testCase.verifyTrue(isfile(fullfile(testCase.output_dir, 'A001.csv')), ...
                'A001.csv not created');
            testCase.verifyTrue(isfile(fullfile(testCase.output_dir, 'B002.csv')), ...
                'B002.csv not created');
        end

        function testAppendsWithoutDuplicatingHeader(testCase)
            chunk1 = table("A001", 1, 'VariableNames', {'FILEID', 'VALUE'});
            chunk2 = table("A001", 2, 'VariableNames', {'FILEID', 'VALUE'});

            writer = narwc.ingestion.SurveyFileWriter(testCase.output_dir);
            writer.writeChunk(chunk1);
            writer.writeChunk(chunk2);

            out = readtable(fullfile(testCase.output_dir, 'A001.csv'));
            testCase.verifyEqual(height(out), 2, ...
                'Second writeChunk call should append, not duplicate header');
            testCase.verifyEqual(out.VALUE, [1; 2]);
        end

        function testDroppedFileidRowsCountedInTotalNotPerSurvey(testCase)
            data = table(["A001"; ""; "A001"], [1; 2; 3], ...
                'VariableNames', {'FILEID', 'VALUE'});

            writer = narwc.ingestion.SurveyFileWriter(testCase.output_dir);
            writer.writeChunk(data);
            summary = writer.finalize('test source');

            out = readtable(fullfile(testCase.output_dir, 'A001.csv'));
            testCase.verifyEqual(height(out), 2, ...
                'Empty-FILEID row must not appear in any per-survey file');
            testCase.verifyEqual(summary.total_rows, 3, ...
                'Total row count must include dropped-FILEID rows');
        end

        function testSanitizesFilename(testCase)
            data = table("A/001", 1, 'VariableNames', {'FILEID', 'VALUE'});

            writer = narwc.ingestion.SurveyFileWriter(testCase.output_dir);
            writer.writeChunk(data);

            testCase.verifyTrue(isfile(fullfile(testCase.output_dir, 'A_001.csv')), ...
                'FILEID with a reserved character must be sanitized in the filename');
        end

        function testAccumulatesRowCountsAcrossChunks(testCase)
            chunk1 = table(["A001"; "A001"], [1; 2], 'VariableNames', {'FILEID', 'VALUE'});
            chunk2 = table("A001", 3, 'VariableNames', {'FILEID', 'VALUE'});

            writer = narwc.ingestion.SurveyFileWriter(testCase.output_dir);
            writer.writeChunk(chunk1);
            writer.writeChunk(chunk2);
            summary = writer.finalize('test source');

            testCase.verifyEqual(summary.total_surveys, 1);
            testCase.verifyEqual(summary.total_rows, 3);
        end

        function testFinalizeWritesSummaryInsideOutputDir(testCase)
            data = table("A001", 1, 'VariableNames', {'FILEID', 'VALUE'});

            writer = narwc.ingestion.SurveyFileWriter(testCase.output_dir);
            writer.writeChunk(data);
            summary = writer.finalize('test source');

            listing = dir(fullfile(testCase.output_dir, '_split_summary_*.log'));
            testCase.verifyEqual(numel(listing), 1, ...
                'Expected exactly one _split_summary_*.log inside output_dir');
            testCase.verifyEqual(fullfile(listing(1).folder, listing(1).name), summary.file);

            contents = fileread(summary.file);
            testCase.verifyTrue(contains(contents, 'Total surveys: 1'));
            testCase.verifyTrue(contains(contents, 'Total rows: 1'));
        end

    end
end
