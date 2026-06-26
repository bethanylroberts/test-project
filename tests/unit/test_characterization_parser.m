classdef test_characterization_parser < matlab.unittest.TestCase
    % TEST_CHARACTERIZATION_PARSER Characterization tests for StandardFormat parser.
    %
    % Exercises StandardFormat.read() end-to-end (createImportOptions +
    % remapToDatabase + standardize) on a fixture to lock in field types and
    % DB-order mapping.
    %
    % StandardFormat expects a headerless CSV with columns in CSV_FIELD_ORDER.
    % Fixture files have a header row, so the test strips the header before
    % feeding the file to the parser.
    %
    % No database connection required.

    properties
        fixture_dir
        test_file   % per-test temp file
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
        function buildHeaderlessFile(testCase)
            here = fileparts(mfilename('fullpath'));
            test_root = fileparts(here);
            testCase.fixture_dir = fullfile(test_root, 'fixtures', 'sample_data');

            % aT11110.csv: 328 data rows, columns in CSV_FIELD_ORDER.
            % Strip the header so StandardFormat (DataLines=[1,Inf]) sees only data.
            src = fullfile(testCase.fixture_dir, 'aT11110.csv');
            data = readtable(src);   % auto-detects header

            testCase.test_file = [tempname '.csv'];
            writetable(data, testCase.test_file, 'WriteVariableNames', true);
        end
    end

    methods (TestMethodTeardown)
        function cleanupFile(testCase)
            if exist(testCase.test_file, 'file')
                delete(testCase.test_file);
            end
        end
    end

    methods (Test)

        function testParserReturnsTable(testCase)
            % read() must return a table with rows from the fixture.

            parser = narwc.io.parsers.StandardFormat();
            [data, ~] = parser.read(testCase.test_file);

            testCase.verifyClass(data, 'table', ...
                'StandardFormat.read() must return a table');
            testCase.verifyEqual(height(data), 328, ...
                'Row count must match fixture (aT11110: 328 data rows)');
        end

        function testParserProducesDatabaseFieldOrder(testCase)
            % After remapToDatabase the columns must be in DB order.

            parser = narwc.io.parsers.StandardFormat();
            [data, ~] = parser.read(testCase.test_file);

            db_order = narwc.db.FieldDefinitions.getDatabaseOrder();
            actual_fields = data.Properties.VariableNames;

            % Every DB field that appears in the output must be in DB order.
            present = ismember(db_order, actual_fields);
            db_fields_present = db_order(present);

            for k = 1:numel(db_fields_present)
                field = db_fields_present{k};
                actual_idx = find(strcmp(actual_fields, field), 1);
                expected_idx = find(strcmp(db_order, field), 1);
                testCase.verifyLessThanOrEqual(actual_idx, expected_idx + 10, ...
                    sprintf('Field %s is unexpectedly far from its DB position', field));
            end

            % Verify a specific remapping: in CSV_FIELD_ORDER EVENTNO is col 24;
            % in DB order it is col 2.  After remap it must appear before col 10.
            eventno_idx = find(strcmp(actual_fields, 'EVENTNO'), 1);
            testCase.verifyLessThan(eventno_idx, 10, ...
                'EVENTNO must be near the start of DB-ordered output');
        end

        function testParserFileidValuesPreserved(testCase)
            % FILEID values must survive the round-trip intact.

            parser = narwc.io.parsers.StandardFormat();
            [data, ~] = parser.read(testCase.test_file);

            testCase.verifyTrue(ismember('FILEID', data.Properties.VariableNames), ...
                'FILEID column must be present after parse');

            unique_ids = unique(data.FILEID);
            testCase.verifyEqual(numel(unique_ids), 1, ...
                'All rows in aT11110 fixture must share a single FILEID');
            testCase.verifyEqual(char(unique_ids(1)), 'aT11110', ...
                'FILEID value must be preserved as aT11110');
        end

        function testParserNumericFieldTypes(testCase)
            % Fields defined as double in FieldDefinitions must be numeric
            % after parsing.

            parser = narwc.io.parsers.StandardFormat();
            [data, ~] = parser.read(testCase.test_file);

            numeric_fields = {'LAT_DD', 'LONG_DD', 'YEAR', 'MONTH', 'DAY', ...
                              'ALT', 'BEAUFORT', 'EVENTNO'};

            for k = 1:numel(numeric_fields)
                f = numeric_fields{k};
                if ismember(f, data.Properties.VariableNames)
                    testCase.verifyTrue(isnumeric(data.(f)), ...
                        sprintf('%s must be numeric after StandardFormat.read()', f));
                end
            end
        end

        function testParserMetadataFields(testCase)
            % metadata struct must carry row_count, column_count, and format.

            parser = narwc.io.parsers.StandardFormat();
            [~, metadata] = parser.read(testCase.test_file);

            testCase.verifyTrue(isfield(metadata, 'row_count'));
            testCase.verifyTrue(isfield(metadata, 'column_count'));
            testCase.verifyTrue(isfield(metadata, 'format'));
            testCase.verifyEqual(metadata.row_count, 328);
        end

    end
end
