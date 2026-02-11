function behavioral_rules(data, collector, config)
    % BEHAVIORAL_RULES Validate behavioral observation fields
    %
    % Inputs:
    %   data      - Table with survey data
    %   collector - ErrorCollector instance for reporting issues
    %   config    - Configuration struct (optional, uses get_config if not provided)
    
    % Get default config from centralized source
    if nargin < 3 || isempty(config)
        full_config = get_config('validation');
        config = full_config.behavioral;
        config.behave_table_path = full_config.behave_table_path;
    elseif isfield(config, 'behavioral')
        % Full validation config passed - extract behavioral section
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
    % If config already has behave_table_path directly, use as-is
    
    % Ensure behave_table_path exists
    if ~isfield(config, 'behave_table_path')
        try
            paths = get_config('paths');
            config.behave_table_path = paths.lookup_tables.behave;
        catch
            warning('behavioral_rules:NoPath', 'Could not determine behave_table_path');
            return;
        end
    end
    
    % Load valid behavior codes
    valid_codes = load_behavior_codes(config);
    if isempty(valid_codes)
        warning('behavioral_rules:NoCodesLoaded', ...
            'Could not load behavior codes from %s - skipping behavioral validation', ...
            config.behave_table_path);
        return;
    end
    
    
    % Get list of BEHAV columns present in data
    behav_columns = get_behav_columns(data);
    
    if isempty(behav_columns)
        return;  % No behavior columns to validate
    end
    
    % Validate each behavior column has valid codes
    for i = 1:length(behav_columns)
        validate_behavior_codes(data, collector, behav_columns{i}, valid_codes);
    end
    
    % Validate behavior combinations are compatible
    validate_behavior_compatibility(data, collector, behav_columns, config);
    
    % Validate behaviors are compatible with taxcode
    if ismember('TAXCODE', data.Properties.VariableNames)
        validate_behavior_taxcode_compatibility(data, collector, behav_columns, config);
    end
    
    % Validate behaviors are compatible with species code
    if ismember('SPECCODE', data.Properties.VariableNames)
        validate_behavior_species_compatibility(data, collector, behav_columns, config);
    end
    
    % Validate calf-related behaviors have calf present
    validate_calf_behavior_consistency(data, collector, behav_columns, config);
end

function valid_codes = load_behavior_codes(config)
    % Load valid behavior codes from Behave.csv
    
    valid_codes = [];
    
    if ~exist(config.behave_table_path, 'file')
        return;
    end
    
    try
        behave_table = readtable(config.behave_table_path, 'TextType', 'string');
        
        % Handle different possible column names
        if ismember('Value', behave_table.Properties.VariableNames)
            valid_codes = behave_table.Value;
        elseif ismember('CODE', behave_table.Properties.VariableNames)
            valid_codes = behave_table.CODE;
        elseif width(behave_table) >= 1
            % Assume first column is the code
            valid_codes = behave_table{:, 1};
        end
        
        % Ensure numeric
        if ~isnumeric(valid_codes)
            valid_codes = str2double(valid_codes);
        end
        
        % Remove NaN values
        valid_codes = valid_codes(~isnan(valid_codes));
        
    catch ME
        warning('behavioral_rules:LoadError', ...
            'Error loading behavior codes: %s', ME.message);
    end
end

function behav_columns = get_behav_columns(data)
    % Get list of BEHAV1-BEHAV15 columns present in data
    
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
    % Validate that behavior codes are valid
    
    values = data.(column_name);
    
    % Handle different data types
    if iscell(values)
        values = cellfun(@(x) str2double(x), values);
    elseif isstring(values)
        values = str2double(values);
    end
    
    % Find non-empty, non-NaN values
    non_null_idx = find(~isnan(values) & ~ismissing(values));
    
    if isempty(non_null_idx)
        return;
    end
    
    % Check which values are not in valid codes
    invalid_idx = non_null_idx(~ismember(values(non_null_idx), valid_codes));
    
    if ~isempty(invalid_idx)
        invalid_values = unique(values(invalid_idx));
        collector.addError(column_name, invalid_idx, ...
            sprintf('%s contains invalid behavior code(s): %s', ...
                column_name, mat2str(invalid_values)), 'error');
    end
end

function validate_behavior_compatibility(data, collector, behav_columns, config)
    % Validate that behaviors within a record are compatible with each other
    %
    % For example, a dead animal cannot also be swimming
    
    if length(behav_columns) < 2
        return;  % Need at least 2 behavior columns to check compatibility
    end
    
    % Collect all behaviors for each row
    n_rows = height(data);
    
    for row = 1:n_rows
        row_behaviors = get_row_behaviors(data, row, behav_columns);
        
        if length(row_behaviors) < 2
            continue;
        end
        
        % Check for incompatible combinations
        incompatible = check_incompatible_behaviors(row_behaviors, config);
        
        if ~isempty(incompatible)
            collector.addError('BEHAV', row, ...
                sprintf('Incompatible behaviors recorded: %s', incompatible), 'error');
        end
    end
