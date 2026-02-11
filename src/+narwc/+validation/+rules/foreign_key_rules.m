function foreign_key_rules(data, collector, config)
    % FOREIGN_KEY_RULES Validate all fields with foreign key constraints
    %
    % This validation module checks fields that have foreign key relationships
    % to lookup tables in the database. Invalid values will cause INSERT to fail.
    %
    % Lookup tables validated:
    %   ANHEAD, Block, Cloud, Confidnc, Contrib, DDSOURCE, DType, GLARE,
    %   IDREL, IDSOURCE, LEGGOOD, LEGSTAGE, LEGTYPE, OLDVIZ, PHOTOS,
    %   PLATFORM, STRATUM, STRIP, WX
    %
    % Note: Some fields are also validated elsewhere:
    %   - SPECCODE, TAXCODE -> species_rules.m
    %   - BEAUFORT -> beaufort_rules.m
    %   - BEHAV1-15 -> behavioral_rules.m
    %
    % Inputs:
    %   data      - Table with survey data
    %   collector - ErrorCollector instance
    %   config    - Configuration struct (optional)
    %
    % Usage:
    %   collector = narwc.validation.ErrorCollector();
    %   narwc.validation.rules.foreign_key_rules(data, collector);
    %
    % See also: get_lookup_table, narwc.validation.SurveyValidator
    
    % Define all foreign key mappings: {field_name, lookup_table_name}
    % The lookup table name should match the filename (without .csv) in data/tables/
    fk_mappings = {
        % Field Name     Lookup Table    Notes
        'ANHEAD',        'anhead'        % Animal heading (1-8 compass)
        'BLOCK',         'block'         % Survey block
        'CLOUD',         'cloud'         % Cloud cover (oktas 0-8)
        'CONFIDNC',      'confidnc'      % ID confidence
        'CONTRIB',       'contrib'       % Data contributor
        'DDSOURCE',      'ddsource'      % Position source
        'DTYPE',         'dtype'         % Data type
        'GLAREL',        'glare'         % Left glare
        'GLARER',        'glare'         % Right glare (same table as GLAREL)
        'IDREL',         'idrel'         % ID reliability
        'IDSOURCE',      'idsource'      % ID source
        'LEGGOOD',       'leggood'       % Leg quality
        'LEGSTAGE',      'legstage'      % Leg stage
        'LEGTYPE',       'legtype'       % Leg type
        'OLDVIZ',        'oldviz'        % Old visibility format
        'PHOTOS',        'photos'        % Photos taken
        'PLATFORM',      'platform'      % Platform/vessel
        'STRATUM',       'stratum'       % Survey stratum
        'STRIP',         'strip'         % Strip transect flag
        'WX',            'wx'            % Weather conditions
    };
    
    % Cache for loaded lookup tables (avoid reloading same table)
    lookup_cache = containers.Map();
    
    % Validate each field
    for i = 1:size(fk_mappings, 1)
        field_name = fk_mappings{i, 1};
        table_name = fk_mappings{i, 2};
        
        % Skip if field not in data
        if ~ismember(field_name, data.Properties.VariableNames)
            continue;
        end
        
        % Load lookup table (with caching)
        if isKey(lookup_cache, table_name)
            valid_codes = lookup_cache(table_name);
        else
            valid_codes = load_valid_codes(table_name);
            lookup_cache(table_name) = valid_codes;
        end
        
        % Skip validation if lookup table couldn't be loaded
        if isempty(valid_codes)
            continue;
        end
        
        % Validate field values
        validate_field(data, collector, field_name, valid_codes, table_name);
    end
end

%% ========================================================================
%  HELPER FUNCTIONS
%  ========================================================================

function valid_codes = load_valid_codes(table_name)
    % LOAD_VALID_CODES Load valid codes from a lookup table
    %
    % Uses get_lookup_table() to load the CSV file, then extracts
    % the valid values from the 'Value' column (or first column).
    
    valid_codes = [];
    
    try
        lookup_table = get_lookup_table(table_name);
        
        if isempty(lookup_table) || height(lookup_table) == 0
            warning('foreign_key_rules:EmptyTable', ...
                'Lookup table %s is empty or not found', upper(table_name));
            return;
        end
        
        % Get values from 'Value' column or first column
        if ismember('Value', lookup_table.Properties.VariableNames)
            valid_codes = lookup_table.Value;
        else
            valid_codes = lookup_table{:, 1};
        end
        
        % Standardize the data type
        valid_codes = standardize_codes(valid_codes);
        
    catch ME
        warning('foreign_key_rules:LoadError', ...
            'Failed to load %s lookup table: %s', upper(table_name), ME.message);
    end
end

