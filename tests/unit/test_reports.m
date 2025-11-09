classdef test_reports < matlab.unittest.TestCase
    % TEST_REPORTS Unit tests for report generation
    
    properties
        test_output_dir
    end
    
    methods (TestMethodSetup)
        function createOutputDir(testCase)
            testCase.test_output_dir = tempname;
            mkdir(testCase.test_output_dir);
        end
    end
    
    methods (TestMethodTeardown)
        function cleanupOutputDir(testCase)
            if exist(testCase.test_output_dir, 'dir')
                rmdir(testCase.test_output_dir, 's');
            end
        end
    end
    
    methods (Test)
        function testProcessingReport(testCase)
            % Test processing report generation
            
            tracker = narwc.processing.ChangeTracker();
            tracker.recordChange('test_step', 1, 'field1', 'old', 'new', 'Test change');
            
            report = narwc.reports.ProcessingReport(tracker, 'TEST001');
            output_file = fullfile(testCase.test_output_dir, 'processing.md');
            
            report.generate(output_file);
            
            testCase.verifyTrue(exist(output_file, 'file') > 0);
            
            % Check content
            content = fileread(output_file);
            testCase.verifySubstring(content, 'Processing Report');
            testCase.verifySubstring(content, 'TEST001');
        end
        
        function testValidationReport(testCase)
            % Test validation report generation
            
            % Create mock validation results
            results = struct();
            results.errors = struct('field', {'LAT_DD'}, 'row', {1}, ...
                'message', {'Out of range'}, 'severity', {'error'});
            results.warnings = [];
            results.info = [];
            results.summary = struct('errors', 1, 'warnings', 0, 'info', 0, ...
                'by_field', struct('LAT_DD', 1));
            
            report = narwc.reports.ValidationReport(results, 'TEST001');
            output_file = fullfile(testCase.test_output_dir, 'validation.md');
            
            report.generate(output_file);
            
            testCase.verifyTrue(exist(output_file, 'file') > 0);
            
            % Check content
            content = fileread(output_file);
            testCase.verifySubstring(content, 'Validation Report');
            testCase.verifySubstring(content, 'FAILED');
        end
        
        function testSummaryStatistics(testCase)
            % Test summary statistics report
            
            data = TestFixtures.generate_mock_survey(10);
            
            report = narwc.reports.SummaryStatistics(data, 'TEST001');
            output_file = fullfile(testCase.test_output_dir, 'summary.md');
            
            report.generate(output_file);
            
            testCase.verifyTrue(exist(output_file, 'file') > 0);
            
            % Check content
            content = fileread(output_file);
            testCase.verifySubstring(content, 'Survey Summary Statistics');
            testCase.verifySubstring(content, 'Total Records');
        end
    end
end