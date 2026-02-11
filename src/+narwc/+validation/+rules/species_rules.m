function species_rules(data, collector, config)
    % SPECIES_RULES Validate species-related fields
    %
    % This validation module checks:
    %   1. SPECCODE - Species identification codes (4-char max)
    %   2. TAXCODE - Taxonomic category codes (0-9)
    %   3. NUMBER - Group size counts
    %   4. NUMCALF - Calf counts within groups
    %   5. Cross-field validation (SPECCODE-TAXCODE match, calves vs total)
    %
    % Inputs:
    %   data - Table with survey data
    %   collector - ErrorCollector instance
    %   config - Configuration struct (optional)
    %
    % Lookup Tables Used:
    %   - data/tables/SPECCODE.csv - Valid species codes and their properties
    %   - data/tables/TAXCODE.csv - Valid taxonomic categories
    %
    % Usage:
    %   collector = narwc.validation.ErrorCollector();
    %   narwc.validation.rules.species_rules(data, collector);
    %
    % See also: narwc.validation.SurveyValidator
    
    % Get default config from centralized source
    if nargin < 3 || isempty(config)
        full_config = get_config('validation');
        config = full_config.species;
        config.speccode_table_path = full_config.speccode_table_path;
        config.taxcode_table_path = full_config.taxcode_table_path;
    elseif isfield(config, 'species')
        paths = struct();
        if isfield(config, 'speccode_table_path')
            paths.speccode_table_path = config.speccode_table_path;
        end
        if isfield(config, 'taxcode_table_path')
            paths.taxcode_table_path = config.taxcode_table_path;
        end
        config = config.species;
        if isfield(paths, 'speccode_table_path')
            config.speccode_table_path = paths.speccode_table_path;
        end
        if isfield(paths, 'taxcode_table_path')
            config.taxcode_table_path = paths.taxcode_table_path;
        end
    end
    
    % Merge provided config with defaults to ensure all fields exist
    config = merge_with_defaults(config);
    
    % Load lookup tables if not already loaded
    if isempty(config.speccode_table)
        config = load_lookup_tables(config);
    end
    
    % Determine which records are sightings (vs environmental/platform records)
    % This affects which validations are required vs optional
    is_sighting = identify_sighting_records(data);
    
    % === Core Field Validations ===
    
    if ismember('SPECCODE', data.Properties.VariableNames)
        validate_speccode(data, collector, config, is_sighting);
    end
    
    if ismember('TAXCODE', data.Properties.VariableNames)
        validate_taxcode(data, collector, config, is_sighting);
    end
    
    if ismember('NUMBER', data.Properties.VariableNames)
        validate_group_size(data, collector, config, is_sighting);
    end
    
    if ismember('NUMCALF', data.Properties.VariableNames)
        validate_calf_count(data, collector, config, is_sighting);
    end
    
    % === Cross-Field Validations ===
    
    if ismember('SPECCODE', data.Properties.VariableNames) && ...
       ismember('TAXCODE', data.Properties.VariableNames)
        validate_speccode_taxcode_match(data, collector, config);
    end
    
    if ismember('NUMBER', data.Properties.VariableNames) && ...
       ismember('NUMCALF', data.Properties.VariableNames)
        validate_calves_vs_total(data, collector, config);
    end
    
    % === Species-Specific Validations ===
    
    if ismember('SPECCODE', data.Properties.VariableNames)
        validate_right_whale_specific(data, collector, config);
    end
end

%% ========================================================================
%  CONFIGURATION FUNCTIONS
%  ========================================================================

