function extract_surveys_from_csv(legacy_file, output_dir, options)
    % EXTRACT_SURVEYS_FROM_CSV Extract all surveys from legacy CSV
    %
    % Usage:
    %   extract_surveys_from_csv('data/legacy/RUSS_24_VALID.CSV')
    %   extract_surveys_from_csv('legacy.csv', 'data/extracted')
    %   extract_surveys_from_csv('legacy.csv', 'data/extracted', 'Overwrite', true)
    
    arguments
        legacy_file char
        output_dir char = 'data/legacy/extracted_surveys'
        options.Overwrite logical = false
        options.ChunkSize double = 10000
    end
    
    fprintf('=== Extracting Surveys from Legacy CSV ===\n\n');
    
    % Create extractor
    extractor = migration.SurveyExtractor(legacy_file, options.ChunkSize);
    
    % Extract all
    extractor.extractAll(output_dir, 'Overwrite', options.Overwrite);
    
    fprintf('\n✓ Extraction complete. Files saved to: %s\n', output_dir);
end