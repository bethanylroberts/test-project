function required_fields(data, collector, config)
    % REQUIRED_FIELDS Validate required NOT NULL fields
    %
    % Inputs:
    %   data - Table with survey data
    %   collector - ErrorCollector instance
    %   config - Configuration struct (optional)

    if nargin < 3 || isempty(config)
        full_config = get_config('validation');
        fields_to_check = full_config.required_fields;
    elseif isfield(config, 'required_fields') && iscell(config.required_fields)
        fields_to_check = config.required_fields;
    elseif iscell(config)
        fields_to_check = config;
    else
        fields_to_check = {'LAT_DD', 'LON_DD', 'YEAR', 'MONTH', 'DAY'};
    end

    for i = 1:length(fields_to_check)
        field = fields_to_check{i};

        if ~ismember(field, data.Properties.VariableNames)
            collector.addError(field, [], ...
                sprintf('Required field %s is missing', field), 'error', ...
                'required_fields.column_missing');
            continue;
        end

        if isnumeric(data.(field))
            invalid_idx = find(isnan(data.(field)));
        elseif iscellstr(data.(field)) || isstring(data.(field)) %#ok<ISCLSTR>
            invalid_idx = find(cellfun(@isempty, data.(field)) | ismissing(data.(field)));
        else
            invalid_idx = find(ismissing(data.(field)));
        end

        if ~isempty(invalid_idx)
            collector.addError(field, invalid_idx, ...
                sprintf('Required field %s cannot be NULL or empty', field), 'error', ...
                'required_fields.value_missing');
        end
    end
end

function config = default_config() %#ok<DEFNU>
    % FIXME: move to central config file
    % FIXME: these are not accurate
    config.required_fields = {
        'DDSOURCE'
        'EVENTNO'
        'FILEID'
        'IDSOURCE'
        'YEAR'
    };
end