end

function row_behaviors = get_row_behaviors(data, row, behav_columns)
    % Get all non-empty behavior codes for a single row
    
    row_behaviors = [];
    
    for i = 1:length(behav_columns)
        val = data.(behav_columns{i})(row);
        
        % Handle different data types
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
    % Check if a set of behaviors contains incompatible combinations
    %
    % Returns empty string if compatible, error message if not
    
    incompatible_msg = '';
    
    % Define behavior categories
    dead_behaviors = config.dead_behaviors;  % 0-3: dead states
    active_swimming = config.active_swimming_behaviors;  % Active movement behaviors
    
    % Check: Dead animals cannot have active behaviors
    has_dead = any(ismember(behaviors, dead_behaviors));
    has_active = any(ismember(behaviors, active_swimming));
    
    if has_dead && has_active
        incompatible_msg = 'Dead/stranded animal cannot have active swimming behavior';
        return;
    end
    
    % TODO: Add additional incompatibility checks here
    % Example patterns to implement:
    %   - Breach (13) is whale-specific, aerobatics (14) is dolphin-specific
    %   - Motionless at surface (22) incompatible with fast swimming (6)
    %   - Add more rules as needed based on domain knowledge
    
    % Check custom incompatible pairs from config
    for i = 1:size(config.incompatible_behavior_pairs, 1)
        pair = config.incompatible_behavior_pairs(i, :);
        if all(ismember(pair, behaviors))
            incompatible_msg = sprintf('Behaviors %d and %d are incompatible', pair(1), pair(2));
            return;
        end
    end
end

function validate_behavior_taxcode_compatibility(data, collector, behav_columns, config)
    % Validate behaviors are appropriate for the taxonomic group
    
    n_rows = height(data);
    
    for row = 1:n_rows
        taxcode = data.TAXCODE(row);
        
        % Handle different data types
        if iscell(taxcode)
            taxcode = taxcode{1};
        end
        if isstring(taxcode)
            taxcode = char(taxcode);
        end
        
        % Check for empty/missing - use all() for non-scalar ismissing result
        if isempty(taxcode) || all(ismissing(taxcode))
            continue;
        end
        
        row_behaviors = get_row_behaviors(data, row, behav_columns);
        
        if isempty(row_behaviors)
            continue;
        end
        
        % Check taxcode-specific restrictions
        invalid_behavior = check_taxcode_behavior_restrictions(taxcode, row_behaviors, config);
        
        if ~isempty(invalid_behavior)
            collector.addError('BEHAV', row, ...
                sprintf('Behavior %d not valid for taxcode %s: %s', ...
                    invalid_behavior.code, taxcode, invalid_behavior.reason), 'warning');
        end
    end
end

function invalid = check_taxcode_behavior_restrictions(taxcode, behaviors, config)
    % Check if any behaviors are invalid for the given taxcode
    %
    % Returns struct with code and reason, or empty if all valid
    
    invalid = [];
    
    % TODO: Define taxcode-behavior restrictions
    % Example structure (to be populated based on domain knowledge):
    %
    % Mysticeti (baleen whales):
    %   - Valid: breach (13), fluking behaviors
    %   - Invalid: bow riding (12), aerobatics (14)
    %
    % Odontoceti (toothed whales/dolphins):
    %   - Valid: aerobatics (14), bow riding (12)
    %   - Breach (13) may be less common
    %
    % Pinnipedia (seals/sea lions):
    %   - Invalid: most cetacean-specific behaviors
    
    % Check against configured restrictions
    if isfield(config, 'taxcode_behavior_restrictions') && ...
            isfield(config.taxcode_behavior_restrictions, taxcode)
        
        restricted = config.taxcode_behavior_restrictions.(taxcode);
        
        for i = 1:length(behaviors)
            if ismember(behaviors(i), restricted.invalid_codes)
                invalid.code = behaviors(i);
                invalid.reason = restricted.reason;
                return;
            end
        end
    end
end

function validate_behavior_species_compatibility(data, collector, behav_columns, config)
    % Validate behaviors are appropriate for the specific species
    
    n_rows = height(data);
    
    for row = 1:n_rows
        speccode = data.SPECCODE(row);
        
        % Handle different data types
        if iscell(speccode)
            speccode = speccode{1};
        end
        if isstring(speccode)
            speccode = char(speccode);
        end
        
        % Check for empty/missing - use all() for non-scalar ismissing result
        if isempty(speccode) || all(ismissing(speccode))
            continue;
        end
        
        row_behaviors = get_row_behaviors(data, row, behav_columns);
        
        if isempty(row_behaviors)
            continue;
        end
        
        % Check species-specific restrictions
        invalid_behavior = check_species_behavior_restrictions(speccode, row_behaviors, config);
        
        if ~isempty(invalid_behavior)
            collector.addError('BEHAV', row, ...
                sprintf('Behavior %d not typical for species %s: %s', ...
                    invalid_behavior.code, speccode, invalid_behavior.reason), 'warning');
        end
    end
