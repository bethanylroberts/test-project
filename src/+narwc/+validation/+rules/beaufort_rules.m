function beaufort_rules(data, collector, config)
    % BEAUFORT_RULES Validate Beaufort scale (FK constraint)
    %
    % Inputs:
    %   data - Table with survey data
    %   collector - ErrorCollector instance
    %   config - Configuration struct (optional)

    if nargin < 3 || isempty(config)
        full_config = get_config('validation');
        config = full_config.environmental;
    elseif isfield(config, 'environmental')
        config = config.environmental;
    end

    if ~isfield(config, 'valid_values')
        config = default_config();
    end

    if ~ismember('BEAUFORT', data.Properties.VariableNames)
        return;
    end

    non_null_idx = find(~isnan(data.BEAUFORT) & ~ismissing(data.BEAUFORT));
    if isempty(non_null_idx)
        return;
    end

    invalid_idx = non_null_idx(~ismember(data.BEAUFORT(non_null_idx), config.valid_values));
    if ~isempty(invalid_idx)
        collector.addError('BEAUFORT', invalid_idx, ...
            sprintf('BEAUFORT must be %d-%d (Beaufort wind scale)', ...
            min(config.valid_values), max(config.valid_values)), ...
            'error', 'beaufort_rules.beaufort_out_of_range');
    end
end

function config = default_config()
    config.valid_values = 0:12;
end
