function environmental_rules(data, collector, config)
    % ENVIRONMENTAL_RULES Validate environmental condition fields
    %
    % Inputs:
    %   data - Table with survey data
    %   collector - ErrorCollector instance
    %   config - Configuration struct (optional)
    

    % Get default config from centralized source
    if nargin < 3 || isempty(config)
        full_config = get_config('validation');
        config = full_config.environmental;
    elseif isfield(config, 'environmental')
        config = config.environmental;
    end
    
    % Validate cloud cover
    % FIXME: delete, once determined to be wrong
    % if ismember('CLOUD', data.Properties.VariableNames)
    %     validate_cloud(data, collector, config);
    % end
    
    % Validate visibility
    if ismember('VISIBLTY', data.Properties.VariableNames)
        validate_visibility(data, collector, config);
    end
    
    % Validate surface temperature
    if ismember('SURFTEMP', data.Properties.VariableNames)
        validate_surftemp(data, collector, config);
    end
    
    % Validate glare
    if ismember('GLAREL', data.Properties.VariableNames)
        validate_glare(data, collector, 'GLAREL', config);
    end
    if ismember('GLARER', data.Properties.VariableNames)
        validate_glare(data, collector, 'GLARER', config);
    end
    
    % Validate weather code
    if ismember('WX', data.Properties.VariableNames)
        validate_wx(data, collector, config);
    end
end

% FIXME: Look up table fixes this, but this is wrong
% function validate_cloud(data, collector, config)
%     % Validate cloud cover (0-8 oktas)
    
%     non_null_idx = find(~isnan(data.CLOUD) & ~ismissing(data.CLOUD));
    
%     if isempty(non_null_idx)
%         return;
%     end
    
%     invalid_idx = non_null_idx(~ismember(data.CLOUD(non_null_idx), config.cloud_values));
    
%     if ~isempty(invalid_idx)
%         collector.addError('CLOUD', invalid_idx, ...
%             'CLOUD must be 0-8 (oktas)', 'error');
%     end
% end

function validate_visibility(data, collector, config)
    % Validate visibility
    
    % Cannot be negative
    if ~config.visibility_allow_negative
        negative_idx = find(data.VISIBLTY < 0);
        if ~isempty(negative_idx)
            collector.addError('VISIBLTY', negative_idx, ...
                'VISIBLTY cannot be negative', 'error');
        end
    end
    
    % Warn for unusual values
    too_high = find(data.VISIBLTY > config.visibility_max);
    if ~isempty(too_high)
        collector.addError('VISIBLTY', too_high, ...
            sprintf('VISIBLTY >%.0f - unusually high', config.visibility_max), ...
            'warning');
    end
end

function validate_surftemp(data, collector, config)
    % Validate surface temperature (Celsius)
    
    % Out of reasonable ocean range
    too_cold = find(data.SURFTEMP < config.surftemp_min);
    if ~isempty(too_cold)
        collector.addError('SURFTEMP', too_cold, ...
            sprintf('SURFTEMP <%.0f°C - below typical ocean minimum', config.surftemp_min), ...
            'warning');
    end
    
    too_hot = find(data.SURFTEMP > config.surftemp_max);
    if ~isempty(too_hot)
        collector.addError('SURFTEMP', too_hot, ...
            sprintf('SURFTEMP >%.0f°C - above typical ocean maximum', config.surftemp_max), ...
            'warning');
    end
end

function validate_glare(data, collector, field_name, config)
    % Validate glare level (0-3 typically)
    
    non_null_idx = find(~isnan(data.(field_name)) & ~ismissing(data.(field_name)));
    
    if isempty(non_null_idx)
        return;
    end
    
    invalid_idx = non_null_idx(~ismember(data.(field_name)(non_null_idx), config.glare_values));
    
    if ~isempty(invalid_idx)
        collector.addError(field_name, invalid_idx, ...
            sprintf('%s must be 0-3', field_name), 'error');
    end
end

function validate_wx(data, collector, config)
    % Validate weather code (1-char)
    
    if iscellstr(data.WX) || isstring(data.WX)
        too_long = cellfun(@length, data.WX) > 1;
        invalid_idx = find(too_long);
        
        if ~isempty(invalid_idx)
            collector.addError('WX', invalid_idx, ...
                'WX must be 1 character', 'error');
        end
    end
end

function config = default_config()
    % Default configuration for environmental validation
    
    % FIXME: move to a config file location
    config.cloud_values = 0:8;  % Oktas
    config.visibility_max = 50;  % km or nm
    config.visibility_allow_negative = true;
    config.surftemp_min = -2;  % °C (freezing point of seawater)
    config.surftemp_max = 35;  % °C (warm tropical waters)
    config.glare_values = 0:3;  % None to severe
end