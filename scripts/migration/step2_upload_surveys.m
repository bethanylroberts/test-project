function stats = step2_upload_surveys(options)
    % STEP2_UPLOAD_SURVEYS Step 2: Upload surveys from pending folder to database
    %
    % Usage:
    %   step2_upload_surveys()
    %   step2_upload_surveys('Overwrite', true)
    %   step2_upload_surveys('Validate', false)
    
    arguments
        options.BaseDir char = 'data/legacy/surveys'
        options.Overwrite logical = false
        options.Validate logical = true
        options.StopOnError logical = false
    end
    
    fprintf('=== Step 2: Uploading Surveys to Database ===\n\n');
    fprintf('Source: %s/pending/\n\n', options.BaseDir);
    
    % Connect to database
    conn = narwc.db.Connection.create();
    
    try
        % Create converter
        converter = migration.BatchConverter(conn, options.BaseDir);
        
        % Upload all from pending folder
        converter.uploadFromFolder(...
            'Overwrite', options.Overwrite, ...
            'Validate', options.Validate, ...
            'StopOnError', options.StopOnError);
        
        % Get stats
        stats = converter.getStats();
        
        fprintf('\n✓ Step 2 complete. Ready for Step 3 (validation)\n');
        fprintf('  Run: step3_validate_migration\n\n');
        
    finally
        conn.close();
    end
end