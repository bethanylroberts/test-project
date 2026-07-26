classdef BatchUploader < handle
    % BATCHUPLOADER Batch upload surveys to database with file management
    %
    % Usage:
    %   uploader = narwc.ingestion.BatchUploader(conn, base_dir);
    %   uploader.uploadFromFolder();
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
        error_log_file  % error log (one file per run when datetime stamping is on)
        run_summary_file % per-survey run summary CSV
        table_name      % target database table (default: 'Master')
        batch_config    % full config struct from load_config(), or struct() if not provided
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
                base_dir char = 'data/surveys'
                options.TableName char = 'Master'
                options.Config struct = struct()
            end

            obj.connection   = connection;
            obj.logger       = logging.Logger('narwc.ingestion.BatchUploader');
            obj.base_dir     = base_dir;
            obj.table_name   = options.TableName;
            obj.batch_config = options.Config;

            obj.resetStats();
            obj.ensureDirectories();
        end

        function ensureDirectories(obj)
            % ENSURE DIRECTORIES Create necessary directories

            % FIXME: pending has to exist or we do not know where the files are
            dirs = {'pending', 'processed', 'rejected', 'skipped'};
            for i = 1:length(dirs)
                dir_path = fullfile(obj.base_dir, dirs{i});
                if ~exist(dir_path, 'dir')
                    mkdir(dir_path);
                end
            end
        end

        function initializeErrorLog(obj, allow_warnings, allow_errors, run_ts)
            % INITIALIZEERRORLOG Open error log and write run header.
            %
            % When config.pipeline.logging.use_datetime_filenames is true (the
            % default), each run gets its own timestamped log file.  Otherwise
            % a fixed filename is used and runs accumulate in the same file.

            if nargin < 2
                allow_warnings = false;
            end
            if nargin < 3
                allow_errors = false;
            end
            if nargin < 4
                run_ts = '';
            end

            log_dir = fileparts(obj.base_dir);

            use_datetime = true;
            if isfield(obj.batch_config, 'pipeline') && ...
                    isfield(obj.batch_config.pipeline, 'logging') && ...
                    isfield(obj.batch_config.pipeline.logging, 'use_datetime_filenames')
                use_datetime = obj.batch_config.pipeline.logging.use_datetime_filenames;
            end

            if use_datetime
                if isempty(run_ts)
                    run_ts = narwc.logging.run_timestamp();
                end
                obj.error_log_file   = fullfile(log_dir, sprintf('_errors_%s.log', run_ts));
                obj.run_summary_file = fullfile(log_dir, sprintf('_run_summary_%s.csv', run_ts));
            else
                obj.error_log_file   = fullfile(log_dir, '_errors.log');
                obj.run_summary_file = fullfile(log_dir, '_run_summary.csv');
            end

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
            fprintf(fid, 'AllowWarnings: %s | AllowErrors: %s\n', ...
                mat2str(allow_warnings), mat2str(allow_errors));
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
                    fprintf(fid, ['run_timestamp,fileid,status,error_count,' ...
                        'warning_count_new,warning_count_acknowledged,' ...
                        'warning_count_acknowledged_per_row,' ...
                        'warning_count_acknowledged_per_survey,notes\n']);
                    fclose(fid);
                end
            end
        end

        function appendRunSummaryRow(obj, fileid, status, error_count, warn_new, warn_ack, warn_ack_per_row, warn_ack_per_survey, notes)
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
                fprintf(fid, '%s,%s,%s,%d,%d,%d,%d,%d,%s\n', ...
                    ts, fileid, status, error_count, warn_new, warn_ack, ...
                    warn_ack_per_row, warn_ack_per_survey, notes_safe);
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
            %       (default: false) 'BatchId' - Only upload FILEIDs
            %       belonging to this batch (looked up in the batch ledger,
            %       see narwc.ingestion.append_batch_log), instead of
            %       everything currently in pending/ (default: '', meaning
            %       no filtering) 'SplitSummaryFile' - Same effect as
            %       BatchId, but names the split-summary log directly
            %       instead of looking it up via the ledger (default: '')

            % NOTE: this is primarily a loop that runs obj.uploadSurvey with this same options

            arguments
                obj
                options.Overwrite logical = false
                options.Validate logical = true
                options.StopOnError logical = false
                options.AllowWarnings logical = false
                options.AllowErrors logical = false
                options.BatchId char = ''
                options.SplitSummaryFile char = ''
            end

            pending_dir = fullfile(obj.base_dir, 'pending');
            pending_survey_files = dir(fullfile(pending_dir, '*.csv'));

            % Remove summary file if present
            % NOTE: this should not be an issue since it is a txt not a csv
            pending_survey_files = pending_survey_files(~strcmp({pending_survey_files.name}, '_split_summary.txt'));

            if ~isempty(options.BatchId) || ~isempty(options.SplitSummaryFile)
                pending_survey_files = obj.filterToBatch(pending_survey_files, ...
                    options.BatchId, options.SplitSummaryFile);
            end

            obj.logger.info(sprintf('Found %d surveys to upload', length(pending_survey_files)));   % FIXME: remove sprintf if not necessary
            obj.resetStats();
            run_ts = narwc.logging.run_timestamp();
            obj.initializeErrorLog(options.AllowWarnings, options.AllowErrors, run_ts);

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
                            obj.stats.rejected = obj.stats.rejected + 1;
                            obj.moveFile(survey_file_path, 'rejected');
                            continue;
                        end
                    end

                    % Apply known Category C corrections before validation.
                    % Gated by config.pipeline.known_fixes.enabled (default: true).
                    % A log line fires only when at least one row was actually changed.
                    apply_fixes = true;
                    if isfield(obj.batch_config, 'pipeline') && ...
                            isfield(obj.batch_config.pipeline, 'known_fixes') && ...
                            isfield(obj.batch_config.pipeline.known_fixes, 'enabled')
                        apply_fixes = obj.batch_config.pipeline.known_fixes.enabled;
                    end

                    if apply_fixes
                        if ismember('FILEID', survey_data.Properties.VariableNames)
                            fix_fileid = survey_data.FILEID{1};
                        else
                            fix_fileid = '';
                        end
                        [survey_data, fix_report] = migration.apply_known_fixes(survey_data, fix_fileid);
                        if any(structfun(@(x) x > 0, fix_report))
                            obj.logger.info(sprintf('Known fixes applied to %s: %s', ...
                                fix_fileid, format_fix_summary(fix_report)));
                        end
                        obj.accumulateFixReport(fix_report);
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

                    obj.stats.rejected = obj.stats.rejected + 1;
                    obj.moveFile(survey_file_path, 'rejected');

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
                obj.stats.rejected = obj.stats.rejected + 1;
                success = false;
                category = 'rejected';
                return;
            end

            % Validate if requested
            if options.Validate % FIXME: refactor to avoid nesting

                obj.logger.info(sprintf('Validating survey: %s (%d records)', ...
                                survey_id, height(survey_data)));

                % Build validator config from batch validation settings + run-specific flags
                if isfield(obj.batch_config, 'validation')
                    validator_config = obj.batch_config.validation;
                else
                    validator_config = struct();
                end
                validator_config.allow_warnings = options.AllowWarnings;
                validator_config.allow_errors   = options.AllowErrors;
                % SurveyValidator uses flat override_file field, not overrides.csv_path
                if isfield(validator_config, 'overrides') && ...
                        isfield(validator_config.overrides, 'csv_path')
                    validator_config.override_file = validator_config.overrides.csv_path;
                end

                validator = narwc.validation.SurveyValidator(validator_config);
                [is_valid, results] = validator.validate(survey_data);

                warn_new            = 0;
                warn_ack            = 0;
                warn_ack_per_row    = 0;
                warn_ack_per_survey = 0;
                if isfield(results, 'summary')
                    if isfield(results.summary, 'warnings_new')
                        warn_new = results.summary.warnings_new;
                    end
                    if isfield(results.summary, 'warnings_acknowledged')
                        warn_ack = results.summary.warnings_acknowledged;
                    end
                    if isfield(results.summary, 'warnings_acknowledged_per_row')
                        warn_ack_per_row = results.summary.warnings_acknowledged_per_row;
                    end
                    if isfield(results.summary, 'warnings_acknowledged_per_survey')
                        warn_ack_per_survey = results.summary.warnings_acknowledged_per_survey;
                    end
                    if isfield(results.summary, 'acknowledgement_by_rule')
                        obj.accumulateRuleStats(results.summary.acknowledgement_by_rule);
                    end
                end
                obj.stats.warnings_new                     = obj.stats.warnings_new + warn_new;
                obj.stats.warnings_acknowledged            = obj.stats.warnings_acknowledged + warn_ack;
                obj.stats.warnings_acknowledged_per_row    = obj.stats.warnings_acknowledged_per_row + warn_ack_per_row;
                obj.stats.warnings_acknowledged_per_survey = obj.stats.warnings_acknowledged_per_survey + warn_ack_per_survey;

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

                    notes = sprintf('errors=%d warn_new=%d warn_ack=%d (row=%d survey=%d)', ...
                        results.summary.errors, warn_new, warn_ack, warn_ack_per_row, warn_ack_per_survey);
                    obj.appendRunSummaryRow(survey_id, 'rejected', ...
                        results.summary.errors, warn_new, warn_ack, warn_ack_per_row, warn_ack_per_survey, notes);

                    obj.stats.rejected = obj.stats.rejected + 1;
                    success = false;
                    category = 'rejected';
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
                obj.appendRunSummaryRow(survey_id, 'skipped', 0, 0, 0, 0, 0, 'already exists');
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
                    obj.appendRunSummaryRow(survey_id, 'uploaded', 0, 0, 0, 0, 0, 'overwrite');
                else
                    obj.logger.info(sprintf('Uploaded %s', survey_id));
                    obj.stats.uploaded = obj.stats.uploaded + 1;
                    obj.appendRunSummaryRow(survey_id, 'uploaded', 0, 0, 0, 0, 0, '');
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

                obj.stats.rejected = obj.stats.rejected + 1;
                success = false;
                category = 'rejected';
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
                fprintf(fid, '  Rejected:  %d\n', obj.stats.rejected);

                total_processed = obj.stats.uploaded + obj.stats.updated;
                total_attempted = total_processed + obj.stats.rejected;

                fprintf(fid, '\nWarnings:\n');
                fprintf(fid, '  Acknowledged: %d (%d per-row, %d per-survey)\n', ...
                    obj.stats.warnings_acknowledged, ...
                    obj.stats.warnings_acknowledged_per_row, ...
                    obj.stats.warnings_acknowledged_per_survey);
                fprintf(fid, '  New (blocking): %d\n', obj.stats.warnings_new);

                if ~isempty(fieldnames(obj.stats.acknowledgement_by_rule))
                    fprintf(fid, '\nAcknowledged warnings by rule:\n');
                    rule_keys = fieldnames(obj.stats.acknowledgement_by_rule);
                    for i = 1:length(rule_keys)
                        r     = obj.stats.acknowledgement_by_rule.(rule_keys{i});
                        total = r.per_row + r.per_survey;
                        fprintf(fid, '  %s: %d (%d per-row, %d per-survey)\n', ...
                            r.rule_id, total, r.per_row, r.per_survey);
                    end
                end

                fprintf(fid, '\nStatistics:\n');
                fprintf(fid, '  Total Attempted: %d\n', total_attempted);
                fprintf(fid, '  Total Processed: %d\n', total_processed);

                if total_attempted > 0
                    success_rate = (total_processed / total_attempted) * 100;
                    fprintf(fid, '  Success Rate: %.2f%%\n', success_rate);
                end

                fprintf(fid, '\n%s\n', repmat('=', 1, 80));

                % Known Fixes Applied section
                ft = obj.stats.fix_totals;
                fs = obj.stats.fix_survey_counts;
                fprintf(fid, '\n=== Known Fixes Applied ===\n');
                fprintf(fid, '%s\n', fix_summary_line('PHOTOS = 0 -> 1 (sighting rows)', ft.photos_0_to_1,   fs.photos_0_to_1));
                fprintf(fid, '%s\n', fix_summary_line('STRIP > 16 -> NULL (NEAq 2021)',  ft.strip_neaq_2021, fs.strip_neaq_2021));
                fprintf(fid, '%s\n', fix_summary_line('BEAUFORT = 99 -> NULL',           ft.beaufort_99,     fs.beaufort_99));
                fprintf(fid, '%s\n', fix_summary_line('CLOUD = 99 -> NULL',              ft.cloud_99,        fs.cloud_99));
                fprintf(fid, '%s\n', fix_summary_line('GLAREL = 99 -> NULL',             ft.glarel_99,       fs.glarel_99));
                fprintf(fid, '%s\n', fix_summary_line('GLARER = 99 -> NULL',             ft.glarer_99,       fs.glarer_99));
                fprintf(fid, '%s\n', fix_summary_line('NUMCALF = 99 -> NULL',            ft.numcalf_99,      fs.numcalf_99));
                fprintf(fid, '%s\n', fix_summary_line('SPECCODE trailing whitespace trim', ft.speccode_trim,  fs.speccode_trim));
                fprintf(fid, '%s\n', fix_summary_line('LEGTYPE = 99 -> NULL',            ft.legtype_99,      fs.legtype_99));
                fprintf(fid, '\n%s\n', repmat('=', 1, 80));

                fclose(fid);

                obj.logger.info(sprintf('Error log summary written to: %s', obj.error_log_file));

            catch
                % Silently fail
                % ???: is this the behavior I want?
            end
        end

        function filtered = filterToBatch(obj, pending_survey_files, batch_id, split_summary_file)
            % FILTERTOBATCH Narrow pending_survey_files down to one batch's FILEIDs.
            %
            % Resolves the batch's split-summary log (directly via
            % split_summary_file, or by looking up batch_id in the batch
            % ledger), then keeps only the files whose FILEID (the filename
            % stem) appears in that log's survey list. FILEID matching is
            % case-insensitive, matching load_split_summary's own
            % upper()-normalized counts map.

            if isempty(split_summary_file)
                ledger = narwc.ingestion.read_batch_log();
                is_match = strcmp(ledger.stage, 'convert') & strcmp(ledger.batch_id, batch_id);
                matches = ledger(is_match, :);
                if height(matches) == 0
                    error('narwc:ingestion:BatchUploader:UnknownBatchId', ...
                        'No convert entry found in the batch ledger for batch_id ''%s''.', batch_id);
                end
                split_summary_file = matches.output{end};
            end

            [batch_source, ~] = narwc.ingestion.load_split_summary(split_summary_file);
            batch_fileids = keys(batch_source.counts);

            names = {pending_survey_files.name};
            [~, stems] = cellfun(@fileparts, names, 'UniformOutput', false);
            keep = ismember(upper(stems), batch_fileids);
            filtered = pending_survey_files(keep);

            obj.logger.info(sprintf('Batch filter matched %d/%d files in pending/', ...
                nnz(keep), numel(names)));
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
            obj.stats.uploaded                        = 0;
            obj.stats.updated                         = 0;
            obj.stats.skipped                         = 0;
            obj.stats.rejected                        = 0;
            obj.stats.warnings_new                    = 0;
            obj.stats.warnings_acknowledged           = 0;
            obj.stats.warnings_acknowledged_per_row   = 0;
            obj.stats.warnings_acknowledged_per_survey = 0;
            obj.stats.acknowledgement_by_rule         = struct();

            % Per-fix row totals and survey counts for the Known Fixes section
            zero_fix = struct( ...
                'photos_0_to_1',   0, 'strip_neaq_2021', 0, ...
                'beaufort_99',     0, 'cloud_99',         0, ...
                'glarel_99',       0, 'glarer_99',        0, ...
                'numcalf_99',      0, 'speccode_trim',    0, ...
                'legtype_99',      0);
            obj.stats.fix_totals        = zero_fix;
            obj.stats.fix_survey_counts = zero_fix;
        end

        function accumulateRuleStats(obj, by_rule)
            % ACCUMULATERULESTATS Merge per-rule acknowledgement counts into run-level stats

            if isempty(by_rule) || isempty(fieldnames(by_rule))
                return;
            end
            keys = fieldnames(by_rule);
            for i = 1:length(keys)
                k     = keys{i};
                entry = by_rule.(k);
                if isfield(obj.stats.acknowledgement_by_rule, k)
                    obj.stats.acknowledgement_by_rule.(k).per_row = ...
                        obj.stats.acknowledgement_by_rule.(k).per_row + entry.per_row;
                    obj.stats.acknowledgement_by_rule.(k).per_survey = ...
                        obj.stats.acknowledgement_by_rule.(k).per_survey + entry.per_survey;
                else
                    obj.stats.acknowledgement_by_rule.(k) = entry;
                end
            end
        end

        function displayStats(obj)
            % DISPLAYSTATS Display upload statistics

            fprintf('\n=== Upload Summary ===\n');
            fprintf('Uploaded: %d\n', obj.stats.uploaded);
            fprintf('Updated:  %d\n', obj.stats.updated);
            fprintf('Skipped:  %d\n', obj.stats.skipped);
            fprintf('Rejected: %d\n', obj.stats.rejected);
            fprintf('Total:    %d\n', obj.stats.uploaded + obj.stats.updated + ...
                obj.stats.skipped + obj.stats.rejected);

            if obj.stats.rejected > 0
                fprintf('\nError details logged to: %s\n', obj.error_log_file);
            end

            fprintf('\n');
        end

        function stats = getStats(obj)
            % GETSTATS Get upload statistics
            stats = obj.stats;
        end

        function accumulateFixReport(obj, fix_report)
            % ACCUMULATEFIXREPORT Merge a per-survey fix report into run-level totals.
            keys = fieldnames(fix_report);
            for i = 1:numel(keys)
                k = keys{i};
                if isfield(obj.stats.fix_totals, k)
                    obj.stats.fix_totals.(k) = obj.stats.fix_totals.(k) + fix_report.(k);
                    if fix_report.(k) > 0
                        obj.stats.fix_survey_counts.(k) = obj.stats.fix_survey_counts.(k) + 1;
                    end
                end
            end
        end
    end
