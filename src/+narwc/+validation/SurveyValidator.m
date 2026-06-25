classdef SurveyValidator < handle
    % SURVEYVALIDATOR Main validation orchestrator
    %
    % Usage:
    %   validator = narwc.validation.SurveyValidator();
    %   [is_valid, results] = validator.validate(data);
    %
    %   % With a custom override file (useful in tests):
    %   cfg = struct('override_file', '/path/to/overrides.csv');
    %   validator = narwc.validation.SurveyValidator(cfg);

    properties (Access = private)
        config
        logger
        collector
        overrides   % table loaded from override_file, or [] if none
    end

    methods
        function obj = SurveyValidator(config)
            % SURVEYVALIDATOR Constructor

            obj.logger    = logging.Logger('narwc.validation.SurveyValidator');
            obj.collector = narwc.validation.ErrorCollector();

            if nargin < 1 || isempty(config)
                obj.config = obj.defaultConfig();
            else
                obj.config = obj.mergeConfig(obj.defaultConfig(), config);
            end

            obj.overrides = obj.loadOverrides(obj.config.override_file);
        end

        function [is_valid, results] = validate(obj, data)
            % VALIDATE Validate survey data
            %
            % Inputs:
            %   data - Table with survey data
            %
            % Outputs:
            %   is_valid - True if no blocking errors or unacknowledged warnings
            %   results  - Struct with validation results

            obj.logger.info('Starting validation...');
            obj.collector.clear();

            % Run validation rules
            obj.runValidationRules(data);

            % Extract FILEID for override matching
            fileid = '';
            if ismember('FILEID', data.Properties.VariableNames) && height(data) > 0
                fid_val = data.FILEID;
                if iscell(fid_val)
                    fileid = fid_val{1};
                elseif isstring(fid_val)
                    fileid = char(fid_val(1));
                elseif ischar(fid_val)
                    fileid = fid_val;
                end
            end

            % Demote acknowledged warnings to info
            n_acknowledged = obj.applyOverrides(fileid);

            % Collect results
            results.errors   = obj.collector.getErrors('error');
            results.warnings = obj.collector.getErrors('warning');
            results.info     = obj.collector.getErrors('info');
            results.summary  = obj.collector.getSummary();

            results.summary.warnings_acknowledged = n_acknowledged;
            results.summary.warnings_new          = results.summary.warnings;

            results.error_details = obj.formatErrorDetails();

            % Determine validity
            has_errors   = results.summary.errors > 0;
            has_warnings = results.summary.warnings_new > 0;

            if has_errors && ~obj.config.allow_errors
                is_valid = false;
            elseif has_warnings && ~obj.config.allow_warnings
                is_valid = false;
            else
                is_valid = true;
            end

            obj.logger.info(sprintf( ...
                'Validation complete: %d errors, %d warnings (%d acknowledged, %d new)', ...
                results.summary.errors, ...
                n_acknowledged + results.summary.warnings_new, ...
                n_acknowledged, results.summary.warnings_new));

            if ~is_valid
                obj.logger.warning('Data has validation errors');
            end
        end

        function runValidationRules(obj, data)
            % RUNVALIDATIONRULES Execute all validation rules

            if obj.config.validate_required_fields
                obj.logger.debug('Validating required fields...');
                narwc.validation.rules.required_fields(data, obj.collector);
            end

            if obj.config.validate_coordinates
                obj.logger.debug('Validating coordinates...');
                narwc.validation.rules.coordinate_rules(data, obj.collector);
            end

            if obj.config.validate_datetime
                obj.logger.debug('Validating date/time fields...');
                narwc.validation.rules.datetime_rules(data, obj.collector);
            end

            if obj.config.validate_species
                obj.logger.debug('Validating species fields...');
                narwc.validation.rules.species_rules(data, obj.collector);
            end

            if obj.config.validate_environmental
                obj.logger.debug('Validating environmental fields...');
                narwc.validation.rules.environmental_rules(data, obj.collector);
            end

            if obj.config.validate_beaufort
                obj.logger.debug('Validating Beaufort scale...');
                narwc.validation.rules.beaufort_rules(data, obj.collector);
            end

            if obj.config.validate_behavioral
                obj.logger.debug('Validating behavioral fields...');
                narwc.validation.rules.behavioral_rules(data, obj.collector);
            end

            if obj.config.validate_foreign_keys
                obj.logger.debug('Validating foreign key fields...');
                narwc.validation.rules.foreign_key_rules(data, obj.collector);
            end
        end

        function details = formatErrorDetails(obj)
            % FORMATERRORDETAILS Format errors for display
            % Format: [SEVERITY] FIELD: message (rows X)

            details = cell(0);

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
        function n_acknowledged = applyOverrides(obj, fileid)
            % APPLYOVERRIDES Demote warnings that have a matching override entry to 'info'
            %
            % Returns the number of warnings that were acknowledged.

            n_acknowledged = 0;

            if isempty(obj.overrides) || isempty(fileid)
                return;
            end

            warning_indices = obj.collector.getWarningIndices();
            warnings        = obj.collector.getErrors('warning');

            for k = 1:length(warning_indices)
                w = warnings(k);
                if ~isempty(w.eventno) && ~isempty(w.rule_id)
                    if obj.hasOverride(fileid, w.eventno, w.field, w.rule_id)
                        obj.collector.demoteToInfo(warning_indices(k));
                        n_acknowledged = n_acknowledged + 1;
                    end
                end
            end
        end

        function match = hasOverride(obj, fileid, eventno, field, rule_id)
            % HASOVERRIDE Check whether a (fileid, eventno, field, rule_id) tuple is acknowledged

            match = false;

            if isempty(obj.overrides)
                return;
            end

            for k = 1:height(obj.overrides)
                if strcmp(obj.overrides.fileid{k}, fileid) && ...
                        obj.overrides.eventno(k) == eventno && ...
                        strcmp(obj.overrides.field{k}, field) && ...
                        strcmp(obj.overrides.rule_id{k}, rule_id)
                    match = true;
                    return;
                end
            end
        end

        function overrides = loadOverrides(obj, override_file)
            % LOADOVERRIDES Read data/overrides.csv, skipping comment lines
            %
            % Returns an empty array if the file does not exist.

            overrides = [];

            if isempty(override_file) || ~exist(override_file, 'file')
                return;
            end

            try
                % CommentStyle skips lines starting with '#'
                tbl = readtable(override_file, ...
                    'CommentStyle', '#', ...
                    'Delimiter', ',', ...
                    'TextType', 'char', ...
                    'VariableNamingRule', 'preserve');

                % Require the four key columns at a minimum
                required_cols = {'fileid', 'eventno', 'field', 'rule_id'};
                for i = 1:length(required_cols)
                    if ~ismember(required_cols{i}, tbl.Properties.VariableNames)
                        obj.logger.warning(sprintf( ...
                            'Override file %s missing required column: %s', ...
                            override_file, required_cols{i}));
                        return;
                    end
                end

                if height(tbl) == 0
                    return;
                end

                overrides = tbl;
                obj.logger.info(sprintf('Loaded %d override(s) from %s', ...
                    height(overrides), override_file));

            catch ME
                obj.logger.warning(sprintf( ...
                    'Could not load overrides from %s: %s', override_file, ME.message));
            end
        end

        function config = defaultConfig(~)
            % DEFAULTCONFIG Default validation configuration

            try
                config = get_config('validation');
            catch
                config = struct();
            end

            config.validate_required_fields = true;
            config.validate_coordinates     = true;
            config.validate_datetime        = true;
            config.validate_species         = true;
            config.validate_environmental   = true;
            config.validate_beaufort        = true;
            config.validate_behavioral      = true;
            config.validate_platform        = true;
            config.validate_foreign_keys    = true;

            config.allow_errors   = false;
            config.allow_warnings = false;

            config.override_file = fullfile('data', 'overrides.csv');
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
                    merged.(field) = obj.mergeConfig(base.(field), override.(field));
                else
                    merged.(field) = override.(field);
                end
            end
        end
    end
end
