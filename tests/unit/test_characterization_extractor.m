classdef test_characterization_extractor < matlab.unittest.TestCase
    % TEST_CHARACTERIZATION_EXTRACTOR Characterization tests for SurveyExtractor.
    %
    % Locks in the grouping and row-count behaviour of extractAll so that
    % refactoring cannot silently change it.  Does NOT assert that current
    % behaviour is correct -- only that it is stable.
    %
    % No database connection required.

    properties
        fixture_dir   % tests/fixtures/sample_data/
        output_dir    % per-test temp directory
    end

    methods (TestClassSetup)
        function setupPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));          % tests/unit/
            test_root = fileparts(here);                      % tests/
            fixtures_path = fullfile(test_root, 'fixtures');
            if ~contains(path, fixtures_path)
                addpath(fixtures_path);
            end
        end
    end

    methods (TestMethodSetup)
        function setupDirs(testCase)
            here = fileparts(mfilename('fullpath'));
            test_root = fileparts(here);
            testCase.fixture_dir = fullfile(test_root, 'fixtures', 'sample_data');
            testCase.output_dir = tempname;
            mkdir(testCase.output_dir);
        end
    end

    methods (TestMethodTeardown)
        function cleanupDirs(testCase)
            if exist(testCase.output_dir, 'dir')
                rmdir(testCase.output_dir, 's');
            end
        end
    end

    methods (Test)

        function testExtractorGroupsByFileid(testCase)
            % extractAll must produce one output file per unique FILEID.
            % Combining aT11110 and fT00157 must yield exactly two files.

            combined = testCase.buildCombined({'aT11110.csv', 'fT00157.csv'});

            extractor = migration.SurveyExtractor(combined);
            extractor.extractAll(testCase.output_dir, 'Overwrite', true);

            testCase.verifyTrue( ...
                exist(fullfile(testCase.output_dir, 'aT11110.csv'), 'file') == 2, ...
                'aT11110.csv not found in extractor output');
            testCase.verifyTrue( ...
                exist(fullfile(testCase.output_dir, 'fT00157.csv'), 'file') == 2, ...
                'fT00157.csv not found in extractor output');
        end

        function testExtractorRowCounts(testCase)
            % Row counts in extracted files must match the source fixtures.
            %
            % BASELINE (from wc -l on fixture files):
            %   aT11110.csv: 329 lines total (1 header + 328 data rows)
            %   fT00157.csv:  62 lines total (1 header +  61 data rows)

            combined = testCase.buildCombined({'aT11110.csv', 'fT00157.csv'});

            extractor = migration.SurveyExtractor(combined);
            extractor.extractAll(testCase.output_dir, 'Overwrite', true);

            out1 = readtable(fullfile(testCase.output_dir, 'aT11110.csv'));
            out2 = readtable(fullfile(testCase.output_dir, 'fT00157.csv'));

            testCase.verifyEqual(height(out1), 328, ...
                'Row count mismatch for aT11110');
            testCase.verifyEqual(height(out2), 61, ...
                'Row count mismatch for fT00157');
        end

        function testExtractorTotalRowsPreserved(testCase)
            % Total rows across all output files must equal input rows.

            combined = testCase.buildCombined({'aT11110.csv', 'fT00157.csv'});

            extractor = migration.SurveyExtractor(combined);
            extractor.extractAll(testCase.output_dir, 'Overwrite', true);

            out1 = readtable(fullfile(testCase.output_dir, 'aT11110.csv'));
            out2 = readtable(fullfile(testCase.output_dir, 'fT00157.csv'));

            testCase.verifyEqual(height(out1) + height(out2), 328 + 61, ...
                'Total row count must be preserved across split');
        end

        function testExtractorWritesSummary(testCase)
            % extractAll must write a _split_summary.txt file.

            combined = testCase.buildCombined({'aT11110.csv', 'fT00157.csv'});

            extractor = migration.SurveyExtractor(combined);
            extractor.extractAll(testCase.output_dir, 'Overwrite', true);

            testCase.verifyTrue( ...
                exist(fullfile(testCase.output_dir, '_split_summary.txt'), 'file') == 2, ...
                '_split_summary.txt not written');
        end

    end

    methods (Access = private)

        function combined_file = buildCombined(testCase, filenames)
            % Read fixture CSVs (which have headers) and write a headerless
            % combined CSV.  StandardFormat.createImportOptions uses
            % DataLines=[1,Inf] (no header), so the combined file must not
            % have a header row.  The fixture columns are already in
            % CSV_FIELD_ORDER so no reordering is needed.
            %
            % Note: BLOCK is coerced to cell-of-string before vertcat because
            % readtable infers the type per file — files with only empty BLOCK
            % values produce a numeric column; files with 'MC'/'MN' produce a
            % cell column.  Vertcat fails when the types differ.  The underlying
            % per-file type inference is a known latent bug (see PROJECT_STATUS.md).

            tables = cell(numel(filenames), 1);
            for k = 1:numel(filenames)
                tables{k} = readtable(fullfile(testCase.fixture_dir, filenames{k}));
            end

            % Normalize BLOCK: if any table has a cell/string BLOCK column,
            % coerce all-numeric BLOCK columns to empty cell-of-string.
            vars = tables{1}.Properties.VariableNames;
            if ismember('BLOCK', vars)
                has_string_block = any(cellfun( ...
                    @(t) iscell(t.BLOCK) || isstring(t.BLOCK), tables));
                if has_string_block
                    for k = 1:numel(tables)
                        if isnumeric(tables{k}.BLOCK)
                            tables{k}.BLOCK = repmat({''}, height(tables{k}), 1);
                        end
                    end
                end
            end

            combined = tables{1};
            for k = 2:numel(tables)
                combined = [combined; tables{k}]; %#ok<AGROW>
            end

            combined_file = [tempname '.csv'];
            writetable(combined, combined_file, 'WriteVariableNames', false);
        end

    end
end
