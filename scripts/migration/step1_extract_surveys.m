% STEP1_EXTRACT_SURVEYS pulls individual surveys out of the legacy CSV
%
% Thin, migration-flavored wrapper over the shared
% scripts/ingestion/convert_contributor_batch.m ('legacy' contributor,
% StandardFormat parser) -- kept as an ergonomic entry point for the
% familiar step1/step2/step3 migration workflow.
%
% 2026 russ.shomberg@marineacoustics.com

function summary = step1_extract_surveys(csv_file, options)
    % STEP1_EXTRACT_SURVEYS Step 1: Extract individual surveys from the legacy CSV
    %
    % Usage:
    %   step1_extract_surveys('data/surveys/RUSS_24_VALID.CSV')
    %   step1_extract_surveys('legacy.csv', 'Overwrite', true)

    arguments
        csv_file char
        options.OutputDir char = fullfile('data', 'surveys', 'pending')
        options.Overwrite logical = false
        options.ChunkSize double = 10000
    end

    fprintf('=== Step 1: Extracting Surveys from CSV ===\n\n');

    summary = convert_contributor_batch('legacy', 'StandardFormat', ...
        'InputFile', csv_file, ...
        'OutputDir', options.OutputDir, ...
        'Overwrite', options.Overwrite, ...
        'ChunkSize', options.ChunkSize);

    fprintf('\nStep 1 complete. Ready for Step 2 (upload to database)\n');
    fprintf('  Run: step2_upload_surveys(''BatchId'', ''%s'')\n\n', summary.batch_id);
end
