% STEP1_EXTRACT_SURVEYS pulls individual surveys out of a large CSV
% 
% Opens the CSV from the original legacy database and pulls out individual
% surveys. These surveys can then be checked and then uploaded individually.
% 
% 2026 russ.shomberg@marineacoustics.com

% FIXME: this script/function is likely too abstract. Since this is not going to
% regularly run, having an entire `+migration` toolbox and functions does not
% really make sense. Can I just move the relevant code into this script, and
% remove any relevant tests?

function step1_extract_surveys(csv_file, options)
    % STEP1_EXTRACT_SURVEYS Step 1: Extract individual surveys from CSV
    %
    % Usage:
    %   step1_extract_surveys('data/legacy/original_csv/RUSS_24_VALID.CSV')
    %   step1_extract_surveys('legacy.csv', 'Overwrite', true)
    
    arguments
        csv_file char
        options.OutputDir char = 'data/legacy/surveys/pending'
        options.Overwrite logical = false   % ???: does this overwrite work?
        options.ChunkSize double = 10000
    end

    % FIXME: need to more easily expose these options when the scripts are run separately which is likely to be the norm
    
    % FIXME: `fprintf` should use the logging toolbox instead
    fprintf('=== Step 1: Extracting Surveys from CSV ===\n\n');
    fprintf('Source: %s\n', csv_file);
    fprintf('Destination: %s\n\n', options.OutputDir);
    
    % Create extractor
    extractor = narwc.ingestion.SurveyExtractor(csv_file, options.ChunkSize);
    
    % Extract all
    extractor.extractAll(options.OutputDir, 'Overwrite', options.Overwrite);
    
    fprintf('\nStep 1 complete. Ready for Step 2 (upload to database)\n');
    fprintf('  Run: step2_upload_surveys\n\n');
end