function config = default_config()
    % DEFAULT_CONFIG Default configuration for species validation
    %
    % Returns a struct with all configuration options and their default values.
    % Users can override any of these by passing a custom config struct.
    
    % --- Lookup Table Settings ---
    config.lookup_table_dir = 'data/tables';
    
    % --- TAXCODE Settings ---
    % Valid range based on database schema:
    %   0 = Human activity (vessels, fishing gear)
    %   1 = Large cetacean (includes unidentified whale)
    %   2 = Medium cetacean (minke, beaked, killer whales)
    %   3 = Small cetacean
    %   4 = Other marine mammal (seals, manatee)
    %   5 = Sea turtle
    %   6 = Shark
    %   7 = Other fish
    %   8 = Bird
    %   9 = Other/unknown
    config.valid_taxcodes = 0:9;
    
    % Cetacean taxcodes - species that can have calves recorded
    config.cetacean_taxcodes = [1, 2, 3];
    
    % Marine mammal taxcodes - species that might have calves
    config.marine_mammal_taxcodes = [1, 2, 3, 4];
    
    % --- Group Size Settings ---
    config.large_group_threshold = 500;      % Warn if NUMBER exceeds this
    config.very_large_group_threshold = 1000; % Error if NUMBER exceeds this
    config.max_calf_count = 50;              % Maximum reasonable calf count
    
    % --- Right Whale Specific Settings ---
    config.right_whale_codes = {'RIWH', 'NARW', 'SARW'};  % Right whale species codes
    config.right_whale_max_group = 50;       % Max typical right whale group size
    config.right_whale_max_calves = 5;       % Max calves in right whale group
    
    % --- Validation Behavior ---
    config.require_speccode_for_sightings = true;
    config.require_taxcode_for_sightings = true;
    config.validate_speccode_lookup = true;
    config.validate_taxcode_lookup = true;
    config.validate_speccode_taxcode_match = true;
    
    % --- Lookup Tables (loaded lazily) ---
    config.speccode_table = [];
    config.speccode_map = [];
    config.taxcode_table = [];
    config.taxcode_map = [];
end

function config = merge_with_defaults(config)
    % MERGE_WITH_DEFAULTS Merge user config with defaults
    %
    % Ensures all required configuration fields exist by filling in
    % missing fields with default values.
    
    defaults = default_config();
    default_fields = fieldnames(defaults);
    
    for i = 1:length(default_fields)
        field = default_fields{i};
        if ~isfield(config, field)
            config.(field) = defaults.(field);
        end
    end
end

function config = load_lookup_tables(config)
    % LOAD_LOOKUP_TABLES Load species and taxcode lookup tables from CSV files
    %
    % Loads:
    %   - SPECCODE.csv: Species codes, names, and associated TAXCODE
    %   - TAXCODE.csv: Taxonomic category codes and descriptions
    %
    % Creates containers.Map objects for O(1) lookup performance.
    
    % --- Load SPECCODE Table ---
    speccode_file = fullfile(config.lookup_table_dir, 'SPECCODE.csv');
    
    if exist(speccode_file, 'file')
        try
            opts = detectImportOptions(speccode_file);
            % Ensure Value column is read as string
            opts = setvartype(opts, 'Value', 'char');
            config.speccode_table = readtable(speccode_file, opts);
            
            % Create lookup map: SPECCODE -> row index
            codes = config.speccode_table.Value;
            if iscell(codes)
                config.speccode_map = containers.Map(codes, num2cell(1:height(config.speccode_table)));
            else
                config.speccode_map = containers.Map(cellstr(codes), num2cell(1:height(config.speccode_table)));
            end
            
            fprintf('    ✓ Loaded %d species codes from SPECCODE.csv\n', height(config.speccode_table));
        catch ME
            warning('species_rules:LoadError', 'Failed to load SPECCODE table: %s', ME.message);
            config.speccode_table = [];
            config.speccode_map = containers.Map();
        end
    else
        config.speccode_table = [];
        config.speccode_map = containers.Map();
    end
    
    % --- Load TAXCODE Table ---
    taxcode_file = fullfile(config.lookup_table_dir, 'TAXCODE.csv');
    
    if exist(taxcode_file, 'file')
        try
            config.taxcode_table = readtable(taxcode_file);
            
            % Create lookup map: TAXCODE -> row index
            codes = config.taxcode_table.Value;
            config.taxcode_map = containers.Map(codes, num2cell(1:height(config.taxcode_table)));
            
            fprintf('    ✓ Loaded %d taxon codes from TAXCODE.csv\n', height(config.taxcode_table));
        catch ME
            warning('species_rules:LoadError', 'Failed to load TAXCODE table: %s', ME.message);
            config.taxcode_table = [];
            config.taxcode_map = containers.Map();
        end
    else
        config.taxcode_table = [];
        config.taxcode_map = containers.Map();
    end
end

%% ========================================================================
%  HELPER FUNCTIONS
%  ========================================================================

