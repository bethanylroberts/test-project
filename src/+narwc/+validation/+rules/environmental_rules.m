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
    
    % FIXME: no longer needed. Look up table fixes this 
    % % Validate weather code
    % if ismember('WX', data.Properties.VariableNames)
    %     validate_wx(data, collector, config);
    % end
end

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
    % FIXME: visibility should be limited to only a few negative numbers based on oldviz lookup table

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

% FIXME: not needed. Look up table fixes this
% function validate_wx(data, collector, config)
%     % Validate weather code (1-char)
    
%     if iscellstr(data.WX) || isstring(data.WX)
%         too_long = cellfun(@length, data.WX) > 1;
%         invalid_idx = find(too_long);
        
%         if ~isempty(invalid_idx)
%             collector.addError('WX', invalid_idx, ...
%                 'WX must be 1 character', 'error');
%         end
%     end
% end

function config = default_config()
    % Default configuration for environmental validation
    
    % FIXME: move to a config file location
    config.cloud_values = 0:8;  % Oktas
    config.visibility_max = 50;  % km or nm
    config.visibility_allow_negative = true;
    % FIXME: only legacy surveys should be allowed to be negative
    config.surftemp_min = -2;  % °C (freezing point of seawater)
    config.surftemp_max = 35;  % °C (warm tropical waters)
end