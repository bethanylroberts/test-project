classdef test_neaq_aerial_format < matlab.unittest.TestCase
    % TEST_NEAQ_AERIAL_FORMAT Tests for the NEAQAerialFormat parser.
    %
    % Fixture is a reduced-but-real-confirmed subset of
    % data/surveys/raw/NEAQ Aerial/Wind Energy Area 2024/NEAQ-A-*_URI.csv's
    % lowercase header (see NEAQAerialFormat.m's docstring for the full
    % real header) -- only the columns needed to exercise the lowercase
    % rename map and the distinctive detectFormat columns.
    %
    % No database connection required.

    properties
        fixture_dir
        neaq_aerial_file
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
            testCase.neaq_aerial_file = fullfile(testCase.fixture_dir, 'neaq_aerial_sample.csv');
            testCase.standard_file = fullfile(testCase.fixture_dir, 'aT11110.csv');
        end
    end

    methods (Test)

        function testDetectFormatScoresOwnFixtureHighest(testCase)
            neaq_confidence = narwc.io.parsers.NEAQAerialFormat.detectFormat(testCase.neaq_aerial_file);
            standard_confidence = narwc.io.parsers.NEAQAerialFormat.detectFormat(testCase.standard_file);

            testCase.verifyGreaterThan(neaq_confidence, standard_confidence);
            testCase.verifyGreaterThan(neaq_confidence, 0.5);
        end

        function testParseRenamesLowercaseColumns(testCase)
            [data, ~] = narwc.io.parsers.NEAQAerialFormat.parse(testCase.neaq_aerial_file);

            testCase.verifyTrue(ismember('LAT_DD', data.Properties.VariableNames));
            testCase.verifyTrue(ismember('LONG_DD', data.Properties.VariableNames));
            testCase.verifyEqual(data.LAT_DD(1), 41.479, 'AbsTol', 1e-9);
            testCase.verifyEqual(data.LONG_DD(1), -71.121, 'AbsTol', 1e-9);
            testCase.verifyEqual(data.MONTH(1), 3);
            testCase.verifyEqual(data.EVENTNO(1), 163);
        end

        function testParseRenamesBehaviorAndBlockStratum(testCase)
            [data, ~] = narwc.io.parsers.NEAQAerialFormat.parse(testCase.neaq_aerial_file);

            testCase.verifyEqual(data.BEHAV1(1), 6);
            testCase.verifyEqual(char(data.BLOCK(1)), 'M2');
            testCase.verifyEqual(char(data.STRATUM(1)), 'ST1');
        end

        function testParseDropsRectypeNoCanonicalHome(testCase)
            [data, ~] = narwc.io.parsers.NEAQAerialFormat.parse(testCase.neaq_aerial_file);
            testCase.verifyFalse(ismember('RECTYPE', data.Properties.VariableNames));
            testCase.verifyFalse(ismember('rectype', data.Properties.VariableNames));
        end

        function testParseReturnsDatabaseOrder(testCase)
            [data, ~] = narwc.io.parsers.NEAQAerialFormat.parse(testCase.neaq_aerial_file);
            db_order = narwc.db.FieldDefinitions.getDatabaseOrder();
            testCase.verifyEqual(data.Properties.VariableNames, db_order);
        end

        function testParseAssignsFileidFromFilename(testCase)
            [data, ~] = narwc.io.parsers.NEAQAerialFormat.parse(testCase.neaq_aerial_file);
            testCase.verifyEqual(sum(data.FILEID == "neaq_aerial_sample"), 2);
        end

    end
end
