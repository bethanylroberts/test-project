classdef test_ccs_opportunistic_format < matlab.unittest.TestCase
    % TEST_CCS_OPPORTUNISTIC_FORMAT Tests for the CCSOpportunisticFormat parser.
    %
    % Two fixtures exercise the two real layouts (see
    % CCSOpportunisticFormat.m's docstring): ccs_opportunistic_2023_sample.csv
    % (split MONTH/DAY/YEAR already present, one file = one trip, FILEID
    % from filename) and ccs_opportunistic_2024_sample.csv (single DATE
    % column needing the same split as CCSVesselFormat, plus a per-row
    % CRUISENO that becomes FILEID instead of the meaningless
    % one-annual-file filename stem).
    %
    % No database connection required.

    properties
        fixture_dir
        opp_2023_file
        opp_2024_file
        aerial_file
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
            testCase.opp_2023_file = fullfile(testCase.fixture_dir, 'ccs_opportunistic_2023_sample.csv');
            testCase.opp_2024_file = fullfile(testCase.fixture_dir, 'ccs_opportunistic_2024_sample.csv');
            testCase.aerial_file = fullfile(testCase.fixture_dir, 'ccs_aerial_sample.csv');
        end
    end

    methods (Test)

        function testDetectFormatScoresOwnFixtureHighest(testCase)
            opp_confidence = narwc.io.parsers.CCSOpportunisticFormat.detectFormat(testCase.opp_2023_file);
            aerial_confidence = narwc.io.parsers.CCSOpportunisticFormat.detectFormat(testCase.aerial_file);

            testCase.verifyGreaterThan(opp_confidence, aerial_confidence);
            testCase.verifyGreaterThan(opp_confidence, 0.5);
        end

        function testDetectFormatRejectsFileWithLegno(testCase)
            % CCSAerialFormat's fixture carries LEGNO, which opportunistic
            % sightings never have (data/README.md) -- must score 0.
            confidence = narwc.io.parsers.CCSOpportunisticFormat.detectFormat(testCase.aerial_file);
            testCase.verifyEqual(confidence, 0);
        end

        function testDetectFormatScoresOwn2024FixtureHighest(testCase)
            confidence = narwc.io.parsers.CCSOpportunisticFormat.detectFormat(testCase.opp_2024_file);
            testCase.verifyGreaterThan(confidence, 0.5);
        end

        function testParse2023UsesSplitDateAsIs(testCase)
            [data, ~] = narwc.io.parsers.CCSOpportunisticFormat.parse(testCase.opp_2023_file);

            testCase.verifyEqual(data.MONTH(1), 3);
            testCase.verifyEqual(data.DAY(1), 22);
            testCase.verifyEqual(data.YEAR(1), 2023);
        end

        function testParse2023FileidFromFilename(testCase)
            [data, ~] = narwc.io.parsers.CCSOpportunisticFormat.parse(testCase.opp_2023_file);
            testCase.verifyEqual(sum(data.FILEID == "ccs_opportunistic_2023_sample"), 2);
        end

        function testParse2024SplitsDateColumn(testCase)
            [data, ~] = narwc.io.parsers.CCSOpportunisticFormat.parse(testCase.opp_2024_file);

            testCase.verifyEqual(data.MONTH(1), 2);
            testCase.verifyEqual(data.DAY(1), 8);
            testCase.verifyEqual(data.YEAR(1), 2024);
        end

        function testParse2024UsesCruisenoAsFileid(testCase)
            [data, ~] = narwc.io.parsers.CCSOpportunisticFormat.parse(testCase.opp_2024_file);
            testCase.verifyEqual(sum(data.FILEID == "SW1391"), 2, ...
                'FILEID must come from CRUISENO, not the aggregated annual filename');
        end

        function testParseRenamesBehaviorColumns(testCase)
            [data, ~] = narwc.io.parsers.CCSOpportunisticFormat.parse(testCase.opp_2023_file);
            testCase.verifyEqual(data.BEHAV1(1), 5);
            testCase.verifyEqual(data.BEHAV2(1), 6);
        end

        function testParseKeepsPlatform(testCase)
            [data, ~] = narwc.io.parsers.CCSOpportunisticFormat.parse(testCase.opp_2023_file);
            testCase.verifyEqual(data.PLATFORM(1), 573);
        end

        function testParseReturnsDatabaseOrder(testCase)
            [data, ~] = narwc.io.parsers.CCSOpportunisticFormat.parse(testCase.opp_2023_file);
            db_order = narwc.db.FieldDefinitions.getDatabaseOrder();
            testCase.verifyEqual(data.Properties.VariableNames, db_order);
        end

    end
end
