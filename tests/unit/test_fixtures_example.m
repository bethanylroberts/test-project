classdef test_fixtures_example < matlab.unittest.TestCase
    % TEST_FIXTURES_EXAMPLE Example showing how to use test fixtures
    
    methods (Test)
        function testLoadFixture(testCase)
            % Test loading a fixture file
            data = TestFixtures.load('sample_survey.mat');
            testCase.verifyClass(data, 'table');
            testCase.verifyGreaterThan(height(data), 0);
        end
        
        function testMockData(testCase)
            % Test generating mock data
            data = TestFixtures.generate_mock_survey(10);
            testCase.verifyEqual(height(data), 10);
            % FIXME: this format is wrong
            testCase.verifyTrue(all(ismember({'ALT', 'LAT_DD', 'LONG_DD', 'FILEID'}, ...
                data.Properties.VariableNames)));
        end
    end
end