function stats = run_batch_upload(base_dir, config, options)
    % RUN_BATCH_UPLOAD Connect, validate+upload from base_dir/pending, return stats.
    %
    % Shared by scripts/migration/step2_upload_surveys.m (migration) and
    % scripts/ingestion/upload_contributor_batch.m (routine ingestion) --
    % the only difference between the two callers is the default base_dir
    % and console messaging. BatchUploader itself needs no changes; this
    % just extracts the connect/upload/stats/close glue both scripts need.
    %
    % Usage:
    %   stats = narwc.ingestion.run_batch_upload('data/raw', load_config('routine'));

    arguments
        base_dir char
        config struct
        options.Overwrite logical = false
        options.Validate logical = true
        options.StopOnError logical = false
        options.AllowWarnings logical = false
        options.AllowErrors logical = false
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
            'AllowErrors', options.AllowErrors);

        stats = uploader.getStats();
    catch ME
        conn.close();
        rethrow(ME);
    end

    conn.close();
end
