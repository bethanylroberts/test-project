function coordinate_rules(data, collector, config)
    % COORDINATE_RULES Validate coordinate fields
    %
    % Inputs:
    %   data - Table with survey data
    %   collector - ErrorCollector instance
    %   config - Configuration struct (optional)

    if nargin < 3 || isempty(config)
        full_config = get_config('validation');
        config = full_config.coordinates;
    elseif isfield(config, 'coordinates')
        config = config.coordinates;
    end

    if ismember('LAT_DD', data.Properties.VariableNames)
        validate_latitude(data, collector, config);
    end

    if ismember('LONG_DD', data.Properties.VariableNames)
        validate_longitude(data, collector, config);
    end

    if ismember('LAT_DD', data.Properties.VariableNames) && ...
       ismember('LONG_DD', data.Properties.VariableNames)
        validate_coordinate_pairs(data, collector, config);
    end
end

function validate_latitude(data, collector, config)
    lat = data.LAT_DD;

    missing_idx = find(ismissing(lat));
    if ~isempty(missing_idx)
        collector.addError('LAT_DD', missing_idx, ...
            'Missing latitude value', 'error', ...
            'coordinate_rules.lat_missing');
    end

    out_of_range = find(lat < config.lat_min | lat > config.lat_max);
    if ~isempty(out_of_range)
        collector.addError('LAT_DD', out_of_range, ...
            sprintf('Latitude out of valid range [%.1f, %.1f]', ...
            config.lat_min, config.lat_max), 'error', ...
            'coordinate_rules.lat_out_of_range');
    end

    outside_survey = find(lat < config.survey_lat_min | lat > config.survey_lat_max);
    for i = 1:length(outside_survey)
        row = outside_survey(i);
        eventno = get_eventno(data, row);
        collector.addError('LAT_DD', row, ...
            sprintf('Latitude outside typical survey area [%.1f, %.1f]', ...
            config.survey_lat_min, config.survey_lat_max), 'warning', ...
            'coordinate_rules.outside_survey_lat', eventno);
    end
end

function validate_longitude(data, collector, config)
    lon = data.LONG_DD;

    missing_idx = find(ismissing(lon));
    if ~isempty(missing_idx)
        collector.addError('LONG_DD', missing_idx, ...
            'Missing longitude value', 'error', ...
            'coordinate_rules.lon_missing');
    end

    out_of_range = find(lon < config.lon_min | lon > config.lon_max);
    if ~isempty(out_of_range)
        collector.addError('LONG_DD', out_of_range, ...
            sprintf('Longitude out of valid range [%.1f, %.1f]', ...
            config.lon_min, config.lon_max), 'error', ...
            'coordinate_rules.lon_out_of_range');
    end

    outside_survey = find(lon < config.survey_lon_min | lon > config.survey_lon_max);
    for i = 1:length(outside_survey)
        row = outside_survey(i);
        eventno = get_eventno(data, row);
        collector.addError('LONG_DD', row, ...
            sprintf('Longitude outside typical survey area [%.1f, %.1f]', ...
            config.survey_lon_min, config.survey_lon_max), 'warning', ...
            'coordinate_rules.outside_survey_lon', eventno);
    end
end

function validate_coordinate_pairs(data, collector, config) %#ok<INUSD>
    lat = data.LAT_DD;
    lon = data.LONG_DD;

    lat_missing = ismissing(lat);
    lon_missing = ismissing(lon);

    mismatch = find(xor(lat_missing, lon_missing));
    if ~isempty(mismatch)
        collector.addError('LAT_DD/LONG_DD', mismatch, ...
            'One coordinate present but not the other', 'error', ...
            'coordinate_rules.coordinate_pair_mismatch');
    end
end

function eventno = get_eventno(data, row)
    % GET_EVENTNO Extract EVENTNO for a given row, or return [] if unavailable
    eventno = [];
    if ismember('EVENTNO', data.Properties.VariableNames)
        val = data.EVENTNO(row);
        if isnumeric(val) && ~isnan(val)
            eventno = val;
        end
    end
end

function config = default_config() %#ok<DEFNU>
    config.lat_min = -90;
    config.lat_max = 90;
    config.lon_min = -180;
    config.lon_max = 180;
    config.survey_lat_min = 35;
    config.survey_lat_max = 50;
    config.survey_lon_min = -75;
    config.survey_lon_max = -60;
    config.check_land = false;
end
