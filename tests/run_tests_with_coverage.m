function results = run_tests_with_coverage()
    % RUN_TESTS_WITH_COVERAGE Run all tests with code coverage
    results = test_runner('all', 'Verbose', true, 'Coverage', true);
end