classdef test_ccs_aerial_format < matlab.unittest.TestCase
    % TEST_CCS_AERIAL_FORMAT Tests for the CCSAerialFormat parser.
    %
    % Fixture is a reduced-but-real-confirmed subset of
    % data/surveys/raw/CCS/2023 Aerial/*.csv's header (see
    % CCSAerialFormat.m's docstring for the full real header) -- only the
    % columns needed to exercise the B1..B15 rename, canonical-name
    % passthrough, and FILEID-from-filename behavior.
    %
    % No database connection required.

    properties
        fixture_dir
        ccs_aerial_file
        ccs_vessel_file
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
            testCase.ccs_aerial_file = fullfile(testCase.fixture_dir, 'ccs_aerial_sample.csv');
            testCase.ccs_vessel_file = fullfile(testCase.fixture_dir, 'ccs_vessel_2023_sample.csv');
            testCase.standard_file = fullfile(testCase.fixture_dir, 'aT11110.csv');
        end
    end

    methods (Test)

        function testDetectFormatScoresOwnFixtureHighest(testCase)
            aerial_confidence = narwc.io.parsers.CCSAerialFormat.detectFormat(testCase.ccs_aerial_file);
            vessel_confidence = narwc.io.parsers.CCSAerialFormat.detectFormat(testCase.ccs_vessel_file);
            standard_confidence = narwc.io.parsers.CCSAerialFormat.detectFormat(testCase.standard_file);

            testCase.verifyGreaterThan(aerial_confidence, vessel_confidence);
            testCase.verifyGreaterThan(aerial_confidence, standard_confidence);
            testCase.verifyGreaterThan(aerial_confidence, 0.5);
        end

        function testParseRenamesBehaviorColumns(testCase)
            [data, ~] = narwc.io.parsers.CCSAerialFormat.parse(testCase.ccs_aerial_file);

            testCase.verifyTrue(ismember('BEHAV1', data.Properties.VariableNames));
            testCase.verifyTrue(ismember('BEHAV2', data.Properties.VariableNames));
            testCase.verifyTrue(ismember('BEHAV3', data.Properties.VariableNames));
            testCase.verifyEqual(data.BEHAV1(1), 6);
            testCase.verifyEqual(data.BEHAV2(1), 7);
        end

        function testParsePassesThroughCanonicalColumns(testCase)
            [data, ~] = narwc.io.parsers.CCSAerialFormat.parse(testCase.ccs_aerial_file);

            testCase.verifyEqual(data.LAT_DD(1), 42.05, 'AbsTol', 1e-9);
            testCase.verifyEqual(data.LONG_DD(1), -70.63, 'AbsTol', 1e-9);
            testCase.verifyEqual(char(data.SPECCODE(1)), 'RIWH');
        end

        function testParseReturnsDatabaseOrder(testCase)
            [data, ~] = narwc.io.parsers.CCSAerialFormat.parse(testCase.ccs_aerial_file);

            db_order = narwc.db.FieldDefinitions.getDatabaseOrder();
            testCase.verifyEqual(data.Properties.VariableNames, db_order, ...
                'CCSAerialFormat.parse() output must be in canonical DB field order');
        end

        function testParseAssignsFileidFromFilename(testCase)
            [data, ~] = narwc.io.parsers.CCSAerialFormat.parse(testCase.ccs_aerial_file);

            testCase.verifyEqual(sum(data.FILEID == "ccs_aerial_sample"), 2, ...
                'FILEID must be derived from the filename stem for every row');
        end

        function testParseRowCount(testCase)
            [data, metadata] = narwc.io.parsers.CCSAerialFormat.parse(testCase.ccs_aerial_file);

            testCase.verifyEqual(height(data), 2);
            testCase.verifyEqual(metadata.row_count, 2);
        end

    end
end
