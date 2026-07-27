classdef test_contributor_defaults < matlab.unittest.TestCase
    % TEST_CONTRIBUTOR_DEFAULTS Unit tests for
    % narwc.ingestion.lookup_contributor_defaults.
    %
    % Most tests point table_path at a temp CSV so nothing touches the real
    % data/tables/contributor_defaults.csv; a couple of tests read the real
    % seeded table directly to lock in the documented curator-confirmation
    % cases (see PROJECT_STATUS.md §8.7).

    properties
        table_path
    end

    methods (TestMethodSetup)
        function setupTablePath(testCase)
            testCase.table_path = fullfile(tempname, 'contributor_defaults.csv');
            d = fileparts(testCase.table_path);
            mkdir(d);
            fid = fopen(testCase.table_path, 'w');
            fprintf(fid, '"contributor","path_pattern","DDSOURCE","IDSOURCE","PLATFORM","notes"\n');
            % Note: real CCS subfolders are named "2023 Vessel"/"2023 Aerial"/
            % etc. -- the platform word is the second word of one path
            % segment (space-separated), not its own segment after a "/" --
            % so patterns match on "Vessel/"/"Aerial/" without a leading "/".
            fprintf(fid, '"CCS","*Vessel/TB0322*","","","","ambiguous, excluded"\n');
            fprintf(fid, '"CCS","*Vessel/*","CCS","RWC","107","R/V Shearwater"\n');
            fprintf(fid, '"CCS","*Opportunistic/*","CCS","RWC","","already per-row"\n');
            fclose(fid);
        end
    end

    methods (TestMethodTeardown)
        function cleanupTablePath(testCase)
            d = fileparts(testCase.table_path);
            if exist(d, 'dir')
                rmdir(d, 's');
            end
        end
    end

    methods (Test)

        function testMatchesGeneralPattern(testCase)
            overrides = narwc.ingestion.lookup_contributor_defaults('CCS', ...
                'data/surveys/raw/CCS/2023 Vessel/SW1375.csv', testCase.table_path);

            testCase.verifyEqual(overrides.DDSOURCE, 'CCS');
            testCase.verifyEqual(overrides.IDSOURCE, 'RWC');
            testCase.verifyEqual(overrides.PLATFORM, 107);
        end

        function testMoreSpecificRowWinsOverGeneralOne(testCase)
            overrides = narwc.ingestion.lookup_contributor_defaults('CCS', ...
                'data/surveys/raw/CCS/2023 Vessel/TB032223.csv', testCase.table_path);

            testCase.verifyFalse(isfield(overrides, 'DDSOURCE'));
            testCase.verifyFalse(isfield(overrides, 'IDSOURCE'));
            testCase.verifyFalse(isfield(overrides, 'PLATFORM'), ...
                'The ambiguous-platform row must win and leave PLATFORM unset');
        end

        function testBlankPlatformOmittedFromResult(testCase)
            overrides = narwc.ingestion.lookup_contributor_defaults('CCS', ...
                'data/surveys/raw/CCS/2023 Opportunistic/Mar-22.csv', testCase.table_path);

            testCase.verifyEqual(overrides.DDSOURCE, 'CCS');
            testCase.verifyFalse(isfield(overrides, 'PLATFORM'), ...
                'A blank PLATFORM cell must not appear in the returned struct');
        end

        function testNoMatchReturnsEmptyStruct(testCase)
            overrides = narwc.ingestion.lookup_contributor_defaults('SEUS EWS', ...
                'data/surveys/raw/SEUS EWS/Winter 2021-22/FLWS2122.dbf', testCase.table_path);

            testCase.verifyEqual(overrides, struct());
        end

        function testMissingTableReturnsEmptyStruct(testCase)
            overrides = narwc.ingestion.lookup_contributor_defaults('CCS', ...
                'anything.csv', fullfile(tempname, 'does_not_exist.csv'));
            testCase.verifyEqual(overrides, struct());
        end

        function testContributorMismatchDoesNotMatch(testCase)
            overrides = narwc.ingestion.lookup_contributor_defaults('NEAQ Aerial', ...
                'data/surveys/raw/CCS/2023 Vessel/SW1375.csv', testCase.table_path);
            testCase.verifyEqual(overrides, struct());
        end

        function testRealSeededTableFlagsAmbiguousCcsVesselFile(testCase)
            % Locks in the real, checked-in table's documented curator-
            % confirmation case (PROJECT_STATUS.md §8.7): the ambiguous
            % Tow Boat US charter file must resolve to no PLATFORM.
            real_table = fullfile('data', 'tables', 'contributor_defaults.csv');
            testCase.assumeTrue(exist(real_table, 'file') == 2);

            overrides = narwc.ingestion.lookup_contributor_defaults('CCS', ...
                'data/surveys/raw/CCS/2023 Vessel/TB032223.csv', real_table);

            testCase.verifyFalse(isfield(overrides, 'PLATFORM'));
        end

        function testRealSeededTableResolvesNeaqAerial(testCase)
            real_table = fullfile('data', 'tables', 'contributor_defaults.csv');
            testCase.assumeTrue(exist(real_table, 'file') == 2);

            overrides = narwc.ingestion.lookup_contributor_defaults('NEAQ Aerial', ...
                'data/surveys/raw/NEAQ Aerial/Wind Energy Area 2024/NEAQ-A-20240301_URI.csv', real_table);

            testCase.verifyEqual(overrides.DDSOURCE, 'NEA');
            testCase.verifyEqual(overrides.IDSOURCE, 'MCE');
            testCase.verifyEqual(overrides.PLATFORM, 651);
        end

    end
end
