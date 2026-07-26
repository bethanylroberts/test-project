% STEP2_UPLOAD_SURVEYS moves surveys from pending to database
%
% Thin, migration-flavored wrapper over the shared
% scripts/ingestion/upload_contributor_batch.m -- kept as an ergonomic entry
% point for the familiar step1/step2/step3 migration workflow. Defaults to
% the 'migration' validation config profile (permissive legacy-quirk
% overrides), unlike routine ingestion's strict defaults.
%
% 2026 russ.shomberg@marineacoustics.com

function stats = step2_upload_surveys(options)
    % STEP2_UPLOAD_SURVEYS Step 2: Upload surveys from pending folder to database
    %
    % Usage:
    %   step2_upload_surveys()
    %   step2_upload_surveys('BatchId', '2026-07-26_14-30-12_legacy')
    %   step2_upload_surveys('Overwrite', true)
    %   step2_upload_surveys('Validate', false)
    %   step2_upload_surveys('AllowWarnings', true)
    %   step2_upload_surveys('AllowWarnings', true, 'AllowErrors', true)

    arguments
        options.Config struct = struct()
        options.BatchId char = ''
        options.Overwrite logical = false
        options.Validate logical = true
        options.StopOnError logical = false
        options.AllowWarnings logical = false
        options.AllowErrors logical = false
    end

    fprintf('=== Step 2: Uploading Surveys to Database ===\n\n');

    config = options.Config;
    if isempty(fieldnames(config))
        config = load_config('migration');
    end

    stats = upload_contributor_batch('Config', config, ...
        'BatchId', options.BatchId, ...
        'Overwrite', options.Overwrite, ...
        'Validate', options.Validate, ...
        'StopOnError', options.StopOnError, ...
        'AllowWarnings', options.AllowWarnings, ...
        'AllowErrors', options.AllowErrors);

    fprintf('\nStep 2 complete. Ready for Step 3 (validation)\n');
    fprintf('  Run: step3_validate_migration(''BatchId'', ''%s'')\n\n', options.BatchId);
end
