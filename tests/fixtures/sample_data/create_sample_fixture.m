function create_sample_fixture()
    % CREATE_SAMPLE_FIXTURE Create sample test data
    
    % Generate small sample survey
    sample_survey = TestFixtures.generate_mock_survey(5);
    
    % Save as MAT file
    save('tests/fixtures/sample_data/sample_survey.mat', 'sample_survey');
    
    % Save as CSV
    writetable(sample_survey, 'tests/fixtures/sample_data/sample_survey.csv');
    
    fprintf('Created sample fixtures:\n');
    fprintf('  - sample_survey.mat\n');
    fprintf('  - sample_survey.csv\n');
end