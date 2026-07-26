% UPLOAD_CONTRIBUTOR_BATCH validates and uploads surveys from pending/
%
% Uses the output of convert_contributor_batch, which writes one CSV per
% survey to data/surveys/pending/ -- for every source, including the legacy
% migration. Validates and either uploads to the database or reports the
% errors, via the shared narwc.ingestion.run_batch_upload helper.
%
% Pass 'BatchId' to scope the run to one batch's files (looked up in the
% batch ledger -- see narwc.ingestion.append_batch_log) instead of
% processing everything currently in pending/, which matters once more than
% one batch's files can be sitting there at once. The run is recorded as an
% 'upload' row in the same ledger either way.

function stats = upload_contributor_batch(options)
    % UPLOAD_CONTRIBUTOR_BATCH Upload surveys from data/surveys/pending to database
    %
    % Usage:
    %   upload_contributor_batch()
    %   upload_contributor_batch('Config', load_config('routine'))
    %   upload_contributor_batch('Config', load_config('migration'))
    %   upload_contributor_batch('Overwrite', true)
    %   upload_contributor_batch('BatchId', '2026-07-26_14-30-12_legacy')

    arguments
        options.Config struct = struct()
        options.BaseDir char = 'data/surveys'
        options.Overwrite logical = false
        options.Validate logical = true
        options.StopOnError logical = false
        options.AllowWarnings logical = false
        options.AllowErrors logical = false
        options.BatchId char = ''
    end

    fprintf('=== Uploading Surveys to Database ===\n\n');
    fprintf('Source: %s/pending/\n', options.BaseDir);
    if ~isempty(options.BatchId)
        fprintf('Batch:  %s\n', options.BatchId);
    end
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
        'AllowErrors', options.AllowErrors, ...
        'BatchId', options.BatchId);

    fprintf('\nUpload complete.\n\n');

    source = '';
    if ~isempty(options.BatchId)
        ledger = narwc.ingestion.read_batch_log();
        is_match = strcmp(ledger.stage, 'convert') & strcmp(ledger.batch_id, options.BatchId);
        matches = ledger(is_match, :);
        if height(matches) > 0
            source = matches.source{end};
        end
    end

    notes = sprintf('uploaded=%d updated=%d skipped=%d rejected=%d', ...
        stats.uploaded, stats.updated, stats.skipped, stats.rejected);
    narwc.ingestion.append_batch_log(struct( ...
        'batch_id', options.BatchId, 'stage', 'upload', 'source', source, ...
        'input', fullfile(options.BaseDir, 'pending'), 'output', options.BaseDir, ...
        'notes', notes));
end
