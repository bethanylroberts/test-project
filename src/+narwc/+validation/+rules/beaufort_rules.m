function beaufort_rules(data, collector, config)
    % BEAUFORT_RULES Validate Beaufort scale (FK constraint)
    %
    % Inputs:
    %   data - Table with survey data
    %   collector - ErrorCollector instance
    %   config - Configuration struct (optional)
    
    % Get default config from centralized source
    if nargin < 3 || isempty(config)
        full_config = get_config('validation');
        config = full_config.environmental;  % beaufort is in environmental
    elseif isfield(config, 'environmental')
        config = config.environmental;
    end

    
    % Ensure config has the field we need
    if ~isfield(config, 'valid_values')
        config = default_config();
    end
    
    if ~ismember('BEAUFORT', data.Properties.VariableNames)
        return;
    end
    
    % Find non-null values
    non_null_idx = find(~isnan(data.BEAUFORT) & ~ismissing(data.BEAUFORT));
    
    if isempty(non_null_idx)
        return;
    end
    
    % Check against valid values
    invalid_idx = non_null_idx(~ismember(data.BEAUFORT(non_null_idx), config.valid_values));
    
    if ~isempty(invalid_idx)
        collector.addError('BEAUFORT', invalid_idx, ...
            sprintf('BEAUFORT must be %d-%d (Beaufort wind scale)', ...
            min(config.valid_values), max(config.valid_values)), ...
            'error');
    end
end

function config = default_config()
    % Default configuration for Beaufort validation
    
    % Beaufort scale: 0 (calm) to 12 (hurricane)
    config.valid_values = 0:12;
end