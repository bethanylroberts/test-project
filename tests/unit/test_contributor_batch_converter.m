classdef test_contributor_batch_converter < matlab.unittest.TestCase
    % TEST_CONTRIBUTOR_BATCH_CONVERTER Tests for
    % narwc.ingestion.convert_contributor_batch.
    %
    % Uses a hand-rolled fake parser (tests/fixtures/FakeParser.m) so these
    % tests don't depend on any real per-contributor format -- they verify
    % the function correctly drives SurveyFileWriter regardless of which
    % parser produced the table.

    properties
        output_dir
        input_file1
        input_file2
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
        function setupDirsAndFiles(testCase)
            testCase.output_dir = tempname;
            mkdir(testCase.output_dir);
            % Input files are placeholders -- FakeParser ignores their
            % contents and returns preset data instead.
            testCase.input_file1 = [tempname '.csv'];
            fclose(fopen(testCase.input_file1, 'w'));
            testCase.input_file2 = [tempname '.csv'];
            fclose(fopen(testCase.input_file2, 'w'));
        end
    end

    methods (TestMethodTeardown)
        function cleanup(testCase)
            if exist(testCase.output_dir, 'dir')
                rmdir(testCase.output_dir, 's');
            end
            if exist(testCase.input_file1, 'file')
                delete(testCase.input_file1);
            end
            if exist(testCase.input_file2, 'file')
                delete(testCase.input_file2);
            end
        end
    end

    methods (Test)

        function testConvertsSingleFile(testCase)
            data = table(["A001"; "A001"; "B002"], [1; 2; 3], ...
                'VariableNames', {'FILEID', 'VALUE'});
            parser = FakeParser(data);

            narwc.ingestion.convert_contributor_batch(parser, ...
                {testCase.input_file1}, testCase.output_dir);

            testCase.verifyTrue(isfile(fullfile(testCase.output_dir, 'A001.csv')));
            testCase.verifyTrue(isfile(fullfile(testCase.output_dir, 'B002.csv')));
            testCase.verifyEqual(parser.parse_call_count, 1);
        end

        function testConvertsMultipleFilesIntoSharedOutput(testCase)
            data1 = table("A001", 1, 'VariableNames', {'FILEID', 'VALUE'});
            data2 = table("A001", 2, 'VariableNames', {'FILEID', 'VALUE'});
            parser = FakeParser({data1, data2});

            narwc.ingestion.convert_contributor_batch(parser, ...
                {testCase.input_file1, testCase.input_file2}, testCase.output_dir);

            out = readtable(fullfile(testCase.output_dir, 'A001.csv'));
            testCase.verifyEqual(height(out), 2, ...
                'Both input files should accumulate into the same survey file');
            testCase.verifyEqual(out.VALUE, [1; 2]);
            testCase.verifyEqual(parser.parse_call_count, 2);
            testCase.verifyEqual(parser.parsed_paths, ...
                {testCase.input_file1, testCase.input_file2});
        end

        function testWritesSummary(testCase)
            data = table("A001", 1, 'VariableNames', {'FILEID', 'VALUE'});
            parser = FakeParser(data);

            summary = narwc.ingestion.convert_contributor_batch(parser, ...
                {testCase.input_file1}, testCase.output_dir);

            listing = dir(fullfile(testCase.output_dir, '_split_summary_*.log'));
            testCase.verifyEqual(numel(listing), 1);
            testCase.verifyEqual(summary.total_surveys, 1);
            testCase.verifyEqual(summary.total_rows, 1);
        end

        function testCreatesOutputDirIfMissing(testCase)
            rmdir(testCase.output_dir, 's');   % start with a nonexistent dir
            data = table("A001", 1, 'VariableNames', {'FILEID', 'VALUE'});
            parser = FakeParser(data);

            narwc.ingestion.convert_contributor_batch(parser, ...
                {testCase.input_file1}, testCase.output_dir);

            testCase.verifyTrue(isfolder(testCase.output_dir));
            testCase.verifyTrue(isfile(fullfile(testCase.output_dir, 'A001.csv')));
        end

    end
end
