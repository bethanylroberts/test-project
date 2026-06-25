classdef BatchUploader < handle
    % BATCHUPLOADER Batch upload surveys to database with file management
    %
    % Usage:
    %   uploader = narwc.ingestion.BatchUploader(conn, base_dir);
    %   uploader.uploadFromFolder();
    %
    %   % Legacy migration mode (allows negative visibility etc.):
    %   uploader = narwc.ingestion.BatchUploader(conn, base_dir, 'LegacyMode', true);
    %
    %   % Custom target table:
    %   uploader = narwc.ingestion.BatchUploader(conn, base_dir, 'TableName', 'StagingMaster');
    %
    % 2026 russ.shomberg@marineacoustics.com

    properties (Access = private)
        connection      % connection to database
        logger          % from custom logging toolbox
        stats           % upload statistics
        base_dir        % location of standard folder structure
        error_log_file  % error log (append mode across runs)
        run_summary_file % per-survey run summary CSV
        table_name      % target database table (default: 'Master')
        legacy_mode     % when true, applies legacy-leniency validation settings
    end

    methods
        function obj = BatchUploader(connection, base_dir, options)
            % BATCHUPLOADER Constructor
            %
            % Required fields list comes from get_config('validation').required_fields.
            % required_fields.m has its own default_config() with a different list
            % flagged as "not accurate" — that default is unused when called from here.

            arguments
                connection
                base_dir char = 'data/legacy/surveys'
                options.TableName char = 'Master'
                options.LegacyMode logical = false
            end

            obj.connection  = connection;
            obj.logger      = logging.Logger('narwc.ingestion.BatchUploader');
            obj.base_dir    = base_dir;
            obj.table_name  = options.TableName;
            obj.legacy_mode = options.LegacyMode;

            obj.resetStats();
            obj.ensureDirectories();
        end

        function ensureDirectories(obj)
            % ENSURE DIRECTORIES Create necessary directories

            % FIXME: pending has to exist or we do not know where the files are
            dirs = {'pending', 'processed', 'failed', 'skipped'};
            for i = 1:length(dirs)
                dir_path = fullfile(obj.base_dir, dirs{i});
                if ~exist(dir_path, 'dir')
                    mkdir(dir_path);
                end
            end
        end

        function initializeErrorLog(obj, allow_warnings, allow_errors)
            % INITIALIZEERRORLOG Open error log in append mode and write run header

            if nargin < 2
                allow_warnings = false;
            end
            if nargin < 3
                allow_errors = false;
            end

            failed_dir = fullfile(obj.base_dir, 'failed');
            obj.error_log_file  = fullfile(failed_dir, '_errors.log');
            obj.run_summary_file = fullfile(failed_dir, '_run_summary.csv');

            % Append to the existing log so history accumulates across runs
            fid = fopen(obj.error_log_file, 'a');
            if fid == -1
                obj.logger.warning('Could not open error log file');
                return;
            end

            % TODO: move log file handling into the logging toolbox
            fprintf(fid, '\n%s\n', repmat('=', 1, 80));
            fprintf(fid, 'RUN STARTED: %s\n', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss')));
            fprintf(fid, 'Base Directory: %s\n', obj.base_dir);
            fprintf(fid, 'Table: %s\n', obj.table_name);
            fprintf(fid, 'LegacyMode: %s | AllowWarnings: %s | AllowErrors: %s\n', ...
                mat2str(obj.legacy_mode), mat2str(allow_warnings), mat2str(allow_errors));
            fprintf(fid, '%s\n\n', repmat('-', 1, 80));
            fclose(fid);

            obj.initializeRunSummary();

            obj.logger.debug(sprintf('Error log opened (append): %s', obj.error_log_file));
        end

        function initializeRunSummary(obj)
            % INITIALIZERUNSUMMARY Write header to run summary CSV if it does not exist

            if ~exist(obj.run_summary_file, 'file')
                fid = fopen(obj.run_summary_file, 'a');
                if fid ~= -1
                    fprintf(fid, 'run_timestamp,fileid,status,error_count,warning_count_new,warning_count_acknowledged,notes\n');
                    fclose(fid);
                end
            end
        end

        function appendRunSummaryRow(obj, fileid, status, error_count, warn_new, warn_ack, notes)
            % APPENDRUNSUMMARYROW Append one survey result to _run_summary.csv

            if isempty(obj.run_summary_file)
                return;
            end
            try
                fid = fopen(obj.run_summary_file, 'a');
                if fid == -1
                    return;
                end
                ts = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
                notes_safe = strrep(notes, ',', ';');
                fprintf(fid, '%s,%s,%s,%d,%d,%d,%s\n', ...
                    ts, fileid, status, error_count, warn_new, warn_ack, notes_safe);
                fclose(fid);
            catch
            end
        end

        function uploadFromFolder(obj, options)
            % UPLOADFROMFOLDER Upload all surveys from pending folder
            %
            % This is the main logic function for this class. It validates and
            % then updates each survey in a folder
            %
            % Inputs: options - Name-value pairs: 'Overwrite' - Overwrite
            %   existing data (default: false) 'Validate' - Validate before
            %       upload (default: true) 'StopOnError' - Stop on first error
            %       (default: false) 'AllowWarnings' - Upload despite warnings
            %       (default: false) 'AllowErrors' - Upload despite errors
            %       (default: false)

            % NOTE: this is primarily a loop that runs obj.uploadSurvey with this same options

            arguments
                obj
                options.Overwrite logical = false
                options.Validate logical = true
                options.StopOnError logical = false
                options.AllowWarnings logical = false
                options.AllowErrors logical = false
            end

            pending_dir = fullfile(obj.base_dir, 'pending');
            pending_survey_files = dir(fullfile(pending_dir, '*.csv'));

            % Remove summary file if present
            % NOTE: this should not be an issue since it is a txt not a csv
            pending_survey_files = pending_survey_files(~strcmp({pending_survey_files.name}, '_split_summary.txt'));
            % TODO: add tracking for multiple runs

            obj.logger.info(sprintf('Found %d surveys to upload', length(pending_survey_files)));   % FIXME: remove sprintf if not necessary
            obj.resetStats();
            obj.initializeErrorLog(options.AllowWarnings, options.AllowErrors);

            for idx = 1:length(pending_survey_files)
                survey_file_path = fullfile(pending_survey_files(idx).folder, pending_survey_files(idx).name);

                fprintf('[%d/%d] Processing %s...\n', idx, length(pending_survey_files), pending_survey_files(idx).name);   % FIXME: use logger

                try
                    survey_data = readtable(survey_file_path);

                    % Early rejection of test fixtures before any processing
                    if ismember('FILEID', survey_data.Properties.VariableNames)
                        fid_val = survey_data.FILEID{1};
                        if numel(fid_val) >= 2 && fid_val(2) == 'T'
                            obj.logger.error(sprintf( ...
                                '%s: FILEID has position 2 = ''T'' (test fixture). Skipping.', ...
                                pending_survey_files(idx).name));
                            obj.stats.failed = obj.stats.failed + 1;
                            obj.moveFile(survey_file_path, 'failed');
                            continue;
                        end
                    end

                    [success, category] = obj.uploadSurvey(survey_data, ...
                        'Overwrite',        options.Overwrite, ...
                        'Validate',         options.Validate, ...
                        'AllowWarnings',    options.AllowWarnings, ...
                        'AllowErrors',      options.AllowErrors);

                    % Move file to appropriate folder
                    obj.moveFile(survey_file_path, category);

                catch ME
                    obj.logger.error(sprintf('Error processing %s: %s', ...
                        pending_survey_files(idx).name, ME.message));

                    obj.logError(pending_survey_files(idx).name, ME, 'File processing error');

                    obj.stats.failed = obj.stats.failed + 1;
                    obj.moveFile(survey_file_path, 'failed');

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
            %
            % This includes the validation steps, which generate errors and
            % warnings to determine if the survey should be uploaded

            % FIXME: obj.uploadSurvey should be a generic function in the `narwc` toolbox

            arguments
                obj
                survey_data     table
                options.Overwrite       logical = false
                options.Validate        logical = true
                options.AllowWarnings   logical = false
                options.AllowErrors     logical = false
            end

            % TODO: check is_standard_format else break

            % Get survey ID
            if ismember('FILEID', survey_data.Properties.VariableNames)
                survey_id = survey_data.FILEID{1};
            else
                error('No FILEID found in survey data');
                % NOTE: only possible if the survey is the wrong format
            end

            % Reject test fixtures — FILEID position 2 = 'T' is reserved for
            % anonymized test data and must never reach the production database.
            if numel(survey_id) >= 2 && survey_id(2) == 'T'
                obj.logger.error(sprintf( ...
                    '%s: FILEID has position 2 = ''T'' (test fixture marker). Refusing upload.', ...
                    survey_id));
                obj.stats.failed = obj.stats.failed + 1;
                success = false;
                category = 'failed';
                return;
            end

            % Validate if requested
            if options.Validate % FIXME: refactor to avoid nesting

                obj.logger.info(sprintf('Validating survey: %s (%d records)', ...
                                survey_id, height(survey_data)));

                % Create validator config with override options
                validator_config = struct();
                validator_config.allow_warnings = options.AllowWarnings;
                validator_config.allow_errors = options.AllowErrors;

                % LegacyMode controls leniency flags that differ between legacy
                % migration and modern strict ingestion.
                validator_config.environmental = struct();
                validator_config.environmental.visibility_allow_negative = obj.legacy_mode;

                validator = narwc.validation.SurveyValidator(validator_config);
                [is_valid, results] = validator.validate(survey_data);

                warn_new = 0;
                warn_ack = 0;
                if isfield(results, 'summary')
                    if isfield(results.summary, 'warnings_new')
                        warn_new = results.summary.warnings_new;
                    end
                    if isfield(results.summary, 'warnings_acknowledged')
                        warn_ack = results.summary.warnings_acknowledged;
                    end
                end
                obj.stats.warnings_new          = obj.stats.warnings_new + warn_new;
                obj.stats.warnings_acknowledged = obj.stats.warnings_acknowledged + warn_ack;

                if ~is_valid
                    has_errors   = results.summary.errors > 0;
                    has_warnings = warn_new > 0;

                    % Log what's blocking
                    if has_errors && ~options.AllowErrors
                        obj.logger.error(sprintf('%s has %d validation errors', ...
                            survey_id, results.summary.errors));
                    end
                    if has_warnings && ~options.AllowWarnings
                        obj.logger.warning(sprintf('%s has %d new validation warnings', ...
                            survey_id, warn_new));
                    end

                    % Log validation details
                    validation_err = struct();
                    validation_err.message = sprintf( ...
                        'Validation failed: %d errors, %d warnings (%d acknowledged, %d new)', ...
                        results.summary.errors, warn_ack + warn_new, warn_ack, warn_new);
                    validation_err.identifier = 'Ingestion:ValidationFailed';
                    validation_err.stack = dbstack();
                    obj.logError(survey_id, validation_err, 'Validation error', results);

                    notes = sprintf('errors=%d warn_new=%d warn_ack=%d', ...
                        results.summary.errors, warn_new, warn_ack);
                    obj.appendRunSummaryRow(survey_id, 'rejected', ...
                        results.summary.errors, warn_new, warn_ack, notes);

                    obj.stats.failed = obj.stats.failed + 1;
                    success = false;
                    category = 'failed';
                    return;
                end
            end

            obj.logger.info(sprintf('Uploading survey: %s (%d records)', ...    % TODO: remove sprintf if not needed
                survey_id, height(survey_data)));

            % Check if exists
            exists = obj.surveyExists(survey_id);

            if exists && ~options.Overwrite
                obj.logger.info(sprintf('%s already exists in database, skipping', survey_id));     % TODO: remove sprintf if not needed
                obj.stats.skipped = obj.stats.skipped + 1;
                obj.appendRunSummaryRow(survey_id, 'skipped', 0, 0, 0, 'already exists');
                success = true;
                category = 'skipped';
                return;
            end

            % Save AutoCommit state so the connection can be safely reused
            % after this operation, regardless of outcome.
            prev_auto_commit = obj.connection.getAutoCommit();

            % Attempt to begin a transaction.  If the driver does not support
            % transactions, log a warning and fall back to the old non-atomic
            % behaviour so the operation can still proceed.
            txn_ok = false;
            try
                obj.connection.beginTransaction();
                txn_ok = true;
            catch txn_err
                obj.logger.warning(sprintf( ...
                    '%s: driver does not support transactions, proceeding non-atomically: %s', ...
                    survey_id, txn_err.message));
            end

            try
                % Delete existing rows before inserting new ones (overwrite path).
                if exists
                    obj.logger.info(sprintf('Deleting existing records for %s', survey_id));
                    delete_query = sprintf("DELETE FROM %s WHERE FILEID = '%s'", obj.table_name, survey_id);
                    obj.connection.execute(delete_query);
                end

                % Convert data types for database compatibility
                survey_data = narwc.io.DataTypeConverter().prepareForUpload(survey_data);

                % Upload new data
                obj.connection.insert(obj.table_name, survey_data);

                if txn_ok
                    obj.connection.commit();
                end

                if exists
                    obj.logger.info(sprintf('Updated %s', survey_id));
                    obj.stats.updated = obj.stats.updated + 1;
                    obj.appendRunSummaryRow(survey_id, 'uploaded', 0, 0, 0, 'overwrite');
                else
                    obj.logger.info(sprintf('Uploaded %s', survey_id));
                    obj.stats.uploaded = obj.stats.uploaded + 1;
                    obj.appendRunSummaryRow(survey_id, 'uploaded', 0, 0, 0, '');
                end

                success = true;
                category = 'processed';

            catch ME
                if txn_ok
                    try
                        obj.connection.rollback();
                    catch
                    end
                    stage = 'insert';
                    if exists
                        stage = 'delete/insert';
                    end
                    obj.logger.error(sprintf( ...
                        '%s: upload failed at %s stage — prior data preserved via rollback: %s', ...
                        survey_id, stage, ME.message));
                    obj.logError(survey_id, ME, ...
                        'Database upload error (rolled back; prior data preserved)');
                else
                    obj.logger.error(sprintf('Failed to upload %s: %s', ...
                        survey_id, ME.message));
                    obj.logError(survey_id, ME, ...
                        'Database upload error (non-atomic; data may be partial)');
                end

                obj.stats.failed = obj.stats.failed + 1;
                success = false;
                category = 'failed';
            end

            % Restore AutoCommit state whether the operation succeeded or failed.
            if txn_ok
                obj.connection.setAutoCommit(prev_auto_commit);
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

            % FIXME: can we include some of this in the logging toolbox

            if nargin < 4
                % ???: when would this occur? Can I delete it?
                error_type = 'Unknown error';
            end

            try
                fid = fopen(obj.error_log_file, 'a');
                if fid == -1
                    % ???: is this the behavior I want
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
                        % TODO: replace line with eventno? or add
                    end
                else
                    fprintf(fid, 'Error: %s\n', exception.message);
                    fprintf(fid, 'ID: %s\n', exception.identifier);
                    if ~isempty(exception.stack)
                        fprintf(fid, 'Location: %s (line %d)\n', ...
                            exception.stack(1).name, exception.stack(1).line);
                        % TODO: replace line with eventno? or add
                    end
                end

                % Write extra info if provided (e.g., validation results)
                if nargin >= 5 && ~isempty(extra_info)
                    % ???: does this functionality ever get used?
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
                fprintf(fid, 'UPLOAD SUMMARY\n');
                fprintf(fid, '%s\n', repmat('=', 1, 80));
                fprintf(fid, 'Completed: %s\n\n', char(datetime('now')));

                fprintf(fid, 'Results:\n');
                fprintf(fid, '  Uploaded:  %d\n', obj.stats.uploaded);
                fprintf(fid, '  Updated:   %d\n', obj.stats.updated);
                fprintf(fid, '  Skipped:   %d\n', obj.stats.skipped);
                fprintf(fid, '  Failed:    %d\n', obj.stats.failed);

                total_processed = obj.stats.uploaded + obj.stats.updated;
                total_attempted = total_processed + obj.stats.failed;

                fprintf(fid, '\nWarnings:\n');
                fprintf(fid, '  Acknowledged: %d\n', obj.stats.warnings_acknowledged);
                fprintf(fid, '  New (blocking): %d\n', obj.stats.warnings_new);

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
                % ???: is this the behavior I want?
            end
        end

        function moveFile(obj, source_path, category)
            % MOVE FILE Move file to appropriate category folder

            % FIXME: this method name is not very good, or does not need to be a method

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

            query = sprintf("SELECT COUNT(*) as cnt FROM %s WHERE FILEID = '%s'", ...
                obj.table_name, survey_id);
            result = obj.connection.fetch(query);
            % TODO: add functionality to return results as well for if we need to overwrite
            exists = result.cnt > 0;
        end

        function resetStats(obj)
            % RESETSTATS Reset statistics

            obj.stats = struct();
            obj.stats.uploaded             = 0;
            obj.stats.updated              = 0;
            obj.stats.skipped              = 0;
            obj.stats.failed               = 0;
            obj.stats.warnings_new         = 0;
            obj.stats.warnings_acknowledged = 0;
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
