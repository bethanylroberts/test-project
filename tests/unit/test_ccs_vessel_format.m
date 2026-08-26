classdef test_ccs_vessel_format < matlab.unittest.TestCase
    % TEST_CCS_VESSEL_FORMAT Tests for the CCSVesselFormat parser.
    %
    % Two fixtures exercise the two real behavior-column-naming variants
    % (see CCSVesselFormat.m's docstring): ccs_vessel_2023_sample.csv
    % already has canonical BEHAV1/BEHAV2 names (rename is a no-op),
    % ccs_vessel_2024_sample.csv has B1/B2 needing the rename. Both share
    % the single-DATE-column layout (no split MONTH/DAY/YEAR) that this
    % parser must split -- the 2024 fixture also exercises the uppercase
    % "MAY" month-abbreviation case confirmed in real 2024 files.
    %
    % No database connection required.

    properties
        fixture_dir
        vessel_2023_file
        vessel_2024_file
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
            testCase.vessel_2023_file = fullfile(testCase.fixture_dir, 'ccs_vessel_2023_sample.csv');
            testCase.vessel_2024_file = fullfile(testCase.fixture_dir, 'ccs_vessel_2024_sample.csv');
            testCase.aerial_file = fullfile(testCase.fixture_dir, 'ccs_aerial_sample.csv');
        end
    end

    methods (Test)

        function testDetectFormatScoresOwnFixtureHighest(testCase)
            vessel_confidence = narwc.io.parsers.CCSVesselFormat.detectFormat(testCase.vessel_2023_file);
            aerial_confidence = narwc.io.parsers.CCSVesselFormat.detectFormat(testCase.aerial_file);

            testCase.verifyGreaterThan(vessel_confidence, aerial_confidence);
            testCase.verifyGreaterThan(vessel_confidence, 0.5);
        end

        function testDetectFormatRejectsFileWithSplitDate(testCase)
            % A file carrying MONTH (CCSAerialFormat/CCSOpportunisticFormat)
            % must score 0, not just lower -- the presence of MONTH is a
            % hard signal this isn't CCSVesselFormat's single-DATE layout.
            confidence = narwc.io.parsers.CCSVesselFormat.detectFormat(testCase.aerial_file);
            testCase.verifyEqual(confidence, 0);
        end

        function testParseSplitsDateColumn2023(testCase)
            [data, ~] = narwc.io.parsers.CCSVesselFormat.parse(testCase.vessel_2023_file);

            testCase.verifyEqual(data.MONTH(1), 4);
            testCase.verifyEqual(data.DAY(1), 21);
            testCase.verifyEqual(data.YEAR(1), 2023);
        end

        function testParseSplitsDateColumn2024UppercaseMonth(testCase)
            [data, ~] = narwc.io.parsers.CCSVesselFormat.parse(testCase.vessel_2024_file);

            testCase.verifyEqual(data.MONTH(1), 5);
            testCase.verifyEqual(data.DAY(1), 2);
            testCase.verifyEqual(data.YEAR(1), 2024);
        end

        function testParsePassesThroughAlreadyCanonicalBehaviorColumns(testCase)
            [data, ~] = narwc.io.parsers.CCSVesselFormat.parse(testCase.vessel_2023_file);

            testCase.verifyEqual(data.BEHAV1(1), 6);
            testCase.verifyEqual(data.BEHAV2(1), 7);
        end

        function testParseRenamesBehaviorColumns2024(testCase)
            [data, ~] = narwc.io.parsers.CCSVesselFormat.parse(testCase.vessel_2024_file);

            testCase.verifyEqual(data.BEHAV1(1), 11);
            testCase.verifyEqual(data.BEHAV2(1), 12);
        end

        function testParseDropsDepthNoCanonicalHome(testCase)
            [data, ~] = narwc.io.parsers.CCSVesselFormat.parse(testCase.vessel_2023_file);
            testCase.verifyFalse(ismember('DEPTH', data.Properties.VariableNames));
        end

        function testParseKeepsSurftemp(testCase)
            [data, ~] = narwc.io.parsers.CCSVesselFormat.parse(testCase.vessel_2023_file);
            testCase.verifyEqual(data.SURFTEMP(1), 12.1, 'AbsTol', 1e-9);
        end

        function testParseReturnsDatabaseOrder(testCase)
            [data, ~] = narwc.io.parsers.CCSVesselFormat.parse(testCase.vessel_2023_file);
            db_order = narwc.db.FieldDefinitions.getDatabaseOrder();
            testCase.verifyEqual(data.Properties.VariableNames, db_order);
        end

        function testParseAssignsFileidFromFilename(testCase)
            [data, ~] = narwc.io.parsers.CCSVesselFormat.parse(testCase.vessel_2023_file);
            testCase.verifyEqual(sum(data.FILEID == "ccs_vessel_2023_sample"), 2);
        end

    end
end
