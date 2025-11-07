function [data_out, tracker] = standardize_coordinates(data_in, tracker, config)
    % STANDARDIZE_COORDINATES Standardize coordinate formats
    %
    % Ensures coordinates are in decimal degrees with proper precision
    
    if nargin < 3
        config = struct();
        config.decimal_places = 6;  % ~0.1 meter precision
    end
    
    data_out = data_in;
    
    % Standardize latitude
    if ismember('LAT_DD', data_out.Properties.VariableNames)
        old_lat = data_out.LAT_DD;
        data_out.LAT_DD = round(data_out.LAT_DD, config.decimal_places);
        
        % Record changes
        changed = old_lat ~= data_out.LAT_DD & ~isnan(old_lat);
        if any(changed)
            changed_rows = find(changed);
            for i = 1:length(changed_rows)
                tracker.recordModification('standardize_coordinates', ...
                    changed_rows(i), 'LAT_DD', ...
                    old_lat(changed_rows(i)), data_out.LAT_DD(changed_rows(i)));
            end
        end
    end
    
    % Standardize longitude
    if ismember('LONG_DD', data_out.Properties.VariableNames)
        old_lon = data_out.LONG_DD;
        data_out.LONG_DD = round(data_out.LONG_DD, config.decimal_places);
        
        % Record changes
        changed = old_lon ~= data_out.LONG_DD & ~isnan(old_lon);
        if any(changed)
            changed_rows = find(changed);
            for i = 1:length(changed_rows)
                tracker.recordModification('standardize_coordinates', ...
                    changed_rows(i), 'LONG_DD', ...
                    old_lon(changed_rows(i)), data_out.LONG_DD(changed_rows(i)));
            end
        end
    end
end