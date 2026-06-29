function platform_rules(data, collector, config)
    % PLATFORM_RULES Validate PLATFORM field against lookup table
    %
    % Inputs:
    %   data      - Table with survey data
    %   collector - ErrorCollector instance
    %   config    - Configuration struct

    if ~ismember('PLATFORM', data.Properties.VariableNames)
        return;
    end

    if isfield(config, 'platform')
        platform_table_path = config.platform.table_path;
    else
        platform_table_path = fullfile('data', 'tables', 'PLATFORM.csv');
    end

    valid_codes = load_platform_codes(platform_table_path);
    if isempty(valid_codes)
        warning('platform_rules:NoCodesLoaded', ...
            'Could not load platform codes from %s - skipping platform validation', ...
            platform_table_path);
        return;
    end

    validate_platform_values(data, collector, valid_codes);
end

function valid_codes = load_platform_codes(platform_table_path)
    valid_codes = [];
    if ~exist(platform_table_path, 'file')
        return;
    end
    try
        platform_table = readtable(platform_table_path, 'TextType', 'string');
        if ismember('Value', platform_table.Properties.VariableNames)
            valid_codes = platform_table.Value;
        elseif ismember('CODE', platform_table.Properties.VariableNames)
            valid_codes = platform_table.CODE;
        elseif width(platform_table) >= 1
            valid_codes = platform_table{:, 1};
        end
        if iscell(valid_codes)
            numeric_codes = cellfun(@(x) str2double(x), valid_codes, 'UniformOutput', false);
            if all(cellfun(@(x) ~isnan(x), numeric_codes))
                valid_codes = cell2mat(numeric_codes);
            end
        elseif isstring(valid_codes)
            numeric_codes = str2double(valid_codes);
            if all(~isnan(numeric_codes))
                valid_codes = numeric_codes;
            end
        end
        if isnumeric(valid_codes)
            valid_codes = valid_codes(~isnan(valid_codes));
        end
    catch ME
        warning('platform_rules:LoadError', 'Error loading platform codes: %s', ME.message);
    end
end

function validate_platform_values(data, collector, valid_codes)
    values = data.PLATFORM;

    if iscell(values)
        numeric_values = cellfun(@(x) str2double(string(x)), values);
        if ~all(isnan(numeric_values(~cellfun(@isempty, values))))
            values = numeric_values;
        end
    elseif isstring(values)
        numeric_values = str2double(values);
        if ~all(isnan(numeric_values(~ismissing(values))))
            values = numeric_values;
        end
    end

    if isnumeric(values)
        non_null_idx = find(~isnan(values) & ~ismissing(values));
    elseif iscell(values)
        non_null_idx = find(~cellfun(@isempty, values) & ~cellfun(@(x) all(ismissing(x)), values));
    elseif isstring(values)
        non_null_idx = find(~ismissing(values) & strlength(values) > 0);
    else
        non_null_idx = [];
    end

    if isempty(non_null_idx)
        return;
    end

    if isnumeric(values) && isnumeric(valid_codes)
        invalid_idx = non_null_idx(~ismember(values(non_null_idx), valid_codes));
    elseif isnumeric(values) && ~isnumeric(valid_codes)
        valid_numeric = str2double(string(valid_codes));
        valid_numeric = valid_numeric(~isnan(valid_numeric));
        invalid_idx   = non_null_idx(~ismember(values(non_null_idx), valid_numeric));
    else
        values_str  = string(values(non_null_idx));
        valid_str   = string(valid_codes);
        invalid_idx = non_null_idx(~ismember(values_str, valid_str));
    end

    if ~isempty(invalid_idx)
        invalid_values = unique(values(invalid_idx));
        if isnumeric(invalid_values)
            invalid_str = mat2str(invalid_values(:)');
        else
            invalid_values = string(invalid_values);
            invalid_values = invalid_values(~ismissing(invalid_values));
            if length(invalid_values) <= 5
                invalid_str = strjoin(invalid_values, ', ');
            else
                invalid_str = sprintf('%s, ... (%d unique values)', ...
                    strjoin(invalid_values(1:3), ', '), length(invalid_values));
            end
        end
        collector.addError('PLATFORM', invalid_idx, ...
            sprintf('PLATFORM contains invalid value(s) not in lookup table: %s', invalid_str), ...
            'error', 'platform_rules.platform_invalid');
    end
end
