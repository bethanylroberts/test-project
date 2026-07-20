function photos_rules(data, collector, config) %#ok<INUSD>
    % PHOTOS_RULES Validate PHOTOS field against lookup table
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

    field_name        = 'PHOTOS';
    lookup_table_name = 'photos';

    if ~ismember(field_name, data.Properties.VariableNames)
        return;
    end

    valid_codes = load_lookup_codes(lookup_table_name);
    if isempty(valid_codes)
        warning('photos_rules:NoCodesLoaded', ...
            'Could not load codes from %s lookup table - skipping validation', ...
            upper(lookup_table_name));
        return;
    end

    validate_foreign_key_field(data, collector, field_name, valid_codes, lookup_table_name);
end

function valid_codes = load_lookup_codes(table_name)
    valid_codes = [];
    try
        lookup_table = get_lookup_table(table_name);
        if isempty(lookup_table)
            return;
        end
        if ismember('Value', lookup_table.Properties.VariableNames)
            valid_codes = lookup_table.Value;
        else
            valid_codes = lookup_table{:, 1};
        end
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
    values = data.(field_name);

    if isnumeric(values)
        non_null_idx    = find(~isnan(values) & ~ismissing(values));
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

    invalid_mask = ~ismember(values_to_check, valid_codes);
    invalid_idx  = non_null_idx(invalid_mask);

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
                field_name, upper(table_name), invalid_str), 'error', ...
            'photos_rules.photos_invalid');
    end
end
