function coordinate_rules(data, collector, config)
    % COORDINATE_RULES Validate coordinate fields
    %
    % Inputs:
    %   data - Table with survey data
    %   collector - ErrorCollector instance
    %   config - Configuration struct (optional)
    %
    % Usage:
    %   collector = narwc.validation.ErrorCollector();
    %   narwc.validation.rules.coordinate_rules(data, collector);
    
    % Get default config from centralized source
    if nargin < 3 || isempty(config)
        full_config = get_config('validation');
        config = full_config.coordinates;
    elseif isfield(config, 'coordinates')
        % Config passed is the full validation config - extract coordinates
        config = config.coordinates;
    end

    % Validate latitude
    if ismember('LAT_DD', data.Properties.VariableNames)
        validate_latitude(data, collector, config);
    end
    
    % Validate longitude
    if ismember('LONG_DD', data.Properties.VariableNames)
        validate_longitude(data, collector, config);
    end
    
    % Validate coordinate pairs
    if ismember('LAT_DD', data.Properties.VariableNames) && ...
       ismember('LONG_DD', data.Properties.VariableNames)
        validate_coordinate_pairs(data, collector, config);
    end
end

function validate_latitude(data, collector, config)
    % Validate latitude values
    
    lat = data.LAT_DD;
    
    % Check for missing values
    missing_idx = find(ismissing(lat));
    if ~isempty(missing_idx)
        collector.addError('LAT_DD', missing_idx, ...
            'Missing latitude value', 'error');
    end
    
    % Check range
    out_of_range = find(lat < config.lat_min | lat > config.lat_max);
    if ~isempty(out_of_range)
        collector.addError('LAT_DD', out_of_range, ...
            sprintf('Latitude out of valid range [%.1f, %.1f]', ...
            config.lat_min, config.lat_max), 'error');
    end
    
    % Check for typical survey area
    outside_survey = find(lat < config.survey_lat_min | lat > config.survey_lat_max);
    if ~isempty(outside_survey)
        collector.addError('LAT_DD', outside_survey, ...
            sprintf('Latitude outside typical survey area [%.1f, %.1f]', ...
            config.survey_lat_min, config.survey_lat_max), 'warning');
    end
end

function validate_longitude(data, collector, config)
    % Validate longitude values
    
    lon = data.LONG_DD;
    
    % Check for missing values
    missing_idx = find(ismissing(lon));
    if ~isempty(missing_idx)
        collector.addError('LONG_DD', missing_idx, ...
            'Missing longitude value', 'error');
    end
    
    % Check range
    out_of_range = find(lon < config.lon_min | lon > config.lon_max);
    if ~isempty(out_of_range)
        collector.addError('LONG_DD', out_of_range, ...
            sprintf('Longitude out of valid range [%.1f, %.1f]', ...
            config.lon_min, config.lon_max), 'error');
    end
    
    % Check for typical survey area
    outside_survey = find(lon < config.survey_lon_min | lon > config.survey_lon_max);
    if ~isempty(outside_survey)
        collector.addError('LONG_DD', outside_survey, ...
            sprintf('Longitude outside typical survey area [%.1f, %.1f]', ...
            config.survey_lon_min, config.survey_lon_max), 'warning');
    end
end

function validate_coordinate_pairs(data, collector, config)
    % Validate coordinate pairs (both present, valid together)
    
    lat = data.LAT_DD;
    lon = data.LONG_DD;
    
    % Check for one present but not the other
    lat_missing = ismissing(lat);
    lon_missing = ismissing(lon);
    
    mismatch = find(xor(lat_missing, lon_missing));
    if ~isempty(mismatch)
        collector.addError('LAT_DD/LONG_DD', mismatch, ...
            'One coordinate present but not the other', 'error');
    end
    
    % Check if coordinates are on land (if config has land check)
    if isfield(config, 'check_land') && config.check_land
        % TODO: Implement land/sea check
        % For now, skip
    end
end

function config = default_config()
    % Default configuration for coordinate validation
    
    config.lat_min = -90;
    config.lat_max = 90;
    config.lon_min = -180;
    config.lon_max = 180;
    
    % Typical North Atlantic Right Whale survey area
    config.survey_lat_min = 35;
    config.survey_lat_max = 50;
    config.survey_lon_min = -75;
    config.survey_lon_max = -60;
    
    config.check_land = false;
end