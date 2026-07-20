classdef SurveyProcessor < handle
    % SURVEYPROCESSOR Main data processing pipeline
    %
    % Usage:
    %   processor = narwc.processing.SurveyProcessor();
    %   [processed_data, tracker] = processor.process(raw_data);

    % NOTE: only called by test_processing unit test right now. Not sure this will get used in the end
    
    properties (Access = private)
        config
        logger
        tracker
        steps
    end
    
    methods
        function obj = SurveyProcessor(config)
            % SURVEYPROCESSOR Constructor
            
            if nargin < 1
                obj.config = obj.defaultConfig();
            else
                obj.config = config;
            end
            
            obj.logger = logging.Logger('narwc.processing.SurveyProcessor');
            obj.tracker = narwc.processing.ChangeTracker();
            obj.registerSteps();
        end
        
        function [data_out, tracker] = process(obj, data_in, options)
            % PROCESS Run processing pipeline
            %
            % Inputs:
            %   data_in - Raw survey data table
            %   options - Name-value pairs:
            %       'Steps' - Cell array of step names to run (default: all)
            %       'StopOnError' - Stop if step fails (default: false)
            %
            % Outputs:
            %   data_out - Processed data
            %   tracker - ChangeTracker with all modifications
            
            arguments
                obj
                data_in table
                options.Steps cell = {}
                options.StopOnError logical = false
            end
            
            obj.logger.info('Starting data processing pipeline...');
            obj.tracker.clear();
            % TODO: I want the ability to process a single step without clearing
            
            data_out = data_in;
            initial_rows = height(data_in);
            
            % Determine which steps to run
            if isempty(options.Steps)
                steps_to_run = obj.steps.keys();
            else
                steps_to_run = options.Steps;
            end
            
            % Run each step
            for i = 1:length(steps_to_run)
                step_name = steps_to_run{i};
                
                if ~obj.steps.isKey(step_name)
                    obj.logger.warning(sprintf('Unknown step: %s, skipping', step_name));
                    continue;
                end
                
                obj.logger.info(sprintf('Running step: %s', step_name));
                
                try
                    step_func = obj.steps(step_name);
                    [data_out, obj.tracker] = step_func(data_out, obj.tracker, obj.config);
                    
                    obj.logger.info(sprintf('  ✓ %s complete (%d changes)', ...
                        step_name, obj.tracker.getChangeCount(step_name)));
                    
                catch ME
                    obj.logger.error(sprintf('  ✗ %s failed: %s', step_name, ME.message));
                    
                    if options.StopOnError
                        error('Processing stopped due to error in step: %s', step_name);
                    end
                end
            end
            
            % Summary
            final_rows = height(data_out);
            obj.logger.info(sprintf('Processing complete: %d -> %d rows, %d total changes', ...
                initial_rows, final_rows, obj.tracker.getChangeCount()));
            
            tracker = obj.tracker;
        end
        
        function registerSteps(obj)
            % REGISTERSTEPS Register available processing steps
            
            obj.steps = containers.Map();
            
            % Register each step with full path
            obj.steps('remove_duplicates') = @narwc.processing.steps.remove_duplicates;
            obj.steps('standardize_coordinates') = @narwc.processing.steps.standardize_coordinates;
            obj.steps('standardize_species_codes') = @narwc.processing.steps.standardize_species_codes;
            obj.steps('flag_outliers') = @narwc.processing.steps.flag_outliers;
            % FIXME: add later
            % obj.steps('calculate_derived_fields') = @narwc.processing.steps.calculate_derived_fields;
        end
        
        function config = defaultConfig(obj)
            % DEFAULTCONFIG Default processing configuration
            
            config = struct();
            
            % Remove duplicates config
            config.key_fields = {'FILEID', 'EVENTNO', 'LAT_DD', 'LONG_DD', 'TIME'};
            
            % Coordinate standardization
            config.decimal_places = 6;
            
            % Species code mapping
            config.species_map = containers.Map(...
                {'RW', 'RIGHT', 'NARW'}, ...
                {'RIWH', 'RIWH', 'RIWH'});
            config.to_upper = true;
            
            % Outlier detection
            config.fields = {'ALT', 'BEAUFORT', 'NUMBER'};
            config.iqr_multiplier = 3;
        end
        
        function displaySummary(obj)
            % DISPLAYSUMMARY Display processing summary
            obj.tracker.displaySummary();
        end
    end
end