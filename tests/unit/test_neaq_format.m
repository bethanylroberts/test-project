classdef test_neaq_format < matlab.unittest.TestCase
    % TEST_NEAQ_FORMAT Tests for the NEAQFormat parser.
    %
    % NEAQFormat's layout is built from the one confirmed lead in
    % config/format_definitions.json (header on row 2, Latitude/Longitude/
    % Species renamed to LAT_DD/LONG_DD/SPECCODE) -- see
    % tests/fixtures/sample_data/README.md. These tests lock in that
    % confirmed behavior; they do not assert the fixture matches a real
    % NEAQ export layout, since none is available to check against.
    %
    % No database connection required.

    properties
        fixture_dir
        neaq_file
        standard_file
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
        function setupFiles(testCase)
            here = fileparts(mfilename('fullpath'));
            test_root = fileparts(here);
            testCase.fixture_dir = fullfile(test_root, 'fixtures', 'sample_data');
            testCase.neaq_file = fullfile(testCase.fixture_dir, 'neaq_sample.csv');
            testCase.standard_file = fullfile(testCase.fixture_dir, 'aT11110.csv');
        end
    end

    methods (Test)

        function testDetectFormatScoresNeaqHigherThanStandard(testCase)
            neaq_confidence = narwc.io.parsers.NEAQFormat.detectFormat(testCase.neaq_file);
            standard_confidence = narwc.io.parsers.NEAQFormat.detectFormat(testCase.standard_file);

            testCase.verifyGreaterThan(neaq_confidence, standard_confidence, ...
                'NEAQFormat.detectFormat must score the NEAQ fixture higher than a StandardFormat fixture');
            testCase.verifyGreaterThan(neaq_confidence, 0.5, ...
                'NEAQFormat.detectFormat must be reasonably confident on its own fixture');
        end

        function testParseRenamesConfirmedFields(testCase)
            [data, ~] = narwc.io.parsers.NEAQFormat.parse(testCase.neaq_file);

            testCase.verifyTrue(ismember('LAT_DD', data.Properties.VariableNames));
            testCase.verifyTrue(ismember('LONG_DD', data.Properties.VariableNames));
            testCase.verifyTrue(ismember('SPECCODE', data.Properties.VariableNames));
            testCase.verifyFalse(ismember('Latitude', data.Properties.VariableNames), ...
                'Native NEAQ column name must not survive the rename');

            testCase.verifyEqual(data.LAT_DD(1), 42.35, 'AbsTol', 1e-9);
            testCase.verifyEqual(char(data.SPECCODE(1)), 'RIWH');
        end

        function testParseReturnsDatabaseOrder(testCase)
            [data, ~] = narwc.io.parsers.NEAQFormat.parse(testCase.neaq_file);

            db_order = narwc.db.FieldDefinitions.getDatabaseOrder();
            testCase.verifyEqual(data.Properties.VariableNames, db_order, ...
                'NEAQFormat.parse() output must be in canonical DB field order');
        end

        function testParsePreservesFileid(testCase)
            [data, ~] = narwc.io.parsers.NEAQFormat.parse(testCase.neaq_file);

            testCase.verifyEqual(sum(data.FILEID == "nT00001"), 2);
            testCase.verifyEqual(sum(data.FILEID == "nT00002"), 1);
        end

        function testParseRowCount(testCase)
            [data, metadata] = narwc.io.parsers.NEAQFormat.parse(testCase.neaq_file);

            testCase.verifyEqual(height(data), 3);
            testCase.verifyEqual(metadata.row_count, 3);
        end

    end
end
