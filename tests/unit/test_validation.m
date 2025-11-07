classdef test_validation < matlab.unittest.TestCase
    % TEST_VALIDATION Unit tests for validation framework
    
    methods (Test)
        function testErrorCollector(testCase)
            % Test ErrorCollector functionality
            
            collector = narwc.validation.ErrorCollector();
            
            % Add errors
            collector.addError('LAT_DD', 1, 'Test error', 'error');
            collector.addError('LONG_DD', 2, 'Test warning', 'warning');
            
            % Check counts
            testCase.verifyEqual(collector.getErrorCount(), 2);
            testCase.verifyEqual(collector.getErrorCount('error'), 1);
            testCase.verifyEqual(collector.getErrorCount('warning'), 1);
            
            % Get errors
            errors = collector.getErrors('error');
            testCase.verifyEqual(length(errors), 1);
            testCase.verifyEqual(errors(1).field, 'LAT_DD');
            
            % Clear
            collector.clear();
            testCase.verifyEqual(collector.getErrorCount(), 0);
        end
        
        function testFieldValidatorRange(testCase)
            % Test range validation
            
            values = [1; 5; 10; 15; 20];
            [is_valid, invalid] = narwc.validation.FieldValidator.validateRange(values, 5, 15);
            
            testCase.verifyEqual(is_valid, [false; true; true; true; false]);
            testCase.verifyEqual(invalid, [1; 5]);
        end
        
        function testFieldValidatorMissing(testCase)
            % Test missing value validation
            
            values = [1; NaN; 3; NaN; 5];
            [is_valid, invalid] = narwc.validation.FieldValidator.validateNotMissing(values);
            
            testCase.verifyEqual(sum(~is_valid), 2);
            testCase.verifyEqual(invalid, [2; 4]);
        end
        
        function testFieldValidatorInSet(testCase)
            % Test set membership validation
            
            values = {'RIWH'; 'FIWH'; 'HUWH'; 'UNKNOWN'};
            valid_set = {'RIWH', 'FIWH', 'HUWH', 'SEWH'};
            [is_valid, invalid] = narwc.validation.FieldValidator.validateInSet(values, valid_set);
            
            testCase.verifyFalse(is_valid(4));
            testCase.verifyEqual(invalid, 4);
        end
        
        function testCoordinateValidation(testCase)
            % Test coordinate validation rules
            
            % Create test data
            data = table();
            data.LAT_DD = [41.5; 100; NaN; 42.0];  % One out of range, one missing
            data.LONG_DD = [-70.0; -71.0; -72.0; NaN];  % One missing
            
            collector = narwc.validation.ErrorCollector();
            narwc.validation.rules.coordinate_rules(data, collector);
            
            % Should have errors
            testCase.verifyGreaterThan(collector.getErrorCount('error'), 0);
        end
        
        function testSurveyValidator(testCase)
            % Test main validator
            
            % Create test data
            data = TestFixtures.generate_mock_survey(10);
            
            % Add some invalid data
            data.LAT_DD(1) = 100;  % Invalid
            data.LONG_DD(2) = NaN; % Missing
            
            % Validate
            validator = narwc.validation.SurveyValidator();
            [is_valid, results] = validator.validate(data);
            
            % Should be invalid
            testCase.verifyFalse(is_valid);
            testCase.verifyGreaterThan(results.summary.errors, 0);
        end
        
        function testValidDataPasses(testCase)
            % Test that valid data passes validation
            
            % Create valid test data
            data = TestFixtures.generate_mock_survey(10);
            
            % Validate
            validator = narwc.validation.SurveyValidator();
            [is_valid, results] = validator.validate(data);
            
            % Should be valid (or only warnings)
            testCase.verifyTrue(is_valid || results.summary.errors == 0);
        end
    end
end