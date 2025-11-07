classdef SurveyValidator < handle
    % SURVEYVALIDATOR Main validation orchestrator
    %
    % Usage:
    %   validator = narwc.validation.SurveyValidator();
    %   [is_valid, results] = validator.validate(data);
    
    properties (Access = private)
        config
        logger
        collector
    end
    
    methods
        function obj = SurveyValidator(config)
            % SURVEYVALIDATOR Constructor
            
            if nargin < 1
                obj.config = obj.defaultConfig();
            else
                obj.config = config;
                % TODO: impliment custom configs with options
            end
            
            obj.logger = logging.Logger('narwc.validation.SurveyValidator');
            obj.collector = narwc.validation.ErrorCollector();
        end
        
        function [is_valid, results] = validate(obj, data)
            % VALIDATE Validate survey data
            %
            % Inputs:
            %   data - Table with survey data
            %
            % Outputs:
            %   is_valid - True if no errors found
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
            
            % Determine if valid (no errors, warnings are OK)
            is_valid = results.summary.errors == 0;
            % TODO: make warnings an option
            
            % Log summary
            obj.logger.info(sprintf('Validation complete: %d errors, %d warnings', ...
                results.summary.errors, results.summary.warnings));
            
            if ~is_valid
                obj.logger.warning('Data has validation errors');
            end
        end
        
        function runValidationRules(obj, data)
            % RUNVALIDATIONRULES Execute all validation rules
            
            % Coordinate validation
            if obj.config.validate_coordinates
                obj.logger.debug('Validating coordinates...');
                narwc.validation.rules.coordinate_rules(data, obj.collector, obj.config);
            end
            
            % TODO: Add more rule calls here as you implement them
            % narwc.validation.rules.temporal_rules(data, obj.collector, obj.config);
            % narwc.validation.rules.species_rules(data, obj.collector, obj.config);
            % etc.

            % TODO: add some method for running and batch running custom rules

        end
        
        function config = defaultConfig(obj)
            % DEFAULTCONFIG Default validation configuration
            
            % Which validations to run
            config.validate_coordinates = true;
            config.validate_temporal = true;
            config.validate_species = true;
            config.validate_behavioral = true;
            config.validate_platform = true;
            
            % Coordinate ranges (North Atlantic Right Whale habitat)
            config.lat_min = -90;
            config.lat_max = 90;
            config.lon_min = -180;
            config.lon_max = 180;
            config.survey_lat_min = 35;
            config.survey_lat_max = 50;
            config.survey_lon_min = -75;
            config.survey_lon_max = -60;
            
            % Temporal ranges
            config.min_year = 1970;
            config.max_year = year(datetime('today'));
            
            % Other settings
            config.check_land = false;
        end
    end
end