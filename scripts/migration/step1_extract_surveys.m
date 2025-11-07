function step1_extract_surveys(csv_file, options)
    % STEP1_EXTRACT_SURVEYS Step 1: Extract individual surveys from CSV
    %
    % Usage:
    %   step1_extract_surveys('data/legacy/original_csv/RUSS_24_VALID.CSV')
    %   step1_extract_surveys('legacy.csv', 'Overwrite', true)
    
    arguments
        csv_file char
        options.OutputDir char = 'data/legacy/surveys/pending'
        options.Overwrite logical = false
        options.ChunkSize double = 10000
    end
    
    fprintf('=== Step 1: Extracting Surveys from CSV ===\n\n');
    fprintf('Source: %s\n', csv_file);
    fprintf('Destination: %s\n\n', options.OutputDir);
    
    % Create extractor
    extractor = migration.SurveyExtractor(csv_file, options.ChunkSize);
    
    % Extract all
    extractor.extractAll(options.OutputDir, 'Overwrite', options.Overwrite);
    
    fprintf('\n✓ Step 1 complete. Ready for Step 2 (upload to database)\n');
    fprintf('  Run: step2_upload_surveys\n\n');
end