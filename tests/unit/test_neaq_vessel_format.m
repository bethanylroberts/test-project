classdef test_neaq_vessel_format < matlab.unittest.TestCase
    % TEST_NEAQ_VESSEL_FORMAT Tests for the NEAQVesselFormat parser.
    %
    % Fixture matches the real header confirmed against
    % data/surveys/raw/NEAQ & CWI (vessels)/2023/Fundy/2023-08-28-CWI-V.csv
    % (see NEAQVesselFormat.m's docstring), including the real UTF-8 BOM.
    %
    % No database connection required.

    properties
        fixture_dir
        neaq_vessel_file
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
            testCase.neaq_vessel_file = fullfile(testCase.fixture_dir, 'neaq_vessel_sample.csv');
            testCase.standard_file = fullfile(testCase.fixture_dir, 'aT11110.csv');
        end
    end

    methods (Test)

        function testDetectFormatScoresOwnFixtureHighest(testCase)
            neaq_confidence = narwc.io.parsers.NEAQVesselFormat.detectFormat(testCase.neaq_vessel_file);
            standard_confidence = narwc.io.parsers.NEAQVesselFormat.detectFormat(testCase.standard_file);

            testCase.verifyGreaterThan(neaq_confidence, standard_confidence);
            testCase.verifyGreaterThan(neaq_confidence, 0.5);
        end

        function testFirstHeaderFieldNotBomMangled(testCase)
            % The real file has a UTF-8 BOM before the header row -- this
            % must not survive into the first variable/field name.
            fid = fopen(testCase.neaq_vessel_file, 'r', 'n', 'UTF-8');
            header_line = fgetl(fid);
            fclose(fid);
            % fgetl with 'UTF-8' encoding decodes the BOM's 3 raw bytes into
            % a single U+FEFF character, not the literal byte sequence.
            if ~isempty(header_line) && header_line(1) == char(65279)
                header_line = header_line(2:end);
            end
            header_fields = strsplit(header_line, ',');

            testCase.verifyEqual(header_fields{1}, 'EVENTNO');
        end

        function testParseRenamesLatLong(testCase)
            [data, ~] = narwc.io.parsers.NEAQVesselFormat.parse(testCase.neaq_vessel_file);

            testCase.verifyTrue(ismember('LAT_DD', data.Properties.VariableNames));
            testCase.verifyTrue(ismember('LONG_DD', data.Properties.VariableNames));
            testCase.verifyEqual(data.LAT_DD(1), 44.65, 'AbsTol', 1e-9);
            testCase.verifyEqual(data.LONG_DD(1), -66.12, 'AbsTol', 1e-9);
        end

        function testParsePassesThroughEventnoAndBehavior(testCase)
            [data, ~] = narwc.io.parsers.NEAQVesselFormat.parse(testCase.neaq_vessel_file);

            testCase.verifyEqual(data.EVENTNO(1), 1);
            testCase.verifyEqual(data.BEHAV1(1), 6);
        end

        function testParseReturnsDatabaseOrder(testCase)
            [data, ~] = narwc.io.parsers.NEAQVesselFormat.parse(testCase.neaq_vessel_file);
            db_order = narwc.db.FieldDefinitions.getDatabaseOrder();
            testCase.verifyEqual(data.Properties.VariableNames, db_order);
        end

        function testParseAssignsFileidFromFilename(testCase)
            [data, ~] = narwc.io.parsers.NEAQVesselFormat.parse(testCase.neaq_vessel_file);
            testCase.verifyEqual(sum(data.FILEID == "neaq_vessel_sample"), 2);
        end

        function testParseRowCount(testCase)
            [data, metadata] = narwc.io.parsers.NEAQVesselFormat.parse(testCase.neaq_vessel_file);
            testCase.verifyEqual(height(data), 2);
            testCase.verifyEqual(metadata.row_count, 2);
        end

    end
end
