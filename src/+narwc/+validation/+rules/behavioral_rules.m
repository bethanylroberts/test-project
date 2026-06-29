function behavioral_rules(data, collector, config)
    % BEHAVIORAL_RULES Validate behavioral observation fields
    %
    % Inputs:
    %   data      - Table with survey data
    %   collector - ErrorCollector instance
    %   config    - Configuration struct

    if isfield(config, 'behavioral')
        config = config.behavioral;
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

    % Build the behavior value matrix once; all sub-functions reuse it.
    % Rows: data rows.  Columns: BEHAV1 … BEHAV15 (only present columns).
    % NaN for missing / blank cells.
    behav_matrix = build_behav_matrix(data, behav_columns);

    for i = 1:length(behav_columns)
        validate_behavior_codes(data, collector, behav_columns{i}, valid_codes);
    end

    validate_behavior_compatibility(behav_matrix, collector, config);

    if ismember('TAXCODE', data.Properties.VariableNames)
        validate_behavior_taxcode_compatibility(data, behav_matrix, collector, config);
    end

    if ismember('SPECCODE', data.Properties.VariableNames)
        validate_behavior_species_compatibility(data, behav_matrix, collector, config);
    end

    validate_calf_behavior_consistency(data, behav_matrix, collector, config);
end

% ── Helpers ────────────────────────────────────────────────────────────────

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

function mat = build_behav_matrix(data, behav_columns)
    % Build n_rows × n_bcols numeric matrix of behavior codes (NaN for missing)
    n_rows  = height(data);
    n_bcols = length(behav_columns);
    mat     = nan(n_rows, n_bcols);
    for c = 1:n_bcols
        vals = data.(behav_columns{c});
        if iscell(vals)
            vals = cellfun(@(x) str2double(x), vals);
        elseif isstring(vals)
            vals = str2double(vals);
        end
        mat(:, c) = vals;
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

% ── Validation sub-functions ───────────────────────────────────────────────

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

function validate_behavior_compatibility(behav_matrix, collector, config)
    % Vectorized check for incompatible behavior combinations.
    % Each row is flagged at most once (first applicable rule wins).
    if size(behav_matrix, 2) < 2
        return;
    end

    dead_behaviors  = config.dead_behaviors;
    active_swimming = config.active_swimming_behaviors;
    pairs           = config.incompatible_behavior_pairs;

    n_rows  = size(behav_matrix, 1);
    flagged = false(n_rows, 1);

    % Dead / stranded + active swimming
    has_dead   = any(ismember(behav_matrix, dead_behaviors),  2);
    has_active = any(ismember(behav_matrix, active_swimming), 2);
    dead_rows  = find(has_dead & has_active & ~flagged);
    if ~isempty(dead_rows)
        msg = 'Incompatible behaviors recorded: Dead/stranded animal cannot have active swimming behavior';
        for i = 1:length(dead_rows)
            collector.addError('BEHAV', dead_rows(i), msg, 'error', ...
                'behavioral_rules.incompatible_behaviors');
        end
        flagged(dead_rows) = true;
    end

    % Declared incompatible pairs
    for p = 1:size(pairs, 1)
        has_p1    = any(behav_matrix == pairs(p, 1), 2);
        has_p2    = any(behav_matrix == pairs(p, 2), 2);
        pair_rows = find(has_p1 & has_p2 & ~flagged);
        if ~isempty(pair_rows)
            msg = sprintf('Incompatible behaviors recorded: Behaviors %d and %d are incompatible', ...
                pairs(p, 1), pairs(p, 2));
            for i = 1:length(pair_rows)
                collector.addError('BEHAV', pair_rows(i), msg, 'error', ...
                    'behavioral_rules.incompatible_behaviors');
            end
            flagged(pair_rows) = true;
        end
    end
end

function validate_behavior_taxcode_compatibility(data, behav_matrix, collector, config)
    % Early return when no TAXCODE restrictions are configured
    if ~isfield(config, 'taxcode_behavior_restrictions') || ...
            isempty(fieldnames(config.taxcode_behavior_restrictions))
        return;
    end

    n_rows = height(data);
    for row = 1:n_rows
        taxcode = data.TAXCODE(row);
        if iscell(taxcode), taxcode = taxcode{1}; end
        if isstring(taxcode), taxcode = char(taxcode); end
        if isempty(taxcode) || all(ismissing(taxcode))
            continue;
        end
        row_behaviors = behav_matrix(row, :);
        row_behaviors = row_behaviors(~isnan(row_behaviors));
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

function validate_behavior_species_compatibility(data, behav_matrix, collector, config)
    % Early return when no species restrictions are configured
    if ~isfield(config, 'species_behavior_restrictions') || ...
            isempty(fieldnames(config.species_behavior_restrictions))
        return;
    end

    n_rows = height(data);
    for row = 1:n_rows
        speccode = data.SPECCODE(row);
        if iscell(speccode), speccode = speccode{1}; end
        if isstring(speccode), speccode = char(speccode); end
        if isempty(speccode) || all(ismissing(speccode))
            continue;
        end
        row_behaviors = behav_matrix(row, :);
        row_behaviors = row_behaviors(~isnan(row_behaviors));
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

function validate_calf_behavior_consistency(data, behav_matrix, collector, config)
    calf_field = '';
    if ismember('NUMCALF', data.Properties.VariableNames)
        calf_field = 'NUMCALF';
    elseif ismember('CAESSION', data.Properties.VariableNames)
        calf_field = 'CAESSION';
    end
    if isempty(calf_field)
        return;
    end

    calf_assoc = config.calf_associated_behaviors;

    % Vectorized: which rows have at least one calf-associated behavior?
    has_calf_behav = any(ismember(behav_matrix, calf_assoc), 2);
    if ~any(has_calf_behav)
        return;  % fast path — no calf behaviors in this survey
    end

    % Calf presence vector
    calf_count = data.(calf_field);
    if iscell(calf_count)
        calf_count = cellfun(@(x) str2double(x), calf_count);
    elseif isstring(calf_count)
        calf_count = str2double(calf_count);
    end
    calf_present = ~isnan(calf_count) & calf_count > 0;

    % Rows that trigger the warning
    warn_rows = find(has_calf_behav & ~calf_present);
    for i = 1:length(warn_rows)
        row       = warn_rows(i);
        row_codes = behav_matrix(row, :);
        found     = row_codes(ismember(row_codes, calf_assoc) & ~isnan(row_codes));
        eventno   = get_eventno(data, row);
        collector.addError('BEHAV', row, ...
            sprintf('Calf-associated behavior(s) %s recorded but no calf present', ...
                mat2str(found)), 'warning', ...
            'behavioral_rules.calf_behavior_no_calf', eventno);
    end
end
