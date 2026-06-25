function behavioral_rules(data, collector, config)
    % BEHAVIORAL_RULES Validate behavioral observation fields
    %
    % Inputs:
    %   data      - Table with survey data
    %   collector - ErrorCollector instance
    %   config    - Configuration struct (optional)

    if nargin < 3 || isempty(config)
        full_config = get_config('validation');
        config = full_config.behavioral;
        config.behave_table_path = full_config.behave_table_path;
    elseif isfield(config, 'behavioral')
        behave_path = '';
        if isfield(config, 'behave_table_path')
            behave_path = config.behave_table_path;
        elseif isfield(config.behavioral, 'behave_table_path')
            behave_path = config.behavioral.behave_table_path;
        end
        config = config.behavioral;
        if ~isempty(behave_path)
            config.behave_table_path = behave_path;
        end
    end

    if ~isfield(config, 'behave_table_path')
        try
            paths = get_config('paths');
            config.behave_table_path = paths.lookup_tables.behave;
        catch
            warning('behavioral_rules:NoPath', 'Could not determine behave_table_path');
            return;
        end
    end

    valid_codes = load_behavior_codes(config);
    if isempty(valid_codes)
        warning('behavioral_rules:NoCodesLoaded', ...
            'Could not load behavior codes from %s - skipping behavioral validation', ...
            config.behave_table_path);
        return;
    end

    behav_columns = get_behav_columns(data);
    if isempty(behav_columns)
        return;
    end

    for i = 1:length(behav_columns)
        validate_behavior_codes(data, collector, behav_columns{i}, valid_codes);
    end

    validate_behavior_compatibility(data, collector, behav_columns, config);

    if ismember('TAXCODE', data.Properties.VariableNames)
        validate_behavior_taxcode_compatibility(data, collector, behav_columns, config);
    end

    if ismember('SPECCODE', data.Properties.VariableNames)
        validate_behavior_species_compatibility(data, collector, behav_columns, config);
    end

    validate_calf_behavior_consistency(data, collector, behav_columns, config);
end

function valid_codes = load_behavior_codes(config)
    valid_codes = [];
    if ~exist(config.behave_table_path, 'file')
        return;
    end
    try
        behave_table = readtable(config.behave_table_path, 'TextType', 'string');
        if ismember('Value', behave_table.Properties.VariableNames)
            valid_codes = behave_table.Value;
        elseif ismember('CODE', behave_table.Properties.VariableNames)
            valid_codes = behave_table.CODE;
        elseif width(behave_table) >= 1
            valid_codes = behave_table{:, 1};
        end
        if ~isnumeric(valid_codes)
            valid_codes = str2double(valid_codes);
        end
        valid_codes = valid_codes(~isnan(valid_codes));
    catch ME
        warning('behavioral_rules:LoadError', 'Error loading behavior codes: %s', ME.message);
    end
end

function behav_columns = get_behav_columns(data)
    behav_columns = {};
    all_vars = data.Properties.VariableNames;
    for i = 1:15
        col_name = sprintf('BEHAV%d', i);
        if ismember(col_name, all_vars)
            behav_columns{end+1} = col_name; %#ok<AGROW>
        end
    end
end

function validate_behavior_codes(data, collector, column_name, valid_codes)
    values = data.(column_name);
    if iscell(values)
        values = cellfun(@(x) str2double(x), values);
    elseif isstring(values)
        values = str2double(values);
    end
    non_null_idx = find(~isnan(values) & ~ismissing(values));
    if isempty(non_null_idx)
        return;
    end
    invalid_idx = non_null_idx(~ismember(values(non_null_idx), valid_codes));
    if ~isempty(invalid_idx)
        invalid_values = unique(values(invalid_idx));
        collector.addError(column_name, invalid_idx, ...
            sprintf('%s contains invalid behavior code(s): %s', ...
                column_name, mat2str(invalid_values)), 'error', ...
            'behavioral_rules.invalid_behavior_code');
    end
end

function validate_behavior_compatibility(data, collector, behav_columns, config)
    if length(behav_columns) < 2
        return;
    end
    n_rows = height(data);
    for row = 1:n_rows
        row_behaviors = get_row_behaviors(data, row, behav_columns);
        if length(row_behaviors) < 2
            continue;
        end
        incompatible = check_incompatible_behaviors(row_behaviors, config);
        if ~isempty(incompatible)
            collector.addError('BEHAV', row, ...
                sprintf('Incompatible behaviors recorded: %s', incompatible), 'error', ...
                'behavioral_rules.incompatible_behaviors');
        end
    end
end

function row_behaviors = get_row_behaviors(data, row, behav_columns)
    row_behaviors = [];
    for i = 1:length(behav_columns)
        val = data.(behav_columns{i})(row);
        if iscell(val)
            val = str2double(val{1});
        elseif isstring(val)
            val = str2double(val);
        end
        if ~isnan(val) && ~ismissing(val)
            row_behaviors(end+1) = val; %#ok<AGROW>
        end
    end
end

function incompatible_msg = check_incompatible_behaviors(behaviors, config)
    incompatible_msg = '';
    dead_behaviors   = config.dead_behaviors;
    active_swimming  = config.active_swimming_behaviors;
    has_dead   = any(ismember(behaviors, dead_behaviors));
    has_active = any(ismember(behaviors, active_swimming));
    if has_dead && has_active
        incompatible_msg = 'Dead/stranded animal cannot have active swimming behavior';
        return;
    end
    for i = 1:size(config.incompatible_behavior_pairs, 1)
        pair = config.incompatible_behavior_pairs(i, :);
        if all(ismember(pair, behaviors))
            incompatible_msg = sprintf('Behaviors %d and %d are incompatible', pair(1), pair(2));
            return;
        end
    end
