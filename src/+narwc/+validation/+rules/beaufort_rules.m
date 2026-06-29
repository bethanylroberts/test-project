function beaufort_rules(data, collector, config)
    % BEAUFORT_RULES Validate Beaufort scale (FK constraint)
    %
    % Inputs:
    %   data - Table with survey data
    %   collector - ErrorCollector instance
    %   config - Configuration struct

    if isfield(config, 'beaufort')
        config = config.beaufort;
    elseif isfield(config, 'environmental') && isfield(config.environmental, 'beaufort_values')
        config = struct('valid_values', config.environmental.beaufort_values);
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
