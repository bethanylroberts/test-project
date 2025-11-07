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
        
        function uploadFromFolder(obj, options)
            % UPLOADFROMFOLDER Upload all surveys from pending folder
            %
            % Inputs:
            %   options - Name-value pairs:
            %       'Overwrite' - Overwrite existing data (default: false)
            %       'Validate' - Validate before upload (default: true)
            %       'StopOnError' - Stop on first error (default: false)
            
            arguments
                obj
                options.Overwrite logical = false
                options.Validate logical = true
                options.StopOnError logical = false
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
                        'Validate', options.Validate);
                    
                    % Move file to appropriate folder
                    obj.moveFile(file_path, category);
                    
                catch ME
                    obj.logger.error(sprintf('Error processing %s: %s', ...
                        files(i).name, ME.message));
                    obj.stats.failed = obj.stats.failed + 1;
                    obj.moveFile(file_path, 'failed');
                    
                    if options.StopOnError
                        obj.logger.error('Stopping due to error');
                        break;
                    end
                end
            end
            
            obj.displayStats();
        end
        
        function [success, category] = uploadSurvey(obj, survey_data, options)
            % UPLOADSURVEY Upload a single survey
            %
            % Outputs:
            %   success - True if uploaded successfully
            %   category - 'processed', 'skipped', or 'failed'
            
            arguments
                obj
                survey_data table
                options.Overwrite logical = false
                options.Validate logical = true
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
                validator = narwc.validation.SurveyValidator();
                [is_valid, results] = validator.validate(survey_data);
                
                if ~is_valid
                    obj.logger.warning(sprintf('%s has %d validation errors', ...
                        survey_id, results.summary.errors));
                    
                    if results.summary.errors > 0
                        obj.logger.error('Validation failed with errors');
                        obj.stats.failed = obj.stats.failed + 1;
                        success = false;
                        category = 'failed';
                        return;
                    end
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
                obj.stats.failed = obj.stats.failed + 1;
                success = false;
                category = 'failed';
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
            fprintf('\n');
        end
        
        function stats = getStats(obj)
            % GETSTATS Get upload statistics
            stats = obj.stats;
        end
    end
end