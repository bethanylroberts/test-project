function environmental_rules(data, collector, config)
    % ENVIRONMENTAL_RULES Validate environmental condition fields
    %
    % Inputs:
    %   data - Table with survey data
    %   collector - ErrorCollector instance
    %   config - Configuration struct

    if isfield(config, 'environmental')
        config = config.environmental;
    end

    if ismember('VISIBLTY', data.Properties.VariableNames)
        validate_visibility(data, collector, config);
    end

    if ismember('SURFTEMP', data.Properties.VariableNames)
        validate_surftemp(data, collector, config);
    end
end

function validate_visibility(data, collector, config)
    if ~config.visibility_allow_negative
        negative_idx = find(data.VISIBLTY < 0);
        if ~isempty(negative_idx)
            collector.addError('VISIBLTY', negative_idx, ...
                'VISIBLTY cannot be negative', 'error', ...
                'environmental_rules.visibility_negative');
        end
    end

    too_high = find(data.VISIBLTY > config.visibility_max);
    for i = 1:length(too_high)
        row = too_high(i);
        eventno = get_eventno(data, row);
        collector.addError('VISIBLTY', row, ...
            sprintf('VISIBLTY >%.0f - unusually high', config.visibility_max), ...
            'warning', 'environmental_rules.visibility_too_high', eventno);
    end
end

function validate_surftemp(data, collector, config)
    too_cold = find(data.SURFTEMP < config.surftemp_min);
    for i = 1:length(too_cold)
        row = too_cold(i);
        eventno = get_eventno(data, row);
        collector.addError('SURFTEMP', row, ...
            sprintf('SURFTEMP <%.0f°C - below typical ocean minimum', config.surftemp_min), ...
            'warning', 'environmental_rules.surftemp_too_cold', eventno);
    end

    too_hot = find(data.SURFTEMP > config.surftemp_max);
    for i = 1:length(too_hot)
        row = too_hot(i);
        eventno = get_eventno(data, row);
        collector.addError('SURFTEMP', row, ...
            sprintf('SURFTEMP >%.0f°C - above typical ocean maximum', config.surftemp_max), ...
            'warning', 'environmental_rules.surftemp_too_hot', eventno);
    end
end

function eventno = get_eventno(data, row)
    eventno = [];
    if ismember('EVENTNO', data.Properties.VariableNames)
        val = data.EVENTNO(row);
        if isnumeric(val) && ~isnan(val)
            eventno = val;
        end
    end
end