end


% =========================================================================
% File-level helpers (not class methods)
% =========================================================================

function s = format_fix_summary(report)
% Return a compact one-line description of which fixes fired and how many rows.
    parts = {};
    fields = fieldnames(report);
    labels = struct( ...
        'photos_0_to_1',   'PHOTOS 0->1', ...
        'strip_neaq_2021', 'STRIP>16', ...
        'beaufort_99',     'BEAUFORT 99', ...
        'cloud_99',        'CLOUD 99', ...
        'glarel_99',       'GLAREL 99', ...
        'glarer_99',       'GLARER 99', ...
        'numcalf_99',      'NUMCALF 99', ...
        'speccode_trim',   'SPECCODE trim', ...
        'legtype_99',      'LEGTYPE 99');
    for i = 1:numel(fields)
        k = fields{i};
        if report.(k) > 0 && isfield(labels, k)
            parts{end+1} = sprintf('%s=%d', labels.(k), report.(k)); %#ok<AGROW>
        end
    end
    if isempty(parts)
        s = 'none';
    else
        s = strjoin(parts, ', ');
    end
end

function s = fix_summary_line(label, total_rows, survey_count)
% Format one line of the Known Fixes Applied block in the error log.
    if total_rows == 0
        s = sprintf('%s: 0 rows', label);
    else
        s = sprintf('%s: %d rows across %d survey(s)', label, total_rows, survey_count);
    end
end
