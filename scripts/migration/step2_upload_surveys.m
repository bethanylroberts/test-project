% STEP2_UPLOAD_SURVEYS moves surveys from pending to database
% 
% Uses the output of step1 which moves surveys to the pending folder. Step2
% validates the pending surveys and then either uploads them to the database or
% reports the errors.
% 
% 2026 russ.shomberg@marineacoustics.com

% TODO: this should stay here as script for the legacy migration. However, most
% of the code should be moved into a function that can be used by the batch
% upload for the general tools

% FIXME: this is too abstract as it just calls the single
% narwc.ingestion.BatchUploader.uploadFromFolder method.
% - [ ] batch uploader should be more generic. It just needs to pull from a pending folder
% - [ ] batch uploader can be less abstract. Currently reads like java code not matlab

function stats = step2_upload_surveys(options)
    % STEP2_UPLOAD_SURVEYS Step 2: Upload surveys from pending folder to database
    %
    % Usage:
    %   step2_upload_surveys()
    %   step2_upload_surveys('Config', load_config('migration'))
    %   step2_upload_surveys('Overwrite', true)
    %   step2_upload_surveys('Validate', false)
    %   step2_upload_surveys('AllowWarnings', true)
    %   step2_upload_surveys('AllowWarnings', true, 'AllowErrors', true)

    arguments
        options.Config struct = struct()
        options.BaseDir char = 'data/legacy/surveys'
        options.Overwrite logical = false
        options.Validate logical = true
        options.StopOnError logical = false
        options.AllowWarnings logical = false
        options.AllowErrors logical = false
    end

    % FIXME: need to more easily expose these options when the scripts are run separately which is likely to be the norm

    % FIXME: `fprintf` should utilize the logging toolbox
    fprintf('=== Step 2: Uploading Surveys to Database ===\n\n');
    fprintf('Source: %s/pending/\n', options.BaseDir);
    fprintf('Options:\n');
    fprintf('  Overwrite:     %s\n', string(options.Overwrite));
    fprintf('  Validate:      %s\n', string(options.Validate));
    fprintf('  AllowWarnings: %s\n', string(options.AllowWarnings));
    fprintf('  AllowErrors:   %s\n', string(options.AllowErrors));
    fprintf('\n');
    
    % Connect to database
    if ~isempty(fieldnames(options.Config)) && isfield(options.Config, 'db')
        conn = narwc.db.Connection.create(options.Config.db);
    else
        conn = narwc.db.Connection.create();
    end

    try
        % Create uploader — LegacyMode enables legacy-leniency validation
        % settings (e.g. negative visibility) appropriate for migration data.
        converter = narwc.ingestion.BatchUploader(conn, options.BaseDir, ...
            'LegacyMode', true, 'Config', options.Config);

        % Upload all from pending folder
        converter.uploadFromFolder(...
            'Overwrite', options.Overwrite, ...
            'Validate', options.Validate, ...
            'StopOnError', options.StopOnError, ...
            'AllowWarnings', options.AllowWarnings, ...
            'AllowErrors', options.AllowErrors);
        
        % Get stats
        stats = converter.getStats();
        
        fprintf('\nStep 2 complete. Ready for Step 3 (validation)\n');
        fprintf('  Run: step3_validate_migration\n\n');
        
    catch ME
        conn.close();
        rethrow(ME);
    end
    
    conn.close();
end