function is_sighting = identify_sighting_records(data)
    % IDENTIFY_SIGHTING_RECORDS Determine which records represent animal sightings
    %
    % Records are considered sightings if:
    %   - SIGHTNO > 0 (has a sighting number), OR
    %   - NUMBER > 0 (has animals counted), OR
    %   - SPECCODE is not empty and not a platform/environmental code
    %
    % Returns a logical array of the same height as data.
    
    num_records = height(data);
    is_sighting = false(num_records, 1);
    
    % Method 1: Has sighting number
    if ismember('SIGHTNO', data.Properties.VariableNames)
        has_sightno = ~isnan(data.SIGHTNO) & data.SIGHTNO > 0;
        is_sighting = is_sighting | has_sightno;
    end
    
    % Method 2: Has animals counted
    if ismember('NUMBER', data.Properties.VariableNames)
        has_number = ~isnan(data.NUMBER) & data.NUMBER > 0;
        is_sighting = is_sighting | has_number;
    end
    
    % Method 3: Has species code (excluding platform/environmental codes)
    if ismember('SPECCODE', data.Properties.VariableNames)
        platform_codes = {'AC-J', 'AC-P', 'AC-S', 'AC-T', 'BOAT', 'GEAR', 'DEBR'};
        
        if iscellstr(data.SPECCODE) || isstring(data.SPECCODE)
            has_speccode = ~cellfun(@isempty, data.SPECCODE);
            is_platform = ismember(upper(data.SPECCODE), platform_codes);
            is_sighting = is_sighting | (has_speccode & ~is_platform);
        end
    end
end

function speccode_str = safe_get_speccode(data, idx)
    % SAFE_GET_SPECCODE Safely extract SPECCODE value as string
    
    if iscell(data.SPECCODE)
        speccode_str = data.SPECCODE{idx};
    elseif isstring(data.SPECCODE)
        speccode_str = char(data.SPECCODE(idx));
    else
        speccode_str = char(data.SPECCODE(idx));
    end
end

%% ========================================================================
%  VALIDATION FUNCTIONS
%  ========================================================================

function validate_speccode(data, collector, config, is_sighting)
    % VALIDATE_SPECCODE Validate species identification codes
    %
    % Checks:
    %   1. Length <= 4 characters (database constraint)
    %   2. Not empty for sighting records
    %   3. Valid code in lookup table (if available)
    %   4. No invalid characters
    
    if ~(iscellstr(data.SPECCODE) || isstring(data.SPECCODE) || ischar(data.SPECCODE))
        collector.addError('SPECCODE', [], ...
            'SPECCODE column has unexpected data type', 'error');
        return;
    end
    
    num_records = height(data);
    
    % --- Check 1: Length constraint (varchar(4)) ---
    for i = 1:num_records
        speccode = safe_get_speccode(data, i);
        
        if length(speccode) > 4
            collector.addError('SPECCODE', i, ...
                sprintf('SPECCODE "%s" exceeds 4 characters', speccode), 'error');
        end
    end
    
    % --- Check 2: Required for sighting records ---
    if config.require_speccode_for_sightings
        for i = 1:num_records
            if is_sighting(i)
                speccode = safe_get_speccode(data, i);
                
                if isempty(speccode) || strcmp(strtrim(speccode), '')
                    collector.addError('SPECCODE', i, ...
                        'SPECCODE is required for sighting records', 'error');
                end
            end
        end
    end
    
    % --- Check 3: Valid code in lookup table ---
    if config.validate_speccode_lookup && ~isempty(config.speccode_map)
        for i = 1:num_records
            speccode = safe_get_speccode(data, i);
            
            if ~isempty(speccode) && ~isKey(config.speccode_map, speccode)
                collector.addError('SPECCODE', i, ...
                    sprintf('SPECCODE "%s" not found in species lookup table', speccode), ...
                    'error');
            end
        end
    end
    
    % --- Check 4: Valid characters (alphanumeric and hyphen only) ---
    for i = 1:num_records
        speccode = safe_get_speccode(data, i);
        
        if ~isempty(speccode)
            % Allow letters, numbers, and hyphens
            invalid_chars = regexprep(speccode, '[A-Za-z0-9\-]', '');
            
            if ~isempty(invalid_chars)
                collector.addError('SPECCODE', i, ...
                    sprintf('SPECCODE "%s" contains invalid characters: "%s"', speccode, invalid_chars), ...
                    'error');
            end
        end
    end
end