function codes = standardize_codes(codes)
    % STANDARDIZE_CODES Convert codes to consistent format
    %
    % Attempts to convert to numeric if all values are numeric.
    % Otherwise keeps as strings for comparison.
    
    if isempty(codes)
        return;
    end
    
    % Handle cell arrays
    if iscell(codes)
        % Remove empty cells
        codes = codes(~cellfun(@isempty, codes));
        
        % Try to convert to numeric
        numeric_codes = cellfun(@(x) str2double(string(x)), codes, 'UniformOutput', true);
        if all(~isnan(numeric_codes))
            codes = numeric_codes;
        else
            % Keep as trimmed strings
            codes = strtrim(string(codes));
        end
        return;
    end
    
    % Handle string arrays
    if isstring(codes)
        codes = codes(~ismissing(codes) & strlength(codes) > 0);
        
        % Try to convert to numeric
        numeric_codes = str2double(codes);
        if all(~isnan(numeric_codes))
            codes = numeric_codes;
        else
            codes = strtrim(codes);
        end
        return;
    end
    
    % Handle numeric - remove NaN
    if isnumeric(codes)
        codes = codes(~isnan(codes));
    end
end

function validate_field(data, collector, field_name, valid_codes, table_name)
    % VALIDATE_FIELD Check that all values in a field are in the valid codes list
    %
    % Reports errors for any values not found in the lookup table.
    
    values = data.(field_name);
    
    % Get non-null indices and values to check
    [non_null_idx, values_to_check] = get_non_null_values(values, valid_codes);
    
    if isempty(non_null_idx)
        return;
    end
    
    % Find invalid values
    if isnumeric(values_to_check) && isnumeric(valid_codes)
        invalid_mask = ~ismember(values_to_check, valid_codes);
    elseif isnumeric(valid_codes)
        % Try to convert values to numeric for comparison
        numeric_values = convert_to_numeric(values_to_check);
        if ~isempty(numeric_values)
            invalid_mask = ~ismember(numeric_values, valid_codes);
        else
            % Can't compare - treat all as invalid
            invalid_mask = true(size(values_to_check));
        end
    else
        % String comparison (case-insensitive, trimmed)
        values_str = upper(strtrim(string(values_to_check)));
        valid_str = upper(strtrim(string(valid_codes)));
        invalid_mask = ~ismember(values_str, valid_str);
    end
    
    % Report errors
    invalid_idx = non_null_idx(invalid_mask);
    
    if ~isempty(invalid_idx)
        report_invalid_values(collector, field_name, table_name, ...
            values_to_check, invalid_mask, invalid_idx);
    end
end

function [non_null_idx, values_to_check] = get_non_null_values(values, valid_codes)
    % GET_NON_NULL_VALUES Extract non-null values and their indices
    
    non_null_idx = [];
    values_to_check = [];
    
    if isnumeric(values)
        non_null_idx = find(~isnan(values) & ~ismissing(values));
        values_to_check = values(non_null_idx);
        
    elseif iscell(values)
        non_null_idx = find(~cellfun(@isempty, values) & ...
                           ~cellfun(@(x) all(ismissing(x)), values));
        if ~isempty(non_null_idx)
            values_to_check = values(non_null_idx);
            % Convert to appropriate type based on valid_codes
            if isnumeric(valid_codes)
                values_to_check = convert_to_numeric(values_to_check);
            else
                values_to_check = string(values_to_check);
            end
        end
        
    elseif isstring(values)
        non_null_idx = find(~ismissing(values) & strlength(values) > 0);
        if ~isempty(non_null_idx)
            values_to_check = values(non_null_idx);
            if isnumeric(valid_codes)
                values_to_check = convert_to_numeric(values_to_check);
            end
        end
    end
end

function numeric_values = convert_to_numeric(values)
    % CONVERT_TO_NUMERIC Try to convert values to numeric
    
    numeric_values = [];
    
    if isnumeric(values)
        numeric_values = values;
        return;
    end
    
    try
        if iscell(values)
            numeric_values = cellfun(@(x) str2double(string(x)), values, 'UniformOutput', true);
        elseif isstring(values)
            numeric_values = str2double(values);
        end
        
        % Return empty if conversion failed for all values
        if all(isnan(numeric_values))
            numeric_values = [];
        end
    catch
        numeric_values = [];
    end
end

function report_invalid_values(collector, field_name, table_name, values, invalid_mask, invalid_idx)
    % REPORT_INVALID_VALUES Add error to collector for invalid values
    
    invalid_values = values(invalid_mask);
    
    % Get unique invalid values for message
    if isnumeric(invalid_values)
        unique_invalid = unique(invalid_values(~isnan(invalid_values)));
        if length(unique_invalid) <= 5
            invalid_str = mat2str(unique_invalid(:)');
        else
            invalid_str = sprintf('%s ... (%d unique values)', ...
                mat2str(unique_invalid(1:3)'), length(unique_invalid));
        end
    else
        unique_invalid = unique(string(invalid_values));
        unique_invalid = unique_invalid(~ismissing(unique_invalid));
        if length(unique_invalid) <= 5
            invalid_str = strjoin(unique_invalid, ', ');
        else
            invalid_str = sprintf('%s ... (%d unique values)', ...
                strjoin(unique_invalid(1:3), ', '), length(unique_invalid));
        end
    end
    
    collector.addError(field_name, invalid_idx, ...
        sprintf('%s contains invalid value(s) not in %s lookup table: %s', ...
            field_name, upper(table_name), invalid_str), 'error');
end