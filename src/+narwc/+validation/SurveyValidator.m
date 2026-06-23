classdef SurveyValidator < handle
    % SURVEYVALIDATOR Main validation orchestrator
    %
    % Usage:
    %   validator = narwc.validation.SurveyValidator();
    %   [is_valid, results] = validator.validate(data);

    % NOTE: used by BatchConverter, this is the workhorse of the processing
    % since I only really want to check validation, and then hand it back to the
    % user to fix
    
    properties (Access = private)
        config
        logger
        collector
    end
    
    methods
        function obj = SurveyValidator(config)
            % SURVEYVALIDATOR Constructor
            
            obj.logger = logging.Logger('narwc.validation.SurveyValidator');
            obj.collector = narwc.validation.ErrorCollector();
            
            if nargin < 1 || isempty(config)
                obj.config = obj.defaultConfig();
            else
                % Merge provided config with defaults
                obj.config = obj.mergeConfig(obj.defaultConfig(), config);
            end
        end
        
        function [is_valid, results] = validate(obj, data)
            % VALIDATE Validate survey data
            %
            % Inputs:
            %   data - Table with survey data
            %
            % Outputs:
            %   is_valid - True if no errors (and no warnings unless allowed)
            %   results - Struct with validation results
            
            obj.logger.info('Starting validation...');
            obj.collector.clear();
            
            % Run validation rules
            obj.runValidationRules(data);
            
            % Collect results
            results.errors = obj.collector.getErrors('error');
            results.warnings = obj.collector.getErrors('warning');
            results.info = obj.collector.getErrors('info');
            results.summary = obj.collector.getSummary();
            
            % Add detailed error information
            results.error_details = obj.formatErrorDetails();
            
            % Determine if valid based on config
            has_errors = results.summary.errors > 0;
            has_warnings = results.summary.warnings > 0;
            
            if has_errors && ~obj.config.allow_errors
                is_valid = false;
            elseif has_warnings && ~obj.config.allow_warnings
                is_valid = false;
            else
                is_valid = true;
            end
            
            % Log summary
            obj.logger.info(sprintf('Validation complete: %d errors, %d warnings', ...
                results.summary.errors, results.summary.warnings));
            
            if ~is_valid
                obj.logger.warning('Data has validation errors');
            end
        end
        
        function runValidationRules(obj, data)
            % RUNVALIDATIONRULES Execute all validation rules
            
            % Required fields (database NOT NULL constraints)
            if obj.config.validate_required_fields
                obj.logger.debug('Validating required fields...');
                narwc.validation.rules.required_fields(data, obj.collector);
            end
            
            % Coordinate validation
            if obj.config.validate_coordinates
                obj.logger.debug('Validating coordinates...');
                narwc.validation.rules.coordinate_rules(data, obj.collector);
            end
            
            % Date and time validation
            if obj.config.validate_datetime
                obj.logger.debug('Validating date/time fields...');
                narwc.validation.rules.datetime_rules(data, obj.collector);
            end
            
            % Species validation
            if obj.config.validate_species
                obj.logger.debug('Validating species fields...');
                narwc.validation.rules.species_rules(data, obj.collector);
            end
            
            % Environmental conditions validation
            if obj.config.validate_environmental
                obj.logger.debug('Validating environmental fields...');
                narwc.validation.rules.environmental_rules(data, obj.collector);
            end
            
            % Beaufort scale
            if obj.config.validate_beaufort
                obj.logger.debug('Validating Beaufort scale...');
                narwc.validation.rules.beaufort_rules(data, obj.collector);
            end

            % Behavioral validation
            if obj.config.validate_behavioral
                obj.logger.debug('Validating behavioral fields...');
                narwc.validation.rules.behavioral_rules(data, obj.collector);
            end
            
            % Foreign key validation (PLATFORM, PHOTOS, CONTRIB, etc.)
            if obj.config.validate_foreign_keys
                obj.logger.debug('Validating foreign key fields...');
                narwc.validation.rules.foreign_key_rules(data, obj.collector);
            end

        end
        
        function details = formatErrorDetails(obj)
            % FORMATERRORDETAILS Format errors for display
            % Format: [SEVERITY] FIELD: message (rows X)
            
            details = cell(0);
            
            % Get errors
            errors = obj.collector.getErrors('error');
            for i = 1:length(errors)
                err = errors(i);
                if isfield(err, 'row') && ~isempty(err.row)
                    details{end+1} = sprintf('[ERROR] %s: %s (rows %s)', ...
                        err.field, err.message, mat2str(err.row)); %#ok<AGROW>
                else
                    details{end+1} = sprintf('[ERROR] %s: %s', err.field, err.message); %#ok<AGROW>
                end
            end
            
            % Get warnings
            warnings = obj.collector.getErrors('warning');
            for i = 1:length(warnings)
                wrn = warnings(i);
                if isfield(wrn, 'row') && ~isempty(wrn.row)
                    details{end+1} = sprintf('[WARNING] %s: %s (rows %s)', ...
                        wrn.field, wrn.message, mat2str(wrn.row)); %#ok<AGROW>
                else
                    details{end+1} = sprintf('[WARNING] %s: %s', wrn.field, wrn.message); %#ok<AGROW>
                end
            end
        end
    end
    
    methods (Access = private)
        function config = defaultConfig(~)
            % DEFAULTCONFIG Default validation configuration
            %
            % Uses centralized config and adds validation flags
            
            % Get validation config from centralized source
            try
                config = get_config('validation');
            catch
                % Fallback if get_config not available
                config = struct();
            end
            
            % Add validation flags (which rules to run)
            config.validate_required_fields = true;
            config.validate_coordinates = true;
            config.validate_datetime = true;
            config.validate_species = true;
            config.validate_environmental = true;
            config.validate_beaufort = true;
            config.validate_behavioral = true;
            config.validate_platform = true;
            config.validate_foreign_keys = true;
            
            % Override flags - allow upload despite issues
            config.allow_errors = false;    % If true, errors won't block upload
            config.allow_warnings = false;  % If true, warnings won't block upload
        end
        
        function merged = mergeConfig(obj, base, override)
            % MERGECONFIG Merge override config into base config
            
            merged = base;
            
            if isempty(override)
                return;
            end
            
            fields = fieldnames(override);
            for i = 1:length(fields)
                field = fields{i};
                if isstruct(override.(field)) && isfield(base, field) && isstruct(base.(field))
                    % Recursively merge nested structs
                    merged.(field) = obj.mergeConfig(base.(field), override.(field));
                else
                    merged.(field) = override.(field);
                end
            end
        end
    end
end