function datetime_rules(data, collector, config)
    % DATETIME_RULES Validate date and time fields
    %
    % Inputs:
    %   data - Table with survey data
    %   collector - ErrorCollector instance
    %   config - Configuration struct (optional)
    
    % Get default config from centralized source
    if nargin < 3 || isempty(config)
        full_config = get_config('validation');
        config = full_config.datetime;
    elseif isfield(config, 'datetime')
        config = config.datetime;
    end

    
    % Validate YEAR
    if ismember('YEAR', data.Properties.VariableNames)
        validate_year(data, collector, config);
    end
    
    % Validate MONTH
    if ismember('MONTH', data.Properties.VariableNames)
        validate_month(data, collector, config);
    end
    
    % Validate DAY
    if ismember('DAY', data.Properties.VariableNames)
        validate_day(data, collector, config);
    end
    
    % Validate TIME
    if ismember('TIME', data.Properties.VariableNames)
        validate_time(data, collector, config);
    end
    
    % Validate complete dates
    if ismember('YEAR', data.Properties.VariableNames) && ...
       ismember('MONTH', data.Properties.VariableNames) && ...
       ismember('DAY', data.Properties.VariableNames)
        validate_date_combination(data, collector, config);
    end
end

function validate_year(data, collector, config)
    % Validate YEAR field
    
    invalid_idx = find(data.YEAR < config.year_min | data.YEAR > config.year_max);
    
    if ~isempty(invalid_idx)
        collector.addError('YEAR', invalid_idx, ...
            sprintf('YEAR outside valid range [%d, %d]', config.year_min, config.year_max), ...
            'error');
    end
    
    % Warning for very old data
    old_idx = find(data.YEAR < config.year_warning);
    if ~isempty(old_idx)
        collector.addError('YEAR', old_idx, ...
            sprintf('YEAR before %d - verify data quality', config.year_warning), ...
            'warning');
    end
end

function validate_month(data, collector, config)
    % Validate MONTH field (CHECK CONSTRAINT: 1-12)
    
    invalid_idx = find(data.MONTH < 1 | data.MONTH > 12);
    
    if ~isempty(invalid_idx)
        collector.addError('MONTH', invalid_idx, ...
            'MONTH must be between 1 and 12', 'error');
    end
end

function validate_day(data, collector, config)
    % Validate DAY field (CHECK CONSTRAINT: <= 31)
    
    invalid_idx = find(data.DAY < 1 | data.DAY > 31);
    
    if ~isempty(invalid_idx)
        collector.addError('DAY', invalid_idx, ...
            'DAY must be between 1 and 31', 'error');
    end
end

function validate_time(data, collector, config)
    % Validate TIME field (CHECK CONSTRAINT: < 240000)
    
    % Time should be in HHMMSS format
    invalid_range = find(data.TIME < 0 | data.TIME >= 240000);
    
    if ~isempty(invalid_range)
        collector.addError('TIME', invalid_range, ...
            'TIME must be in HHMMSS format (< 240000)', 'error');
    end
    
    % Validate HHMMSS format components
    hours = floor(data.TIME / 10000);
    minutes = floor(mod(data.TIME, 10000) / 100);
    seconds = mod(data.TIME, 100);
    
    invalid_hours = find(hours >= 24);
    if ~isempty(invalid_hours)
        collector.addError('TIME', invalid_hours, ...
            'TIME has invalid hours (>=24)', 'error');
    end
    
    invalid_minutes = find(minutes >= 60);
    if ~isempty(invalid_minutes)
        collector.addError('TIME', invalid_minutes, ...
            'TIME has invalid minutes (>=60)', 'error');
    end
    
    invalid_seconds = find(seconds >= 60);
    if ~isempty(invalid_seconds)
        collector.addError('TIME', invalid_seconds, ...
            'TIME has invalid seconds (>=60)', 'error');
    end
end

function validate_date_combination(data, collector, config)
    % Validate that YEAR/MONTH/DAY form valid dates
    
    valid_idx = find(~isnan(data.YEAR) & ~isnan(data.MONTH) & ~isnan(data.DAY));
    
    for i = 1:length(valid_idx)
        idx = valid_idx(i);
        
        try
            % Try to create a datetime - will fail for invalid dates
            datetime(data.YEAR(idx), data.MONTH(idx), data.DAY(idx));
        catch
            collector.addError('YEAR/MONTH/DAY', idx, ...
                sprintf('Invalid date: %d-%02d-%02d', ...
                data.YEAR(idx), data.MONTH(idx), data.DAY(idx)), ...
                'error');
        end
    end
end

function config = default_config()
    % Default configuration for datetime validation
    
    config.year_min = 1970;
    config.year_max = year(datetime('now')) + 1;  % Allow next year
    config.year_warning = 1990;  % Warn for data before 1990
end