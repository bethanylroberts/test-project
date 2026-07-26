function stats = run_batch_upload(base_dir, config, options)
    % RUN_BATCH_UPLOAD Connect, validate+upload from base_dir/pending, return stats.
    %
    % Shared connect/upload/stats/close glue used by
    % scripts/ingestion/upload_contributor_batch.m for every source -- legacy
    % migration and routine contributor ingestion alike, since both now share
    % the same data/surveys base_dir. Only the validation config profile
    % (load_config('migration') vs. load_config('routine')) differs per run.
    %
    % Usage:
    %   stats = narwc.ingestion.run_batch_upload('data/surveys', load_config('routine'));

    arguments
        base_dir char
        config struct
        options.Overwrite logical = false
        options.Validate logical = true
        options.StopOnError logical = false
        options.AllowWarnings logical = false
        options.AllowErrors logical = false
        options.BatchId char = ''
        options.SplitSummaryFile char = ''
    end

    if ~isempty(fieldnames(config)) && isfield(config, 'db')
        conn = narwc.db.Connection.create(config.db);
    else
        conn = narwc.db.Connection.create();
    end

    try
        uploader = narwc.ingestion.BatchUploader(conn, base_dir, 'Config', config);

        uploader.uploadFromFolder(...
            'Overwrite', options.Overwrite, ...
            'Validate', options.Validate, ...
            'StopOnError', options.StopOnError, ...
            'AllowWarnings', options.AllowWarnings, ...
            'AllowErrors', options.AllowErrors, ...
            'BatchId', options.BatchId, ...
            'SplitSummaryFile', options.SplitSummaryFile);

        stats = uploader.getStats();
    catch ME
        conn.close();
        rethrow(ME);
    end

    conn.close();
end