end

function invalid = check_species_behavior_restrictions(speccode, behaviors, config)
    % Check if any behaviors are invalid/unusual for the given species
    %
    % Returns struct with code and reason, or empty if all valid
    
    invalid = [];
    
    % TODO: Define species-behavior restrictions
    % Example structure (to be populated based on domain knowledge):
    %
    % RIWH (Right Whale):
    %   - Common: breach (13), lobtailing (20), spyhopping (21)
    %   - Unusual/Invalid: bow riding (12), aerobatics (14)
    %
    % BODO (Bottlenose Dolphin):
    %   - Common: bow riding (12), aerobatics (14), porpoising (11)
    %   - Less common: spyhopping (21)
    %
    % HUWH (Humpback Whale):
    %   - Common: breach (13), flippering (19), lobtailing (20)
    
    % Check against configured restrictions
    if isfield(config, 'species_behavior_restrictions') && ...
            isfield(config.species_behavior_restrictions, speccode)
        
        restricted = config.species_behavior_restrictions.(speccode);
        
        for i = 1:length(behaviors)
            if ismember(behaviors(i), restricted.invalid_codes)
                invalid.code = behaviors(i);
                invalid.reason = restricted.reason;
                return;
            end
        end
    end
end

function validate_calf_behavior_consistency(data, collector, behav_columns, config)
    % Validate that calf-related behaviors have a calf present
    %
    % If a behavior is associated with a calf, NUMCALF should be > 0
    
    % Check if we have calf count field
    calf_field = '';
    if ismember('NUMCALF', data.Properties.VariableNames)
        calf_field = 'NUMCALF';
    elseif ismember('CAESSION', data.Properties.VariableNames)
        calf_field = 'CAESSION';
    end
    
    if isempty(calf_field)
        return;  % No calf field to check against
    end
    
    n_rows = height(data);
    
    for row = 1:n_rows
        row_behaviors = get_row_behaviors(data, row, behav_columns);
        
        if isempty(row_behaviors)
            continue;
        end
        
        % Check if any calf-associated behaviors are present
        has_calf_behavior = any(ismember(row_behaviors, config.calf_associated_behaviors));
        
        if has_calf_behavior
            % Check if calf is present
            calf_count = data.(calf_field)(row);
            
            if iscell(calf_count)
                calf_count = str2double(calf_count{1});
            end
            
            calf_present = ~isnan(calf_count) && ~ismissing(calf_count) && calf_count > 0;
            
            if ~calf_present
                calf_behaviors_found = row_behaviors(ismember(row_behaviors, config.calf_associated_behaviors));
                collector.addError('BEHAV', row, ...
                    sprintf('Calf-associated behavior(s) %s recorded but no calf present', ...
                        mat2str(calf_behaviors_found)), 'warning');
            end
        end
    end
end

function config = default_config()
    % Default configuration for behavioral validation
    
    % Path to behavior lookup table
    config.behave_table_path = fullfile('.', 'data', 'tables', 'Behave.csv');
    
    % Dead/stranded behavior codes (0-3)
    config.dead_behaviors = [0, 1, 2, 3];
    
    % Active swimming behaviors that are incompatible with dead state
    config.active_swimming_behaviors = [6, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
    
    % Pairs of behaviors that are incompatible with each other
    % Each row is [behavior1, behavior2]
    config.incompatible_behavior_pairs = [
        6, 22;   % Fast swimming incompatible with motionless at surface
        22, 11;  % Motionless at surface incompatible with porpoising
        % TODO: Add more incompatible pairs based on domain knowledge
    ];
    
    % TODO: Define calf-associated behaviors
    % These are behaviors that specifically involve or indicate a calf
    % Example: nursing behavior, calf-specific swimming patterns, etc.
    config.calf_associated_behaviors = [
        % TODO: Populate with behavior codes that require calf presence
        % Example: if code 99 means "nursing", add 99 here
    ];
    
    % TODO: Define taxcode-specific behavior restrictions
    % Structure: config.taxcode_behavior_restrictions.TAXCODE.invalid_codes = [...]
    %            config.taxcode_behavior_restrictions.TAXCODE.reason = '...'
    config.taxcode_behavior_restrictions = struct();
    
    % TODO: Define species-specific behavior restrictions
    % Structure: config.species_behavior_restrictions.SPECCODE.invalid_codes = [...]
    %            config.species_behavior_restrictions.SPECCODE.reason = '...'
    config.species_behavior_restrictions = struct();
end