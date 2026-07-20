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

            extractor = narwc.ingestion.SurveyExtractor(combined);
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

            extractor = narwc.ingestion.SurveyExtractor(combined);
            extractor.extractAll(testCase.output_dir, 'Overwrite', true);

            out1 = readtable(fullfile(testCase.output_dir, 'aT11110.csv'));
            out2 = readtable(fullfile(testCase.output_dir, 'fT00157.csv'));

            % Expected counts are data rows only (readtable consumes the
            % header written by extractAll, so height() == data rows).
            % The extractor skips line 1 of the combined file as its header,
            % so buildCombined must write the combined file with a header row
            % or the first data row is lost.
            testCase.verifyEqual(height(out1), 328, ...
                'Row count mismatch for aT11110');
            testCase.verifyEqual(height(out2), 61, ...
                'Row count mismatch for fT00157');
        end

        function testExtractorTotalRowsPreserved(testCase)
            % Total rows across all output files must equal input rows.

            combined = testCase.buildCombined({'aT11110.csv', 'fT00157.csv'});

            extractor = narwc.ingestion.SurveyExtractor(combined);
            extractor.extractAll(testCase.output_dir, 'Overwrite', true);

            out1 = readtable(fullfile(testCase.output_dir, 'aT11110.csv'));
            out2 = readtable(fullfile(testCase.output_dir, 'fT00157.csv'));

            testCase.verifyEqual(height(out1) + height(out2), 328 + 61, ...
                'Total row count must be preserved across split');
        end

        function testExtractorWritesSummary(testCase)
            % extractAll must write a _split_summary_<timestamp>.log file
            % inside output_dir (via SurveyFileWriter.finalize).

            combined = testCase.buildCombined({'aT11110.csv', 'fT00157.csv'});

            extractor = narwc.ingestion.SurveyExtractor(combined);
            extractor.extractAll(testCase.output_dir, 'Overwrite', true);

            listing = dir(fullfile(testCase.output_dir, '_split_summary_*.log'));
            testCase.verifyEqual(numel(listing), 1, ...
                '_split_summary_*.log not written inside output_dir');
        end

    end

    methods (Access = private)

        function combined_file = buildCombined(testCase, filenames)
            % Read fixture CSVs (each with a header row) and write a combined
            % CSV that also includes a header row.  SurveyExtractor.extractAll
            % always starts reading from line 2 (hardcoded "skip header"), so
            % the combined file must have a real header at line 1 or the first
            % data row will be silently dropped.  The fixture columns are
            % already in CSV_FIELD_ORDER so no reordering is needed.
            %
            % readtable infers column types per-file from observed values.
            % All-empty columns become double; on R2021a+ text-valued columns
            % become string instead of cell.  Any column whose class diverges
            % across input tables will cause vertcat to fail.  We detect and
            % coerce all such columns to cell-of-char before combining.  The
            % underlying type-inference issue is documented in PROJECT_STATUS.md.

            tables = cell(numel(filenames), 1);
            for k = 1:numel(filenames)
                tables{k} = readtable(fullfile(testCase.fixture_dir, filenames{k}));
            end

            % Coerce any variable whose class diverges across tables to cell-of-char.
            var_names = tables{1}.Properties.VariableNames;
            for v = 1:numel(var_names)
                col = var_names{v};
                classes = cellfun(@(t) class(t.(col)), tables, 'UniformOutput', false);
                if numel(unique(classes)) > 1
                    for k = 1:numel(tables)
                        tables{k}.(col) = ...
                            test_characterization_extractor.toCell(tables{k}.(col));
                    end
                end
            end

            combined = tables{1};
            for k = 2:numel(tables)
                combined = [combined; tables{k}]; %#ok<AGROW>
            end

            combined_file = [tempname '.csv'];
            writetable(combined, combined_file, 'WriteVariableNames', true);
        end

    end

    methods (Static, Access = private)

        function c = toCell(col)
            % Coerce a table column to cell-of-char for vertcat compatibility.
            % string arrays (R2021a+ readtable default) and numeric arrays
            % (all-empty columns inferred as double) are both converted to a
            % cell array of char; existing cell columns pass through unchanged.
            if isstring(col)
                col(ismissing(col)) = "";
                c = cellstr(col);
            elseif isnumeric(col)
                c = repmat({''}, size(col));
            else
                c = col;
            end
        end

    end
end
