function datetime_rules(data, collector, config)
    % DATETIME_RULES Validate date and time fields
    %
    % Inputs:
    %   data - Table with survey data
    %   collector - ErrorCollector instance
    %   config - Configuration struct

    if isfield(config, 'datetime')
        config = config.datetime;
    end

    if ismember('YEAR', data.Properties.VariableNames)
        validate_year(data, collector, config);
    end

    if ismember('MONTH', data.Properties.VariableNames)
        validate_month(data, collector, config);
    end

    if ismember('DAY', data.Properties.VariableNames)
        validate_day(data, collector, config);
    end

    if ismember('TIME', data.Properties.VariableNames)
        validate_time(data, collector, config);
    end

    if ismember('YEAR', data.Properties.VariableNames) && ...
       ismember('MONTH', data.Properties.VariableNames) && ...
       ismember('DAY', data.Properties.VariableNames)
        validate_date_combination(data, collector, config);
    end
end

function validate_year(data, collector, config)
    invalid_idx = find(data.YEAR < config.year_min | data.YEAR > config.year_max);
    if ~isempty(invalid_idx)
        collector.addError('YEAR', invalid_idx, ...
            sprintf('YEAR outside valid range [%d, %d]', config.year_min, config.year_max), ...
            'error', 'datetime_rules.year_out_of_range');
    end

    old_idx = find(data.YEAR < config.year_warning);
    for i = 1:length(old_idx)
        row = old_idx(i);
        eventno = get_eventno(data, row);
        collector.addError('YEAR', row, ...
            sprintf('YEAR before %d - verify data quality', config.year_warning), ...
            'warning', 'datetime_rules.year_too_old', eventno);
    end
end

function validate_month(data, collector, config) %#ok<INUSD>
    invalid_idx = find(data.MONTH < 1 | data.MONTH > 16);
    if ~isempty(invalid_idx)
        collector.addError('MONTH', invalid_idx, ...
            'MONTH must be between 1 and 16 (1-12 calendar months, 13-16 season codes)', 'error', 'datetime_rules.month_out_of_range');
    end
end

function validate_day(data, collector, config) %#ok<INUSD>
    invalid_idx = find(data.DAY < 1 | data.DAY > 31);
    if ~isempty(invalid_idx)
        collector.addError('DAY', invalid_idx, ...
            'DAY must be between 1 and 31', 'error', 'datetime_rules.day_out_of_range');
    end
end

function validate_time(data, collector, config) %#ok<INUSD>
    invalid_range = find(data.TIME < 0 | data.TIME >= 240000);
    if ~isempty(invalid_range)
        collector.addError('TIME', invalid_range, ...
            'TIME must be in HHMMSS format (< 240000)', 'error', ...
            'datetime_rules.time_out_of_range');
    end

    hours   = floor(data.TIME / 10000);
    minutes = floor(mod(data.TIME, 10000) / 100);
    seconds = mod(data.TIME, 100);

    invalid_hours = find(hours >= 24);
    if ~isempty(invalid_hours)
        collector.addError('TIME', invalid_hours, ...
            'TIME has invalid hours (>=24)', 'error', 'datetime_rules.time_invalid_hours');
    end

    invalid_minutes = find(minutes >= 60);
    if ~isempty(invalid_minutes)
        collector.addError('TIME', invalid_minutes, ...
            'TIME has invalid minutes (>=60)', 'error', 'datetime_rules.time_invalid_minutes');
    end

    invalid_seconds = find(seconds >= 60);
    if ~isempty(invalid_seconds)
        collector.addError('TIME', invalid_seconds, ...
            'TIME has invalid seconds (>=60)', 'error', 'datetime_rules.time_invalid_seconds');
    end
end

function validate_date_combination(data, collector, config) %#ok<INUSD>
    % Season codes 13-16 are not calendar months; skip datetime check for those rows.
    valid_idx = find(~isnan(data.YEAR) & ~isnan(data.MONTH) & ~isnan(data.DAY) & data.MONTH <= 12);
    for i = 1:length(valid_idx)
        idx = valid_idx(i);
        try
            datetime(data.YEAR(idx), data.MONTH(idx), data.DAY(idx));
        catch
            collector.addError('YEAR/MONTH/DAY', idx, ...
                sprintf('Invalid date: %d-%02d-%02d', ...
                data.YEAR(idx), data.MONTH(idx), data.DAY(idx)), ...
                'error', 'datetime_rules.invalid_date_combination');
        end
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
