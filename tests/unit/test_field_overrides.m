classdef test_field_overrides < matlab.unittest.TestCase
    % TEST_FIELD_OVERRIDES Tests for narwc.ingestion.apply_field_overrides.
    %
    % No database connection required.

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

    methods (Test)

        function testAppliesStringOverrideToEveryRow(testCase)
            data = TestFixtures.generate_mock_survey(3);
            overrides = struct('DDSOURCE', 'CCS', 'IDSOURCE', 'RWC');

            result = narwc.ingestion.apply_field_overrides(data, overrides);

            testCase.verifyEqual(sum(string(result.DDSOURCE) == "CCS"), 3);
            testCase.verifyEqual(sum(string(result.IDSOURCE) == "RWC"), 3);
        end

        function testAppliesNumericOverrideToEveryRow(testCase)
            data = TestFixtures.generate_mock_survey(3);
            overrides = struct('PLATFORM', 649);

            result = narwc.ingestion.apply_field_overrides(data, overrides);

            testCase.verifyEqual(result.PLATFORM, [649; 649; 649]);
        end

        function testSkipsBlankStringOverride(testCase)
            data = TestFixtures.generate_mock_survey(3);
            original_platform = data.PLATFORM;
            overrides = struct('PLATFORM', [], 'DDSOURCE', '   ');

            result = narwc.ingestion.apply_field_overrides(data, overrides);

            testCase.verifyEqual(result.PLATFORM, original_platform, ...
                'An empty override value must leave the existing column untouched');
            testCase.verifyEqual(result.DDSOURCE, data.DDSOURCE, ...
                'A whitespace-only override value must leave the existing column untouched');
        end

        function testEmptyOverridesStructIsNoOp(testCase)
            data = TestFixtures.generate_mock_survey(3);
            result = narwc.ingestion.apply_field_overrides(data, struct());
            testCase.verifyEqual(result, data);
        end

        function testRejectsNonCanonicalFieldName(testCase)
            data = TestFixtures.generate_mock_survey(3);
            overrides = struct('NOT_A_REAL_FIELD', 'X');

            testCase.verifyError(@() narwc.ingestion.apply_field_overrides(data, overrides), ...
                'apply_field_overrides:UnknownField');
        end

    end
end
