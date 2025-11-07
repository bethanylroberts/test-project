function results = test_runner(test_type, options)
    % TEST_RUNNER Run tests for NARWC Database Project
    %
    % Usage:
    %   test_runner()                          % Run all tests
    %   test_runner('unit')                    % Run only unit tests
    %   test_runner('integration')             % Run only integration tests
    %   test_runner('all')                     % Run all tests
    %   test_runner('all', 'Verbose', true)    % Run with verbose output
    %   test_runner('all', 'Coverage', true)   % Run with code coverage
    %
    % Options:
    %   'Verbose' - Show detailed output (default: false)
    %   'Coverage' - Generate code coverage report (default: false)
    %   'StopOnError' - Stop on first error (default: false)
    %   'Parallel' - Run tests in parallel (default: false)
    
    arguments
        test_type char {mustBeMember(test_type, {'all', 'unit', 'integration'})} = 'all'
        options.Verbose logical = false
        options.Coverage logical = false
        options.StopOnError logical = false
        options.Parallel logical = false
    end
    
    fprintf('\n=== NARWC Database Project Test Runner ===\n\n');
    
    % Get test directory
    test_dir = fileparts(mfilename('fullpath'));
    
    % Build test suite based on type
    switch test_type
        case 'all'
            fprintf('Running all tests...\n\n');
            suite = [testsuite(fullfile(test_dir, 'unit')), ...
                     testsuite(fullfile(test_dir, 'integration'))];
            
        case 'unit'
            fprintf('Running unit tests...\n\n');
            if ~exist(fullfile(test_dir, 'unit'), 'dir')
                error('Unit test directory not found');
            end
            suite = testsuite(fullfile(test_dir, 'unit'));
            
        case 'integration'
            fprintf('Running integration tests...\n\n');
            if ~exist(fullfile(test_dir, 'integration'), 'dir')
                error('Integration test directory not found');
            end
            suite = testsuite(fullfile(test_dir, 'integration'));
    end
    
    % Configure test runner
    runner = matlab.unittest.TestRunner.withTextOutput;
    
    % Add verbose output if requested
    if options.Verbose
        import matlab.unittest.plugins.DiagnosticsOutputPlugin
        runner.addPlugin(DiagnosticsOutputPlugin);
    end
    
    % Add code coverage if requested
    if options.Coverage
        try
            import matlab.unittest.plugins.CodeCoveragePlugin
            src_dir = fullfile(fileparts(test_dir), 'src');
            runner.addPlugin(CodeCoveragePlugin.forFolder(src_dir, ...
                'IncludingSubfolders', true));
            fprintf('Code coverage enabled for src/ directory\n');
        catch ME
            warning('Code coverage not available: %s', ME.message);
        end
    end
    
    % Add stop-on-error if requested
    if options.StopOnError
        import matlab.unittest.plugins.StopOnFailuresPlugin
        runner.addPlugin(StopOnFailuresPlugin);
    end
    
    % Run tests (parallel or serial)
    if options.Parallel
        try
            results = runInParallel(runner, suite);
            fprintf('\nTests run in parallel\n');
        catch ME
            warning('Parallel execution failed, running serially: %s', ME.message);
            results = run(runner, suite);
        end
    else
        results = run(runner, suite);
    end
    
    % Display summary
    fprintf('\n=== Test Summary ===\n');
    fprintf('Total tests:  %d\n', numel(results));
    fprintf('Passed:       %d\n', sum([results.Passed]));
    fprintf('Failed:       %d\n', sum([results.Failed]));
    fprintf('Incomplete:   %d\n', sum([results.Incomplete]));
    fprintf('Duration:     %.2f seconds\n', sum([results.Duration]));
    
    % Show failed tests
    if sum([results.Failed]) > 0
        fprintf('\n=== Failed Tests ===\n');
        failed_tests = results([results.Failed]);
        for i = 1:length(failed_tests)
            fprintf('  ✗ %s\n', failed_tests(i).Name);
        end
    end
    
    % Exit with error if tests failed
    if sum([results.Failed]) > 0
        fprintf('\n❌ Some tests failed!\n\n');
    else
        fprintf('\n✅ All tests passed!\n\n');
    end
end