function validate_taxcode(data, collector, config, is_sighting)
    % VALIDATE_TAXCODE Validate taxonomic category codes
    %
    % Checks:
    %   1. Value in valid range (0-9)
    %   2. Not missing for sighting records
    %   3. Valid code in lookup table (if available)
    
    num_records = height(data);
    
    % --- Check 1: Valid range ---
    for i = 1:num_records
        taxcode = data.TAXCODE(i);
        
        if ~isnan(taxcode) && ~ismissing(taxcode)
            if ~ismember(taxcode, config.valid_taxcodes)
                collector.addError('TAXCODE', i, ...
                    sprintf('TAXCODE %d is not valid (must be 0-9)', taxcode), 'error');
            end
        end
    end
    
    % --- Check 2: Required for sighting records ---
    if config.require_taxcode_for_sightings
        for i = 1:num_records
            if is_sighting(i)
                taxcode = data.TAXCODE(i);
                
                if isnan(taxcode) || ismissing(taxcode)
                    collector.addError('TAXCODE', i, ...
                        'TAXCODE is required for sighting records', 'error');
                end
            end
        end
    end
    
    % --- Check 3: Valid code in lookup table ---
    if config.validate_taxcode_lookup && ~isempty(config.taxcode_map)
        for i = 1:num_records
            taxcode = data.TAXCODE(i);
            
            if ~isnan(taxcode) && ~ismissing(taxcode)
                if ~isKey(config.taxcode_map, taxcode)
                    collector.addError('TAXCODE', i, ...
                        sprintf('TAXCODE %d not found in lookup table', taxcode), ...
                        'warning');
                end
            end
        end
    end
end

function validate_speccode_taxcode_match(data, collector, config)
    % VALIDATE_SPECCODE_TAXCODE_MATCH Verify SPECCODE and TAXCODE are consistent
    %
    % Uses the SPECCODE lookup table which contains the expected TAXCODE
    % for each species. Flags mismatches as errors since they could indicate
    % data entry errors.
    
    if ~config.validate_speccode_taxcode_match
        return;
    end
    
    if isempty(config.speccode_table) || ...
       ~ismember('TAXCODE', config.speccode_table.Properties.VariableNames)
        return;  % Can't validate without lookup table
    end
    
    num_records = height(data);
    
    for i = 1:num_records
        speccode = safe_get_speccode(data, i);
        taxcode = data.TAXCODE(i);
        
        % Skip if either is empty/missing
        if isempty(speccode) || isnan(taxcode) || ismissing(taxcode)
            continue;
        end
        
        % Look up expected TAXCODE for this SPECCODE
        if isKey(config.speccode_map, speccode)
            table_row = config.speccode_map(speccode);
            expected_taxcode = config.speccode_table.TAXCODE(table_row);
            
            % Handle various types of expected_taxcode
            if iscell(expected_taxcode)
                expected_taxcode = expected_taxcode{1};
            end
            
            % Skip if expected is empty or NaN
            if isempty(expected_taxcode) || ...
               (isnumeric(expected_taxcode) && isnan(expected_taxcode)) || ...
               (ischar(expected_taxcode) && strcmp(expected_taxcode, ''))
                continue;
            end
            
            % Convert to numeric if needed
            if ischar(expected_taxcode) || isstring(expected_taxcode)
                expected_taxcode = str2double(expected_taxcode);
            end
            
            % Compare
            if ~isnan(expected_taxcode) && expected_taxcode ~= taxcode
                collector.addError('TAXCODE', i, ...
                    sprintf('TAXCODE mismatch: got %d, expected %d for SPECCODE "%s"', ...
                    taxcode, expected_taxcode, speccode), ...
                    'error');
            end
        end
    end
end

function validate_group_size(data, collector, config, is_sighting)
    % VALIDATE_GROUP_SIZE Validate NUMBER field (group size)
    %
    % Checks:
    %   1. Non-negative values
    %   2. Non-zero for sighting records
    %   3. Reasonable size (warnings for large groups)
    %   4. Integer values
    
    num_records = height(data);
    
    for i = 1:num_records
        number = data.NUMBER(i);
        
        if isnan(number) || ismissing(number)
            continue;
        end
        
        % --- Check 1: Non-negative ---
        if number < 0
            collector.addError('NUMBER', i, ...
                sprintf('NUMBER cannot be negative (got %d)', number), 'error');
            continue;  % Skip other checks for this record
        end
        
        % --- Check 2: Non-zero for sightings ---
        if is_sighting(i) && number == 0
            collector.addError('NUMBER', i, ...
                'NUMBER is zero for sighting record', 'warning');
        end
        
        % --- Check 3: Reasonable size ---
        if number > config.very_large_group_threshold
            collector.addError('NUMBER', i, ...
                sprintf('NUMBER=%d exceeds maximum threshold (%d) - likely data error', ...
                number, config.very_large_group_threshold), 'error');
        elseif number > config.large_group_threshold
            collector.addError('NUMBER', i, ...
                sprintf('NUMBER=%d is unusually large - verify count', number), 'warning');
        end
        
        % --- Check 4: Integer value ---
        if number ~= floor(number)
            collector.addError('NUMBER', i, ...
                sprintf('NUMBER must be an integer (got %.2f)', number), 'error');
        end
    end
