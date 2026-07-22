% UPLOAD_CONTRIBUTOR_BATCH validates and uploads routine contributor surveys
%
% Uses the output of convert_contributor_batch, which writes one CSV per
% survey to data/raw/pending/. Validates and either uploads to the database
% or reports the errors -- the routine-ingestion counterpart of
% scripts/migration/step2_upload_surveys.m, sharing the same
% narwc.ingestion.run_batch_upload helper.

function stats = upload_contributor_batch(options)
    % UPLOAD_CONTRIBUTOR_BATCH Upload surveys from data/raw/pending to database
    %
    % Usage:
    %   upload_contributor_batch()
    %   upload_contributor_batch('Config', load_config('routine'))
    %   upload_contributor_batch('Overwrite', true)

    arguments
        options.Config struct = struct()
        options.BaseDir char = 'data/raw'
        options.Overwrite logical = false
        options.Validate logical = true
        options.StopOnError logical = false
        options.AllowWarnings logical = false
        options.AllowErrors logical = false
    end

    fprintf('=== Uploading Contributor Batch to Database ===\n\n');
    fprintf('Source: %s/pending/\n', options.BaseDir);
    fprintf('Options:\n');
    fprintf('  Overwrite:     %s\n', string(options.Overwrite));
    fprintf('  Validate:      %s\n', string(options.Validate));
    fprintf('  AllowWarnings: %s\n', string(options.AllowWarnings));
    fprintf('  AllowErrors:   %s\n', string(options.AllowErrors));
    fprintf('\n');

    stats = narwc.ingestion.run_batch_upload(options.BaseDir, options.Config, ...
        'Overwrite', options.Overwrite, ...
        'Validate', options.Validate, ...
        'StopOnError', options.StopOnError, ...
        'AllowWarnings', options.AllowWarnings, ...
        'AllowErrors', options.AllowErrors);

    fprintf('\nUpload complete.\n\n');
end
