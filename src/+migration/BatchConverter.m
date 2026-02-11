classdef BatchConverter < handle
    % BATCHCONVERTER Batch upload surveys to database with file management
    %
    % Usage:
    %   converter = migration.BatchConverter(conn);
    %   converter.uploadFromFolder('data/legacy/surveys/pending');
    
    properties (Access = private)
        connection
        logger
        stats
        base_dir
        error_log_file
    end
    
    methods
        function obj = BatchConverter(connection, base_dir)
            % BATCHCONVERTER Constructor
            
            obj.connection = connection;
            obj.logger = logging.Logger('migration.BatchConverter');
            
            if nargin < 2
                obj.base_dir = 'data/legacy/surveys';
            else
                obj.base_dir = base_dir;
            end
            
            obj.resetStats();
            obj.ensureDirectories();
            obj.initializeErrorLog();
        end
        
        function ensureDirectories(obj)
            % ENSUREDIRECTORIES Create necessary directories
            
            dirs = {'pending', 'processed', 'failed', 'skipped'};
            for i = 1:length(dirs)
                dir_path = fullfile(obj.base_dir, dirs{i});
                if ~exist(dir_path, 'dir')
                    mkdir(dir_path);
                end
            end
        end
        
        function initializeErrorLog(obj)
            % INITIALIZEERRORLOG Create/reset error log file
            
            failed_dir = fullfile(obj.base_dir, 'failed');
            obj.error_log_file = fullfile(failed_dir, '_errors.log');
            
            % Create new error log (overwrites existing)
            fid = fopen(obj.error_log_file, 'w');
            if fid == -1
                obj.logger.warning('Could not create error log file');
                return;
            end
            
            fprintf(fid, 'Migration Error Log\n');
            fprintf(fid, '===================\n');
            fprintf(fid, 'Started: %s\n', char(datetime('now')));
            fprintf(fid, 'Base Directory: %s\n', obj.base_dir);
            fprintf(fid, '%s\n\n', repmat('=', 1, 80));
            fclose(fid);
            
            obj.logger.debug(sprintf('Error log initialized: %s', obj.error_log_file));
        end
        
        function uploadFromFolder(obj, options)
            % UPLOADFROMFOLDER Upload all surveys from pending folder
            %
            % Inputs:
            %   options - Name-value pairs:
            %       'Overwrite' - Overwrite existing data (default: false)
            %       'Validate' - Validate before upload (default: true)
            %       'StopOnError' - Stop on first error (default: false)
            %       'AllowWarnings' - Upload despite warnings (default: false)
            %       'AllowErrors' - Upload despite errors (default: false)
            
            arguments
                obj
                options.Overwrite logical = false
                options.Validate logical = true
                options.StopOnError logical = false
                options.AllowWarnings logical = false
                options.AllowErrors logical = false
            end
            
            pending_dir = fullfile(obj.base_dir, 'pending');
            
            % Get list of CSV files
            files = dir(fullfile(pending_dir, '*.csv'));
            
            % Remove summary file if present
            files = files(~strcmp({files.name}, '_split_summary.txt'));
            
            obj.logger.info(sprintf('Found %d surveys to upload', length(files)));
            obj.resetStats();
            
            for i = 1:length(files)
                file_path = fullfile(files(i).folder, files(i).name);
                
                fprintf('[%d/%d] Processing %s...\n', i, length(files), files(i).name);
                
                try
                    % Read survey data
                    survey_data = readtable(file_path);
                    
                    % Upload
                    [success, category] = obj.uploadSurvey(survey_data, ...
                        'Overwrite', options.Overwrite, ...
                        'Validate', options.Validate, ...
                        'AllowWarnings', options.AllowWarnings, ...
                        'AllowErrors', options.AllowErrors);
                    
                    % Move file to appropriate folder
                    obj.moveFile(file_path, category);
                    
                catch ME
                    obj.logger.error(sprintf('Error processing %s: %s', ...
                        files(i).name, ME.message));
                    
                    obj.logError(files(i).name, ME, 'File processing error');
                    
                    obj.stats.failed = obj.stats.failed + 1;
                    obj.moveFile(file_path, 'failed');
                    
                    if options.StopOnError
                        obj.logger.error('Stopping due to error');
                        break;
                    end
                end
            end
            
            obj.writeErrorSummary();
            obj.displayStats();
        end
        
        function [success, category] = uploadSurvey(obj, survey_data, options)
            % UPLOADSURVEY Upload a single survey
            
            arguments
                obj
                survey_data table
                options.Overwrite logical = false
                options.Validate logical = true
                options.AllowWarnings logical = false
                options.AllowErrors logical = false
            end
            
            % Get survey ID
            if ismember('FILEID', survey_data.Properties.VariableNames)
                survey_id = survey_data.FILEID{1};
            else
                error('No FILEID found in survey data');
            end
            
            obj.logger.info(sprintf('Uploading survey: %s (%d records)', ...
                survey_id, height(survey_data)));
            
            % Validate if requested
            if options.Validate
                % Create validator config with override options
                validator_config = struct();
                validator_config.allow_warnings = options.AllowWarnings;
                validator_config.allow_errors = options.AllowErrors;
                
                validator = narwc.validation.SurveyValidator(validator_config);
                [is_valid, results] = validator.validate(survey_data);
                
                if ~is_valid
                    has_errors = results.summary.errors > 0;
                    has_warnings = results.summary.warnings > 0;
                    
                    % Log what's blocking
                    if has_errors && ~options.AllowErrors
                        obj.logger.error(sprintf('%s has %d validation errors', ...
                            survey_id, results.summary.errors));
                    end
                    if has_warnings && ~options.AllowWarnings
                        obj.logger.warning(sprintf('%s has %d validation warnings', ...
                            survey_id, results.summary.warnings));
                    end
                    
                    % Log validation details
                    validation_err = struct();
                    validation_err.message = sprintf('Validation failed: %d errors, %d warnings', ...
                        results.summary.errors, results.summary.warnings);
                    validation_err.identifier = 'Migration:ValidationFailed';
                    validation_err.stack = dbstack();
                    obj.logError(survey_id, validation_err, 'Validation error', results);
                    
                    obj.stats.failed = obj.stats.failed + 1;
                    success = false;
                    category = 'failed';
                    return;
                end
            end
            
            % Check if exists
            exists = obj.surveyExists(survey_id);
            
            if exists && ~options.Overwrite
                obj.logger.info(sprintf('%s already exists in database, skipping', survey_id));
                obj.stats.skipped = obj.stats.skipped + 1;
                success = true;
                category = 'skipped';
                return;
            end
            
            try
                % Delete existing if overwriting
                if exists
                    obj.logger.info(sprintf('Deleting existing records for %s', survey_id));
                    delete_query = sprintf("DELETE FROM Master WHERE FILEID = '%s'", survey_id);
                    obj.connection.execute(delete_query);
                end
                
                % Convert data types for database compatibility
                survey_data = narwc.io.DataTypeConverter().prepareForUpload(survey_data);
                
                % Upload new data
                obj.connection.insert('Master', survey_data);
                
                if exists
                    obj.logger.info(sprintf('✓ Updated %s', survey_id));
                    obj.stats.updated = obj.stats.updated + 1;
                else
                    obj.logger.info(sprintf('✓ Uploaded %s', survey_id));
                    obj.stats.uploaded = obj.stats.uploaded + 1;
                end
                
                success = true;
                category = 'processed';
                
            catch ME
                obj.logger.error(sprintf('✗ Failed to upload %s: %s', ...
                    survey_id, ME.message));
                
                obj.logError(survey_id, ME, 'Database upload error');
                
                obj.stats.failed = obj.stats.failed + 1;
                success = false;
                category = 'failed';
            end
        end
        
        function logError(obj, survey_id, exception, error_type, extra_info)
            % LOGERROR Log an error to the error log file
            %
            % Inputs:
            %   survey_id - Survey identifier or filename
            %   exception - MException object or struct with message/identifier
            %   error_type - Description of error type
            %   extra_info - (optional) Additional information to log
            
            if nargin < 4
                error_type = 'Unknown error';
            end
            
            try
                fid = fopen(obj.error_log_file, 'a');
                if fid == -1
                    return;  % Silently fail if can't open log
                end
                
                % Write error header
                fprintf(fid, '\n[%s] %s\n', char(datetime('now')), survey_id);
                fprintf(fid, 'Type: %s\n', error_type);
                
                % Write error details
                if isstruct(exception)
                    fprintf(fid, 'Error: %s\n', exception.message);
                    if isfield(exception, 'identifier')
                        fprintf(fid, 'ID: %s\n', exception.identifier);
                    end
                    if isfield(exception, 'stack') && ~isempty(exception.stack)
                        fprintf(fid, 'Location: %s (line %d)\n', ...
                            exception.stack(1).name, exception.stack(1).line);
                    end
                else
                    fprintf(fid, 'Error: %s\n', exception.message);
                    fprintf(fid, 'ID: %s\n', exception.identifier);
                    if ~isempty(exception.stack)
                        fprintf(fid, 'Location: %s (line %d)\n', ...
                            exception.stack(1).name, exception.stack(1).line);
                    end
                end
                
                % Write extra info if provided (e.g., validation results)
                if nargin >= 5 && ~isempty(extra_info)
                    if isstruct(extra_info) && isfield(extra_info, 'summary')
                        fprintf(fid, 'Validation Details:\n');
                        fprintf(fid, '  Errors: %d\n', extra_info.summary.errors);
                        fprintf(fid, '  Warnings: %d\n', extra_info.summary.warnings);
                        
                        if isfield(extra_info, 'error_details') && ~isempty(extra_info.error_details)
                            fprintf(fid, '  Details:\n');
                            for i = 1:length(extra_info.error_details)
                                fprintf(fid, '    - %s\n', extra_info.error_details{i});
                            end
                        end
                    end
                end
                
                fprintf(fid, '%s\n', repmat('-', 1, 80));
                fclose(fid);
                
            catch logErr
                obj.logger.warning(sprintf('Failed to write to error log: %s', logErr.message));
            end
        end
        
        function writeErrorSummary(obj)
            % WRITEERRORSUMMARY Write summary section to error log
            
            try
                fid = fopen(obj.error_log_file, 'a');
                if fid == -1
                    return;
                end
                
                fprintf(fid, '\n\n%s\n', repmat('=', 1, 80));
                fprintf(fid, 'MIGRATION SUMMARY\n');
                fprintf(fid, '%s\n', repmat('=', 1, 80));
                fprintf(fid, 'Completed: %s\n\n', char(datetime('now')));
                
                fprintf(fid, 'Results:\n');
                fprintf(fid, '  Uploaded:  %d\n', obj.stats.uploaded);
                fprintf(fid, '  Updated:   %d\n', obj.stats.updated);
                fprintf(fid, '  Skipped:   %d\n', obj.stats.skipped);
                fprintf(fid, '  Failed:    %d\n', obj.stats.failed);
                
                total_processed = obj.stats.uploaded + obj.stats.updated;
                total_attempted = total_processed + obj.stats.failed;
                
                fprintf(fid, '\nStatistics:\n');
                fprintf(fid, '  Total Attempted: %d\n', total_attempted);
                fprintf(fid, '  Total Processed: %d\n', total_processed);
                
                if total_attempted > 0
                    success_rate = (total_processed / total_attempted) * 100;
                    fprintf(fid, '  Success Rate: %.2f%%\n', success_rate);
                end
                
                fprintf(fid, '\n%s\n', repmat('=', 1, 80));
                
                fclose(fid);
                
                obj.logger.info(sprintf('Error log summary written to: %s', obj.error_log_file));
                
            catch
                % Silently fail
            end
        end
        
        function moveFile(obj, source_path, category)
            % MOVEFILE Move file to appropriate category folder
            
            [~, filename, ext] = fileparts(source_path);
            dest_dir = fullfile(obj.base_dir, category);
            dest_path = fullfile(dest_dir, [filename ext]);
            
            try
                movefile(source_path, dest_path);
                obj.logger.debug(sprintf('Moved to %s/', category));
            catch ME
                obj.logger.warning(sprintf('Failed to move file: %s', ME.message));
            end
        end
        
        function exists = surveyExists(obj, survey_id)
            % SURVEYEXISTS Check if survey exists in database
            
            query = sprintf("SELECT COUNT(*) as cnt FROM Master WHERE FILEID = '%s'", ...
                survey_id);
            result = obj.connection.fetch(query);
            exists = result.cnt > 0;
        end
        
        function resetStats(obj)
            % RESETSTATS Reset statistics
            
            obj.stats = struct();
            obj.stats.uploaded = 0;
            obj.stats.updated = 0;
            obj.stats.skipped = 0;
            obj.stats.failed = 0;
        end
        
        function displayStats(obj)
            % DISPLAYSTATS Display upload statistics
            
            fprintf('\n=== Upload Summary ===\n');
            fprintf('Uploaded: %d\n', obj.stats.uploaded);
            fprintf('Updated:  %d\n', obj.stats.updated);
            fprintf('Skipped:  %d\n', obj.stats.skipped);
            fprintf('Failed:   %d\n', obj.stats.failed);
            fprintf('Total:    %d\n', obj.stats.uploaded + obj.stats.updated + ...
                obj.stats.skipped + obj.stats.failed);
            
            if obj.stats.failed > 0
                fprintf('\nError details logged to: %s\n', obj.error_log_file);
            end
            
            fprintf('\n');
        end
        
        function stats = getStats(obj)
            % GETSTATS Get upload statistics
            stats = obj.stats;
        end
    end
end