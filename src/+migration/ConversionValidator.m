classdef ConversionValidator < handle
    % CONVERSION VALIDATOR Validate migration from CSV to database
    % 
    % This is for validating the legacy conversion after the migration has been
    % completed
    %
    % Usage: validator = migration.ConversionValidator(connection); results =
    %   validator.validate(csv_file);
    % 
    % 2026 russ.shomberg@marineacoustics.com

    % FIXME: DELETE I do not think this get used anywhere

    % TODO: check and refactor this code
    
    properties (Access = private)
        connection  % database connection
        logger      % logging toolbox logger
    end
    
    methods
        function obj = ConversionValidator(connection)
            % CONVERSIONVALIDATOR Constructor
            
            obj.connection = connection;
            obj.logger = logging.Logger('migration.ConversionValidator');
        end
        
        function results = validate(obj, survey_file, options)
            % VALIDATE Validate migration
            %
            % Inputs:
            %   csv_file - Path to original CSV file
            %   options - Name-value pairs:
            %       'SampleSize' - Number of surveys to validate (default: all)
            %       'CheckAllFields' - Check all fields or just key fields (default: false)
            %
            % Outputs:
            %   results - Struct with validation results
            
            arguments
                obj
                survey_file char
                options.SampleSize double = inf         % TODO: remove this option?
                options.CheckAllFields logical = false  % TODO: remove this option?
            end
            
            obj.logger.info('Starting migration validation...');
            
            results = struct();
            results.survey_file = survey_file;
            results.validation_time = datetime('now');
            results.issues = {};
            
            % Get survey list from database
            obj.logger.info('Querying database for survey list...');
            db_surveys = obj.connection.fetch('SELECT DISTINCT FILEID FROM Master ORDER BY FILEID');
            results.db_survey_count = height(db_surveys);
            obj.logger.info(sprintf('Found %d surveys in database', results.db_survey_count));
            
            % Get survey list from CSV
            % FIXME: get from folder?
            obj.logger.info('Reading CSV to get survey list...');
            extractor = migration.SurveyExtractor(survey_file);
            csv_data = obj.readCSVFull(extractor);
            csv_surveys = unique(csv_data.FILEID);
            csv_surveys = csv_surveys(~ismissing(csv_surveys) & strlength(csv_surveys) > 0);
            results.csv_survey_count = length(csv_surveys);
            obj.logger.info(sprintf('Found %d surveys in CSV', results.csv_survey_count));
            
            % Compare survey lists
            obj.logger.info('Comparing survey lists...');
            results.survey_comparison = obj.compareSurveyLists(csv_surveys, db_surveys.FILEID);
            
            % Count total records
            obj.logger.info('Counting total records...');
            results.csv_total_records = height(csv_data);
            db_count = obj.connection.fetch('SELECT COUNT(*) as cnt FROM Master');
            results.db_total_records = db_count.cnt;
            obj.logger.info(sprintf('CSV records: %d, DB records: %d', ...
                results.csv_total_records, results.db_total_records));
            
            if results.csv_total_records ~= results.db_total_records
                results.issues{end+1} = sprintf('Record count mismatch: CSV has %d, DB has %d', ...
                    results.csv_total_records, results.db_total_records);
            end
            
            % Sample surveys to validate
            if options.SampleSize < length(csv_surveys)
                obj.logger.info(sprintf('Sampling %d surveys for detailed validation', options.SampleSize));
                sample_idx = randperm(length(csv_surveys), options.SampleSize);
                surveys_to_check = csv_surveys(sample_idx);
            else
                surveys_to_check = csv_surveys;
            end
            
            % Validate each sampled survey
            obj.logger.info(sprintf('Validating %d surveys in detail...', length(surveys_to_check)));
            results.survey_validations = obj.validateSurveys(csv_data, surveys_to_check, options.CheckAllFields);
            
            % Summary
            results.is_valid = isempty(results.issues) && ...
                results.survey_comparison.missing_from_db == 0 && ...
                results.survey_comparison.extra_in_db == 0 && ...
                all([results.survey_validations.matches]);
            
            if results.is_valid
                obj.logger.info('✓ Migration validation PASSED');
            else
                obj.logger.warning('✗ Migration validation FAILED');
            end
            
            results.summary = obj.createSummary(results);
        end
        
        function comparison = compareSurveyLists(obj, csv_surveys, db_surveys)
            % COMPARESURVEYLIST Compare survey lists
            
            comparison = struct();
            
            % Convert to strings for comparison
            csv_surveys = string(csv_surveys);
            db_surveys = string(db_surveys);
            
            % Find missing surveys
            missing_from_db = setdiff(csv_surveys, db_surveys);
            extra_in_db = setdiff(db_surveys, csv_surveys);
            
            comparison.missing_from_db = length(missing_from_db);
            comparison.missing_from_db_list = missing_from_db;
            comparison.extra_in_db = length(extra_in_db);
            comparison.extra_in_db_list = extra_in_db;
            comparison.in_both = length(intersect(csv_surveys, db_surveys));
            
            if comparison.missing_from_db > 0
                obj.logger.warning(sprintf('%d surveys in CSV but not in DB', comparison.missing_from_db));
                obj.issues{end+1} = sprintf('%d surveys missing from database', comparison.missing_from_db);
            end
            
            if comparison.extra_in_db > 0
                obj.logger.warning(sprintf('%d surveys in DB but not in CSV', comparison.extra_in_db));
                obj.issues{end+1} = sprintf('%d extra surveys in database', comparison.extra_in_db);
            end
        end
        
        function validations = validateSurveys(obj, csv_data, survey_ids, check_all_fields)
            % VALIDATESURVEYS Validate individual surveys
            
            validations = struct('survey_id', {}, 'matches', {}, 'csv_rows', {}, ...
                'db_rows', {}, 'issues', {});
            
            for i = 1:length(survey_ids)
                survey_id = survey_ids{i};
                
                if mod(i, 10) == 0
                    obj.logger.info(sprintf('  Validating survey %d/%d (%s)', ...
                        i, length(survey_ids), survey_id));
                end
                
                validation = struct();
                validation.survey_id = survey_id;
                validation.issues = {};
                
                % Get CSV data
                csv_survey = csv_data(strcmp(csv_data.FILEID, survey_id), :);
                validation.csv_rows = height(csv_survey);
                
                % Get DB data
                query = sprintf("SELECT * FROM Master WHERE FILEID = '%s' ORDER BY EVENTNO", survey_id);
                db_survey = obj.connection.fetch(query);
                validation.db_rows = height(db_survey);
                
                % Compare row counts
                if validation.csv_rows ~= validation.db_rows
                    validation.issues{end+1} = sprintf('Row count mismatch: CSV=%d, DB=%d', ...
                        validation.csv_rows, validation.db_rows);
                end
                
                % Compare key fields
                if validation.csv_rows == validation.db_rows
                    % TODO: confirm key field decisions 
                    key_fields = {'EVENTNO', 'LAT_DD', 'LONG_DD', 'YEAR', 'MONTH', 'DAY'};
                    
                    if check_all_fields
                        % Check all fields
                        fields_to_check = csv_survey.Properties.VariableNames;
                    else
                        % Check only key fields
                        fields_to_check = key_fields;
                    end
                    
                    for j = 1:length(fields_to_check)
                        field = fields_to_check{j};
                        
                        if ~ismember(field, db_survey.Properties.VariableNames)
                            continue;
                        end
                        
                        % Compare field values
                        csv_vals = csv_survey.(field);
                        db_vals = db_survey.(field);
                        
                        % Handle missing values
                        csv_missing = ismissing(csv_vals);
                        db_missing = ismissing(db_vals);
                        
                        if ~isequal(csv_missing, db_missing)
                            validation.issues{end+1} = sprintf('Field %s: missing value mismatch', field);
                        end
                        
                        % Compare non-missing values
                        if isnumeric(csv_vals)
                            % Numeric comparison with tolerance
                            non_missing = ~csv_missing & ~db_missing;
                            if any(non_missing)
                                if ~all(abs(csv_vals(non_missing) - db_vals(non_missing)) < 1e-6)
                                    validation.issues{end+1} = sprintf('Field %s: numeric values differ', field);
                                end
                            end
                        else
                            % String comparison
                            non_missing = ~csv_missing & ~db_missing;
                            if any(non_missing)
                                if ~isequal(csv_vals(non_missing), db_vals(non_missing))
                                    validation.issues{end+1} = sprintf('Field %s: string values differ', field);
                                end
                            end
                        end
                    end
                end
                
                validation.matches = isempty(validation.issues);
                validations(i) = validation;
            end
        end
        
        function csv_data = readCSVFull(obj, extractor)
            % READCSVFULL Read entire CSV (with progress logging)
            
            obj.logger.info('Loading full CSV file...');
            extractor.loadData();
            csv_data = extractor.data;
        end
        
        function summary = createSummary(obj, results)
            % CREATESUMMARY Create text summary
            
            summary = sprintf('\n=== Migration Validation Summary ===\n\n');
            summary = [summary sprintf('CSV File: %s\n', results.survey_file)];
            summary = [summary sprintf('Validation Time: %s\n\n', char(results.validation_time))];
            
            summary = [summary sprintf('Survey Counts:\n')];
            summary = [summary sprintf('  CSV: %d surveys\n', results.csv_survey_count)];
            summary = [summary sprintf('  Database: %d surveys\n', results.db_survey_count)];
            summary = [summary sprintf('  Missing from DB: %d\n', results.survey_comparison.missing_from_db)];
            summary = [summary sprintf('  Extra in DB: %d\n\n', results.survey_comparison.extra_in_db)];
            
            summary = [summary sprintf('Record Counts:\n')];
            summary = [summary sprintf('  CSV: %d records\n', results.csv_total_records)];
            summary = [summary sprintf('  Database: %d records\n\n', results.db_total_records)];
            
            summary = [summary sprintf('Sample Validation:\n')];
            summary = [summary sprintf('  Surveys checked: %d\n', length(results.survey_validations))];
            matching = sum([results.survey_validations.matches]);
            summary = [summary sprintf('  Matching: %d\n', matching)];
            summary = [summary sprintf('  Mismatched: %d\n\n', length(results.survey_validations) - matching)];
            
            if results.is_valid
                summary = [summary sprintf('Result: ✓ VALIDATION PASSED\n')];
            else
                summary = [summary sprintf('Result: ✗ VALIDATION FAILED\n\n')];
                summary = [summary sprintf('Issues:\n')];
                for i = 1:length(results.issues)
                    summary = [summary sprintf('  - %s\n', results.issues{i})];
                end
            end
            
            summary = [summary sprintf('\n===================================\n')];
        end
    end
end