end

function validate_calf_count(data, collector, config, is_sighting)
    % VALIDATE_CALF_COUNT Validate NUMCALF field (calf count)
    %
    % Checks:
    %   1. Non-negative values
    %   2. Reasonable count
    %   3. Only for appropriate species (cetaceans/marine mammals)
    %   4. Integer values
    
    num_records = height(data);
    has_taxcode = ismember('TAXCODE', data.Properties.VariableNames);
    
    for i = 1:num_records
        numcalf = data.NUMCALF(i);
        
        if isnan(numcalf) || ismissing(numcalf)
            continue;
        end
        
        % --- Check 1: Non-negative ---
        if numcalf < 0
            collector.addError('NUMCALF', i, ...
                sprintf('NUMCALF cannot be negative (got %d)', numcalf), 'error');
            continue;
        end
        
        % --- Check 2: Reasonable count ---
        if numcalf > config.max_calf_count
            collector.addError('NUMCALF', i, ...
                sprintf('NUMCALF=%d exceeds maximum threshold (%d)', ...
                numcalf, config.max_calf_count), 'warning');
        end
        
        % --- Check 3: Appropriate species ---
        if numcalf > 0 && has_taxcode
            taxcode = data.TAXCODE(i);
            
            if ~isnan(taxcode) && ~ismissing(taxcode)
                if ~ismember(taxcode, config.marine_mammal_taxcodes)
                    collector.addError('NUMCALF', i, ...
                        sprintf('NUMCALF=%d for non-mammal species (TAXCODE=%d)', ...
                        numcalf, taxcode), 'warning');
                end
            end
        end
        
        % --- Check 4: Integer value ---
        if numcalf ~= floor(numcalf)
            collector.addError('NUMCALF', i, ...
                sprintf('NUMCALF must be an integer (got %.2f)', numcalf), 'error');
        end
    end
end

function validate_calves_vs_total(data, collector, config)
    % VALIDATE_CALVES_VS_TOTAL Verify calf count doesn't exceed group size
    %
    % This is a logical consistency check - you can't have more calves
    % than total animals in the group.
    
    num_records = height(data);
    
    for i = 1:num_records
        number = data.NUMBER(i);
        numcalf = data.NUMCALF(i);
        
        % Skip if either is missing
        if isnan(number) || isnan(numcalf) || ismissing(number) || ismissing(numcalf)
            continue;
        end
        
        if numcalf > number
            collector.addError('NUMCALF', i, ...
                sprintf('NUMCALF (%d) exceeds total NUMBER (%d)', numcalf, number), ...
                'error');
        end
        
        % Additional check: calves shouldn't be more than half the group
        % (each calf needs at least one adult)
        if numcalf > 0 && number > 0 && numcalf > number / 2
            collector.addError('NUMCALF', i, ...
                sprintf('NUMCALF (%d) is more than half of NUMBER (%d) - verify count', ...
                numcalf, number), 'warning');
        end
    end
end

function validate_right_whale_specific(data, collector, config)
    % VALIDATE_RIGHT_WHALE_SPECIFIC Additional validation for right whale sightings
    %
    % Right whales (RIWH, NARW, SARW) have special considerations:
    %   - They are critically endangered
    %   - Group sizes are typically small (1-20)
    %   - Calf counts are carefully tracked
    %   - Data quality is especially important
    
    num_records = height(data);
    has_number = ismember('NUMBER', data.Properties.VariableNames);
    has_numcalf = ismember('NUMCALF', data.Properties.VariableNames);
    
    for i = 1:num_records
        speccode = safe_get_speccode(data, i);
        
        if ~ismember(upper(speccode), config.right_whale_codes)
            continue;  % Not a right whale
        end
        
        % --- Check group size ---
        if has_number
            number = data.NUMBER(i);
            
            if ~isnan(number) && number > config.right_whale_max_group
                collector.addError('NUMBER', i, ...
                    sprintf('Right whale group size (%d) unusually large - verify count', ...
                    number), 'warning');
            end
        end
        
        % --- Check calf count ---
        if has_numcalf
            numcalf = data.NUMCALF(i);
            
            if ~isnan(numcalf) && numcalf > config.right_whale_max_calves
                collector.addError('NUMCALF', i, ...
                    sprintf('Right whale calf count (%d) unusually high - verify count', ...
                    numcalf), 'warning');
            end
        end
    end
end