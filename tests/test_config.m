function config = test_config()
    % TEST_CONFIG Configuration for test environment
    
    % Test database settings (separate from production)
    config.use_test_db = false;  % Set to true if you have a test database
    config.test_db_name = 'NARWCDB_TEST';
    
    % Test data settings
    config.cleanup_after_tests = true;  % Remove test data after tests
    config.test_fileid_pattern = 'TEST%';  % Pattern for test FILEIDs
    
    % Fixture settings
    config.fixture_dir = fullfile(pwd, 'tests', 'fixtures');
    config.sample_data_dir = fullfile(config.fixture_dir, 'sample_data');
    config.expected_output_dir = fullfile(config.fixture_dir, 'expected_outputs');
    
    % Test execution settings
    config.parallel_tests = false;
    config.verbose_output = false;
    config.stop_on_failure = false;
end