function foreign_key_rules(data, collector, config) %#ok<INUSD>
    % FOREIGN_KEY_RULES Validate all fields with foreign key constraints
    %
    % Lookup tables validated:
    %   ANHEAD, Block, Cloud, Confidnc, Contrib, DDSOURCE, DType, GLARE,
    %   IDREL, IDSOURCE, LEGGOOD, LEGSTAGE, LEGTYPE, OLDVIZ, PHOTOS,
    %   PLATFORM, STRATUM, STRIP, WX
    %
    % Inputs:
    %   data      - Table with survey data
    %   collector - ErrorCollector instance
    %   config    - Configuration struct (optional)

    fk_mappings = {
        'ANHEAD',   'anhead'
        'BLOCK',    'block'
        'CLOUD',    'cloud'
        'CONFIDNC', 'confidnc'
        'CONTRIB',  'contrib'
        'DDSOURCE', 'ddsource'
        'DTYPE',    'dtype'
        'GLAREL',   'glare'
        'GLARER',   'glare'
        'IDREL',    'idrel'
        'IDSOURCE', 'idsource'
        'LEGGOOD',  'leggood'
        'LEGSTAGE', 'legstage'
        'LEGTYPE',  'legtype'
        'OLDVIZ',   'oldviz'
        'PHOTOS',   'photos'
        'PLATFORM', 'platform'
        'STRATUM',  'stratum'
        'STRIP',    'strip'
        'WX',       'wx'
    };

    lookup_cache = containers.Map();

    for i = 1:size(fk_mappings, 1)
        field_name = fk_mappings{i, 1};
        table_name = fk_mappings{i, 2};

        if ~ismember(field_name, data.Properties.VariableNames)
            continue;
        end

        if isKey(lookup_cache, table_name)
            valid_codes = lookup_cache(table_name);
        else
            valid_codes = load_valid_codes(table_name);
            lookup_cache(table_name) = valid_codes;
        end

        if isempty(valid_codes)
            continue;
        end

        validate_field(data, collector, field_name, valid_codes, table_name);
    end
end

%% =========================================================================

function valid_codes = load_valid_codes(table_name)
    valid_codes = [];
    try
        lookup_table = get_lookup_table(table_name);
        if isempty(lookup_table) || height(lookup_table) == 0
            warning('foreign_key_rules:EmptyTable', ...
                'Lookup table %s is empty or not found', upper(table_name));
            return;
        end
        if ismember('Value', lookup_table.Properties.VariableNames)
            valid_codes = lookup_table.Value;
        else
            valid_codes = lookup_table{:, 1};
        end
        valid_codes = standardize_codes(valid_codes);
    catch ME
        warning('foreign_key_rules:LoadError', ...
            'Failed to load %s lookup table: %s', upper(table_name), ME.message);
    end
end

function codes = standardize_codes(codes)
    if isempty(codes)
        return;
    end
    if iscell(codes)
        codes = codes(~cellfun(@isempty, codes));
        numeric_codes = cellfun(@(x) str2double(string(x)), codes, 'UniformOutput', true);
        if all(~isnan(numeric_codes))
            codes = numeric_codes;
        else
            codes = strtrim(string(codes));
        end
        return;
    end
    if isstring(codes)
        codes = codes(~ismissing(codes) & strlength(codes) > 0);
        numeric_codes = str2double(codes);
        if all(~isnan(numeric_codes))
            codes = numeric_codes;
        else
            codes = strtrim(codes);
        end
        return;
    end
    if isnumeric(codes)
        codes = codes(~isnan(codes));
    end
end

function validate_field(data, collector, field_name, valid_codes, table_name)
    values = data.(field_name);
    [non_null_idx, values_to_check] = get_non_null_values(values, valid_codes);
    if isempty(non_null_idx)
        return;
    end

    if isnumeric(values_to_check) && isnumeric(valid_codes)
        invalid_mask = ~ismember(values_to_check, valid_codes);
    elseif isnumeric(valid_codes)
        numeric_values = convert_to_numeric(values_to_check);
        if ~isempty(numeric_values)
            invalid_mask = ~ismember(numeric_values, valid_codes);
        else
            invalid_mask = true(size(values_to_check));
        end
    else
        values_str = upper(strtrim(string(values_to_check)));
        valid_str  = upper(strtrim(string(valid_codes)));
        invalid_mask = ~ismember(values_str, valid_str);
    end

    invalid_idx = non_null_idx(invalid_mask);
    if ~isempty(invalid_idx)
        report_invalid_values(collector, field_name, table_name, ...
            values_to_check, invalid_mask, invalid_idx);
    end
end

function [non_null_idx, values_to_check] = get_non_null_values(values, valid_codes)
    non_null_idx    = [];
    values_to_check = [];

    if isnumeric(values)
        non_null_idx    = find(~isnan(values) & ~ismissing(values));
        values_to_check = values(non_null_idx);
    elseif iscell(values)
        non_null_idx = find(~cellfun(@isempty, values) & ...
                           ~cellfun(@(x) all(ismissing(x)), values));
        if ~isempty(non_null_idx)
            values_to_check = values(non_null_idx);
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
        if all(isnan(numeric_values))
            numeric_values = [];
        end
    catch
        numeric_values = [];
    end
end

function report_invalid_values(collector, field_name, table_name, values, invalid_mask, invalid_idx)
    MAX_ROWS_TO_REPORT  = 5;
    MAX_VALUES_TO_SHOW  = 5;

    invalid_values       = values(invalid_mask);
    total_invalid_rows   = length(invalid_idx);

    if total_invalid_rows > MAX_ROWS_TO_REPORT
        reported_idx = invalid_idx(1:MAX_ROWS_TO_REPORT);
        rows_note    = sprintf(' (+%d more rows)', total_invalid_rows - MAX_ROWS_TO_REPORT);
    else
        reported_idx = invalid_idx;
        rows_note    = '';
    end

    if isnumeric(invalid_values)
        valid_values   = invalid_values(~isnan(invalid_values));
        unique_invalid = unique(valid_values, 'stable');
        if length(unique_invalid) <= MAX_VALUES_TO_SHOW
            invalid_str = mat2str(unique_invalid(:)');
        else
            invalid_str = sprintf('%s ... (+%d more values)', ...
                mat2str(unique_invalid(1:MAX_VALUES_TO_SHOW)'), ...
                length(unique_invalid) - MAX_VALUES_TO_SHOW);
        end
    else
        str_values     = string(invalid_values);
        str_values     = str_values(~ismissing(str_values));
        unique_invalid = unique(str_values, 'stable');
        if length(unique_invalid) <= MAX_VALUES_TO_SHOW
            invalid_str = strjoin(unique_invalid, ', ');
        else
            invalid_str = sprintf('%s ... (+%d more values)', ...
                strjoin(unique_invalid(1:MAX_VALUES_TO_SHOW), ', '), ...
                length(unique_invalid) - MAX_VALUES_TO_SHOW);
        end
    end

    msg = sprintf('%s contains invalid value(s) not in %s lookup table: %s%s', ...
        field_name, upper(table_name), invalid_str, rows_note);

    rule_id = sprintf('foreign_key_rules.%s_invalid', lower(field_name));
    collector.addError(field_name, reported_idx, msg, 'error', rule_id);
end
