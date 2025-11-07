function [data_out, tracker] = flag_outliers(data_in, tracker, config)
    % FLAG_OUTLIERS Flag statistical outliers in numeric fields
    %
    % Uses IQR method to flag outliers
    
    if nargin < 3
        config = struct();
        config.fields = {'ALT', 'BEAUFORT', 'NUMBER'};
        config.iqr_multiplier = 3;  % 3*IQR for outliers
    end
    
    % FIXME: check for different fields esp. time series

    data_out = data_in;
    
    % Add QC_FLAGS column if it doesn't exist
    if ~ismember('QC_FLAGS', data_out.Properties.VariableNames)
        data_out.QC_FLAGS = repmat({''}, height(data_out), 1);
    end
    
    for i = 1:length(config.fields)
        field = config.fields{i};
        
        if ~ismember(field, data_out.Properties.VariableNames)
            continue;
        end
        
        values = data_out.(field);
        
        % Skip non-numeric
        if ~isnumeric(values)
            continue;
        end
        
        % Calculate IQR
        valid_values = values(~isnan(values));
        if isempty(valid_values)
            continue;
        end
        
        Q1 = quantile(valid_values, 0.25);
        Q3 = quantile(valid_values, 0.75);
        IQR = Q3 - Q1;
        
        lower_bound = Q1 - config.iqr_multiplier * IQR;
        upper_bound = Q3 + config.iqr_multiplier * IQR;
        
        % Flag outliers
        outliers = values < lower_bound | values > upper_bound;
        outlier_idx = find(outliers);
        
        if ~isempty(outlier_idx)
            for j = 1:length(outlier_idx)
                row = outlier_idx(j);
                
                % Add flag
                current_flags = data_out.QC_FLAGS{row};
                if isempty(current_flags)
                    data_out.QC_FLAGS{row} = sprintf('%s_OUTLIER', field);
                else
                    data_out.QC_FLAGS{row} = sprintf('%s;%s_OUTLIER', ...
                        current_flags, field);
                end
                
                % Record flag
                tracker.recordFlag('flag_outliers', row, 'OUTLIER', ...
                    sprintf('%s value %.2f outside [%.2f, %.2f]', ...
                    field, values(row), lower_bound, upper_bound));
            end
        end
    end
end