end

function validate_behavior_taxcode_compatibility(data, collector, behav_columns, config)
    n_rows = height(data);
    for row = 1:n_rows
        taxcode = data.TAXCODE(row);
        if iscell(taxcode)
            taxcode = taxcode{1};
        end
        if isstring(taxcode)
            taxcode = char(taxcode);
        end
        if isempty(taxcode) || all(ismissing(taxcode))
            continue;
        end
        row_behaviors = get_row_behaviors(data, row, behav_columns);
        if isempty(row_behaviors)
            continue;
        end
        invalid_behavior = check_taxcode_behavior_restrictions(taxcode, row_behaviors, config);
        if ~isempty(invalid_behavior)
            eventno = get_eventno(data, row);
            collector.addError('BEHAV', row, ...
                sprintf('Behavior %d not valid for taxcode %s: %s', ...
                    invalid_behavior.code, taxcode, invalid_behavior.reason), 'warning', ...
                'behavioral_rules.taxcode_behavior_restriction', eventno);
        end
    end
end

function invalid = check_taxcode_behavior_restrictions(taxcode, behaviors, config)
    invalid = [];
    if isfield(config, 'taxcode_behavior_restrictions') && ...
            isfield(config.taxcode_behavior_restrictions, taxcode)
        restricted = config.taxcode_behavior_restrictions.(taxcode);
        for i = 1:length(behaviors)
            if ismember(behaviors(i), restricted.invalid_codes)
                invalid.code   = behaviors(i);
                invalid.reason = restricted.reason;
                return;
            end
        end
    end
end

function validate_behavior_species_compatibility(data, collector, behav_columns, config)
    n_rows = height(data);
    for row = 1:n_rows
        speccode = data.SPECCODE(row);
        if iscell(speccode)
            speccode = speccode{1};
        end
        if isstring(speccode)
            speccode = char(speccode);
        end
        if isempty(speccode) || all(ismissing(speccode))
            continue;
        end
        row_behaviors = get_row_behaviors(data, row, behav_columns);
        if isempty(row_behaviors)
            continue;
        end
        invalid_behavior = check_species_behavior_restrictions(speccode, row_behaviors, config);
        if ~isempty(invalid_behavior)
            eventno = get_eventno(data, row);
            collector.addError('BEHAV', row, ...
                sprintf('Behavior %d not typical for species %s: %s', ...
                    invalid_behavior.code, speccode, invalid_behavior.reason), 'warning', ...
                'behavioral_rules.species_behavior_restriction', eventno);
        end
    end
end

function invalid = check_species_behavior_restrictions(speccode, behaviors, config)
    invalid = [];
    if isfield(config, 'species_behavior_restrictions') && ...
            isfield(config.species_behavior_restrictions, speccode)
        restricted = config.species_behavior_restrictions.(speccode);
        for i = 1:length(behaviors)
            if ismember(behaviors(i), restricted.invalid_codes)
                invalid.code   = behaviors(i);
                invalid.reason = restricted.reason;
                return;
            end
        end
    end
end

function validate_calf_behavior_consistency(data, collector, behav_columns, config)
    calf_field = '';
    if ismember('NUMCALF', data.Properties.VariableNames)
        calf_field = 'NUMCALF';
    elseif ismember('CAESSION', data.Properties.VariableNames)
        calf_field = 'CAESSION';
    end
    if isempty(calf_field)
        return;
    end
    n_rows = height(data);
    for row = 1:n_rows
        row_behaviors = get_row_behaviors(data, row, behav_columns);
        if isempty(row_behaviors)
            continue;
        end
        has_calf_behavior = any(ismember(row_behaviors, config.calf_associated_behaviors));
        if has_calf_behavior
            calf_count = data.(calf_field)(row);
            if iscell(calf_count)
                calf_count = str2double(calf_count{1});
            end
            calf_present = ~isnan(calf_count) && ~ismissing(calf_count) && calf_count > 0;
            if ~calf_present
                calf_behaviors_found = row_behaviors(ismember(row_behaviors, config.calf_associated_behaviors));
                eventno = get_eventno(data, row);
                collector.addError('BEHAV', row, ...
                    sprintf('Calf-associated behavior(s) %s recorded but no calf present', ...
                        mat2str(calf_behaviors_found)), 'warning', ...
                    'behavioral_rules.calf_behavior_no_calf', eventno);
            end
        end
    end
end

function eventno = get_eventno(data, row)
    eventno = [];
    if ismember('EVENTNO', data.Properties.VariableNames)
        val = data.EVENTNO(row);
        if isnumeric(val) && ~isnan(val)
            eventno = val;
        end
    end
end

function config = default_config() %#ok<DEFNU>
    config.behave_table_path            = fullfile('.', 'data', 'tables', 'Behave.csv');
    config.dead_behaviors               = [0, 1, 2, 3];
    config.active_swimming_behaviors    = [6, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
    config.incompatible_behavior_pairs  = [6, 22; 22, 11];
    config.calf_associated_behaviors    = [];
    config.taxcode_behavior_restrictions = struct();
    config.species_behavior_restrictions = struct();
end
