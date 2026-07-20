function [data_out, tracker] = calculate_derived_fields(data_in, tracker, config)
    % CALCULATE_DERIVED_FIELDS Calculate derived fields
    %
    % Calculates fields that can be derived from others

    % FIXME: I will not use this on the upload. Might on downloads though
    
    if nargin < 3
        config = struct();
    end
    
    data_out = data_in;
    
    % Calculate day of year
    if ismember('YEAR', data_out.Properties.VariableNames) && ...
       ismember('MONTH', data_out.Properties.VariableNames) && ...
       ismember('DAY', data_out.Properties.VariableNames)
        
        if ~ismember('DAY_OF_YEAR', data_out.Properties.VariableNames)
            data_out.DAY_OF_YEAR = nan(height(data_out), 1);
        end
        
        for i = 1:height(data_out)
            if ~isnan(data_out.YEAR(i)) && ~isnan(data_out.MONTH(i)) && ~isnan(data_out.DAY(i))
                try
                    dt = datetime(data_out.YEAR(i), data_out.MONTH(i), data_out.DAY(i));
                    data_out.DAY_OF_YEAR(i) = day(dt, 'dayofyear');
                    
                    tracker.recordChange('calculate_derived_fields', i, ...
                        'DAY_OF_YEAR', [], data_out.DAY_OF_YEAR(i), ...
                        'Calculated day of year');
                catch
                    % Invalid date, skip
                end
            end
        end
    end
    
    % Calculate distance from previous point (if sequential)
    if ismember('LAT_DD', data_out.Properties.VariableNames) && ...
       ismember('LONG_DD', data_out.Properties.VariableNames)
        
        if ~ismember('DISTANCE_KM', data_out.Properties.VariableNames)
            data_out.DISTANCE_KM = nan(height(data_out), 1);
        end
        
        for i = 2:height(data_out)
            if ~isnan(data_out.LAT_DD(i)) && ~isnan(data_out.LONG_DD(i)) && ...
               ~isnan(data_out.LAT_DD(i-1)) && ~isnan(data_out.LONG_DD(i-1))
                
                % Haversine distance
                dist = haversine_distance(data_out.LAT_DD(i-1), data_out.LONG_DD(i-1), ...
                                         data_out.LAT_DD(i), data_out.LONG_DD(i));
                data_out.DISTANCE_KM(i) = dist;
                
                tracker.recordChange('calculate_derived_fields', i, ...
                    'DISTANCE_KM', [], dist, 'Calculated distance from previous point');
            end
        end
    end
end

function dist_km = haversine_distance(lat1, lon1, lat2, lon2)
    % HAVERSINE_DISTANCE Calculate great circle distance
    R = 6371;  % Earth radius in km
    
    lat1_rad = deg2rad(lat1);
    lat2_rad = deg2rad(lat2);
    delta_lat = deg2rad(lat2 - lat1);
    delta_lon = deg2rad(lon2 - lon1);
    
    a = sin(delta_lat/2)^2 + cos(lat1_rad) * cos(lat2_rad) * sin(delta_lon/2)^2;
    c = 2 * atan2(sqrt(a), sqrt(1-a));
    
    dist_km = R * c;
end