function your_existing_rule(data, collector, config)
    % PORT YOUR EXISTING LOGIC HERE
    
    % Example: If you had something like:
    % invalid_lat = data.LAT_DD < 35 | data.LAT_DD > 50;
    
    % Convert to:
    invalid_idx = find(data.LAT_DD < config.survey_lat_min | ...
                       data.LAT_DD > config.survey_lat_max);
    
    if ~isempty(invalid_idx)
        collector.addError('LAT_DD', invalid_idx, ...
            'Latitude outside survey area', 'warning');
    end
end