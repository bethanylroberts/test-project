function _template_rules(data, collector, config)
    % TEMPLATE_RULES Validate template field against lookup table
    %
    % Validates that template values exist in the template lookup table.
    % This is a foreign key constraint in the database.
    %
    % Inputs:
    %   data      - Table with survey data
    %   collector - ErrorCollector instance
    %   config    - Configuration struct (optional)
    
    % =====================================================================
    % CONFIGURE THESE FOR EACH FIELD:
    % =====================================================================
    field_name = 'template';           % Database column name
    lookup_table_name = 'template';    % Lookup table name (lowercase)
    % =====================================================================


    % TODO: Add to SurveyValidator.m - when a new template is made, it needs to
    % be added to to the list before it is run

    % matlab
    % if obj.config.validate_template
    %     obj.logger.debug('Validating template field...');
    %     narwc.validation.rules.template_rules(data, obj.collector);
    % end

    % Add flag to defaultConfig:

    % matlab
    % config.validate_template = true;


    
    % Check if field exists
    if ~ismember(field_name, data.Properties.VariableNames)
        return;
    end
    
    % Load valid codes from lookup table
    valid_codes = load_lookup_codes(lookup_table_name);
    if isempty(valid_codes)
        warning('%s_rules:NoCodesLoaded', lower(field_name), ...
            'Could not load codes from %s lookup table - skipping validation', ...
            upper(lookup_table_name));
        return;
    end
    
    % Validate field values
    validate_fk_field(data, collector, field_name, valid_codes, lookup_table_name);
end

function valid_codes = load_lookup_codes(table_name)
    % Load valid codes from lookup table
    
    valid_codes = [];
    
    try
        lookup_table = get_lookup_table(table_name);
        
        if isempty(lookup_table)
            return;
        end
        
        % Get values from 'Value' column or first column
        if ismember('Value', lookup_table.Properties.VariableNames)
            valid_codes = lookup_table.Value;
        else
            valid_codes = lookup_table{:, 1};
        end
        
        % Convert to numeric if all values are numeric
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

function validate_fk_field(data, collector, field_name, valid_codes, table_name)
    % Generic validation for foreign key fields
    
    values = data.(field_name);
    
    % Handle different data types
    if isnumeric(values)
        non_null_idx = find(~isnan(values) & ~ismissing(values));
        values_to_check = values(non_null_idx);
    elseif iscell(values)
        non_null_idx = find(~cellfun(@isempty, values) & ...
                           ~cellfun(@(x) all(ismissing(x)), values));
        values_to_check = values(non_null_idx);
        if isnumeric(valid_codes)
            numeric_vals = cellfun(@(x) str2double(string(x)), values_to_check);
            if ~all(isnan(numeric_vals))
                values_to_check = numeric_vals;
            end
        end
    elseif isstring(values)
        non_null_idx = find(~ismissing(values) & strlength(values) > 0);
        values_to_check = values(non_null_idx);
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