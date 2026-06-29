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
            % TODO: increase readability of this section (maybe just refactor
            % into method) if height(data) < 0 this function does nothing
            % anyway, maybe should pop a different error
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
            ack_info       = obj.applyOverrides(fileid);
            n_acknowledged = ack_info.n_per_row + ack_info.n_per_survey;

            % Collect results
            results.errors   = obj.collector.getErrors('error');
            results.warnings = obj.collector.getErrors('warning');
            results.info     = obj.collector.getErrors('info');
            results.summary  = obj.collector.getSummary();

            results.summary.warnings_acknowledged_per_row    = ack_info.n_per_row;
            results.summary.warnings_acknowledged_per_survey = ack_info.n_per_survey;
            results.summary.warnings_acknowledged            = n_acknowledged;
            results.summary.warnings_new                     = results.summary.warnings;
            results.summary.acknowledgement_by_rule          = ack_info.by_rule;

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
                'Validation complete: %d errors, %d warnings (%d acknowledged [%d per-row, %d per-survey], %d new)', ...
                results.summary.errors, ...
                n_acknowledged + results.summary.warnings_new, ...
                n_acknowledged, ack_info.n_per_row, ack_info.n_per_survey, ...
                results.summary.warnings_new));

            if ~is_valid
                obj.logger.warning('Data has validation errors');
            end
        end

        function runValidationRules(obj, data)
            % RUNVALIDATIONRULES Execute all validation rules

            % TODO: figure out how configs may need to be incorporated into the
            % below rules. The rules functions accept a config, but it is not
            % used here.

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
                narwc.validation.rules.behavioral_rules(data, obj.collector, obj.config);
            end

            if obj.config.validate_foreign_keys
                obj.logger.debug('Validating foreign key fields...');
                narwc.validation.rules.foreign_key_rules(data, obj.collector);
            end
        end

        function details = formatErrorDetails(obj)
            % FORMATERRORDETAILS Format errors and warnings for display
            % Format: [SEVERITY] FIELD: message (rows X, EVENTNO=N)

            details = cell(0);

            for sev = {'error', 'warning'}
                entries = obj.collector.getErrors(sev{1});
                for i = 1:length(entries)
                    e = entries(i);

                    % Build location suffix combining row and EVENTNO where available
                    parts = {};
                    if ~isempty(e.row)
                        parts{end+1} = sprintf('rows %s', mat2str(e.row)); %#ok<AGROW>
                    end
                    if ~isempty(e.eventno) && ~any(isnan(e.eventno))
                        parts{end+1} = sprintf('EVENTNO=%d', e.eventno); %#ok<AGROW>
                    end

                    if isempty(parts)
                        loc = '';
                    else
                        loc = [' (' strjoin(parts, ', ') ')'];
                    end

                    details{end+1} = sprintf('[%s] %s: %s%s', ... %#ok<AGROW>
                        upper(sev{1}), e.field, e.message, loc);
                end
            end
        end
    end

    methods (Access = private)
        function ack_result = applyOverrides(obj, fileid)
            % APPLYOVERRIDES Demote warnings that have a matching override entry to 'info'
            %
            % Returns a struct with per-row and per-survey acknowledgement counts
            % and a per-rule breakdown.

            % FIXME: this method has low readability which will make error
            % checking difficult

            ack_result.n_per_row    = 0;
            ack_result.n_per_survey = 0;
            ack_result.by_rule      = struct();

            if isempty(obj.overrides) || isempty(fileid)
                return;
            end

            warning_indices = obj.collector.getWarningIndices();
            warnings        = obj.collector.getErrors('warning');

            matcher_list = obj.buildMatcherList(fileid);
            if isempty(matcher_list)
                return;
            end

            for k = 1:length(warning_indices)
                w = warnings(k);
                if isempty(w.eventno) || isempty(w.rule_id)
                    continue;
                end
                for m = 1:length(matcher_list)
                    fn    = matcher_list{m}{1};
                    label = matcher_list{m}{2};
                    if fn(w.eventno, w.field, w.rule_id)
                        obj.collector.demoteToInfo(warning_indices(k));
                        ack_result.(['n_' label]) = ack_result.(['n_' label]) + 1;
                        rule_key = strrep(w.rule_id, '.', '_');
                        if ~isfield(ack_result.by_rule, rule_key)
                            ack_result.by_rule.(rule_key) = struct( ...
                                'rule_id', w.rule_id, 'per_row', 0, 'per_survey', 0);
                        end
                        ack_result.by_rule.(rule_key).(label) = ...
                            ack_result.by_rule.(rule_key).(label) + 1;
                        break;  % first match wins; no double-counting
                    end
                end
            end
        end

        function matcher_list = buildMatcherList(obj, fileid)
            % BUILDMATCHERLIST Build an ordered list of {matcher_fn, label} pairs
            % for warnings belonging to this survey.
            %
            % Each entry is a 2-element cell: {fn, label} where
            %   fn(eventno, field, rule_id) -> logical
            %   label is 'per_row' or 'per_survey'
            %
            % Override rows are pre-filtered by fileid so matchers only carry
            % the remaining key fields in their closures.
            %
            % TODO: Phase B — append a third class of matcher here for
            %       fileid_pattern glob matching across multiple surveys.

            matcher_list = {};
            for k = 1:height(obj.overrides)
                if ~strcmp(obj.overrides.fileid{k}, fileid)
                    continue;
                end
                ovr_eno     = obj.overrides.eventno(k);
                ovr_field   = obj.overrides.field{k};
                ovr_rule_id = obj.overrides.rule_id{k};

                if ~isnan(ovr_eno)
                    fn = @(eno, fld, rid) ovr_eno == eno && ...
                        strcmp(ovr_field, fld) && strcmp(ovr_rule_id, rid);
                    matcher_list{end+1} = {fn, 'per_row'}; %#ok<AGROW>
                else
                    fn = @(eno, fld, rid) strcmp(ovr_field, fld) && ... %#ok<NASGU>
                        strcmp(ovr_rule_id, rid);
                    matcher_list{end+1} = {fn, 'per_survey'}; %#ok<AGROW>
                end
            end
        end

        function overrides = loadOverrides(obj, override_file)
            % LOADOVERRIDES Read override CSV, skipping comment lines.
            %
            % Returns an empty array if override_file is empty or does not exist.
            % Empty eventno values are normalized to NaN (per-survey override sentinel).

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

                % Normalize eventno to double; empty cells become NaN (per-survey sentinel)
                if iscell(tbl.eventno)
                    raw = tbl.eventno;
                    eventno_dbl = nan(height(tbl), 1);
                    for i = 1:height(tbl)
                        val = strtrim(raw{i});
                        if ~isempty(val)
                            eventno_dbl(i) = str2double(val);
                        end
                    end
                    tbl.eventno = eventno_dbl;
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

            % Override file path — caller can supply via config struct or
            % set via load_config() batch config (validation.overrides.csv_path).
            % Empty string means no overrides are loaded.
            config.override_file = '';
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
