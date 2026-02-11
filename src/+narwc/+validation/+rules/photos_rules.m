function photos_rules(data, collector, config)
    % PHOTOS_RULES Validate PHOTOS field against lookup table
    %
    % Validates that PHOTOS values exist in the PHOTOS lookup table.
    % This is a foreign key constraint in the database.
    %
    % Valid values (from PHOTOS.csv):
    %   1 = NO
    %   2 = YES, SLIDES OR PRINTS (INCLUDING DIGITAL)
    %   3 = YES, CINE
    %   4 = YES, VIDEO
    %   5 = YES, MORE THAN ONE TYPE
    %
    % Inputs:
    %   data      - Table with survey data
    %   collector - ErrorCollector instance
    %   config    - Configuration struct (optional)
    
    field_name = 'PHOTOS';
    lookup_table_name = 'photos';
    
    % Check if field exists
    if ~ismember(field_name, data.Properties.VariableNames)
        return;
    end
    
    % Load valid codes from lookup table
    valid_codes = load_lookup_codes(lookup_table_name);
    if isempty(valid_codes)
        warning('photos_rules:NoCodesLoaded', ...
            'Could not load codes from %s lookup table - skipping validation', ...
            upper(lookup_table_name));
        return;
    end
    
    % Validate field values
    validate_foreign_key_field(data, collector, field_name, valid_codes, lookup_table_name);
end

function valid_codes = load_lookup_codes(table_name)
    % Load valid codes from lookup table
    
    valid_codes = [];
    
    try
        lookup_table = get_lookup_table(table_name);
        
        if isempty(lookup_table)
            return;
        end
        
        % Get values from first column or 'Value' column
        if ismember('Value', lookup_table.Properties.VariableNames)
            valid_codes = lookup_table.Value;
        else
            valid_codes = lookup_table{:, 1};
        end
        
        % Ensure numeric if appropriate
        if iscell(valid_codes)
            numeric_test = cellfun(@(x) str2double(string(x)), valid_codes);
            if all(~isnan(numeric_test))
                valid_codes = numeric_test;
            end
        elseif isstring(valid_codes)
            numeric_test = str2double(valid_codes);
            if all(~isnan(numeric_test))
                valid_codes = numeric_test;
            end
        end
        
    catch ME
        warning('load_lookup_codes:Error', 'Failed to load %s: %s', table_name, ME.message);
    end
end

function validate_foreign_key_field(data, collector, field_name, valid_codes, table_name)
    % Generic validation for foreign key fields
    
    values = data.(field_name);
    
    % Determine data type and find non-null indices
    if isnumeric(values)
        non_null_idx = find(~isnan(values) & ~ismissing(values));
        values_to_check = values(non_null_idx);
    elseif iscell(values)
        non_null_idx = find(~cellfun(@isempty, values) & ...
                           ~cellfun(@(x) all(ismissing(x)), values));
        values_to_check = values(non_null_idx);
        % Try numeric conversion if valid_codes is numeric
        if isnumeric(valid_codes)
            numeric_vals = cellfun(@(x) str2double(string(x)), values_to_check);
            if ~all(isnan(numeric_vals))
                values_to_check = numeric_vals;
            end
        end
    elseif isstring(values)
        non_null_idx = find(~ismissing(values) & strlength(values) > 0);
        values_to_check = values(non_null_idx);
        % Try numeric conversion if valid_codes is numeric
        if isnumeric(valid_codes)
            numeric_vals = str2double(values_to_check);
            if ~all(isnan(numeric_vals))
                values_to_check = numeric_vals;
            end
        end
    else
        return;
    end
    
    if isempty(non_null_idx)
        return;
    end
    
    % Find invalid values
    invalid_mask = ~ismember(values_to_check, valid_codes);
    invalid_idx = non_null_idx(invalid_mask);
    
    if ~isempty(invalid_idx)
        invalid_values = unique(values_to_check(invalid_mask));
        
        % Format for display
        if isnumeric(invalid_values)
            invalid_str = mat2str(invalid_values(:)');
        else
            invalid_values = string(invalid_values);
            if length(invalid_values) <= 5
                invalid_str = strjoin(invalid_values, ', ');
            else
                invalid_str = sprintf('%s... (%d total)', ...
                    strjoin(invalid_values(1:3), ', '), length(invalid_values));
            end
        end
        
        collector.addError(field_name, invalid_idx, ...
            sprintf('%s contains invalid value(s) not in %s lookup table: %s', ...
                field_name, upper(table_name), invalid_str), 'error');
    end
end