function [data_out, tracker] = remove_duplicates(data_in, tracker, config)
    % REMOVE_DUPLICATES Remove duplicate rows from survey data
    %
    % Inputs:
    %   data_in - Input table
    %   tracker - ChangeTracker instance
    %   config - Configuration struct (optional)
    %
    % Outputs:
    %   data_out - Cleaned table
    %   tracker - Updated tracker
    %
    % Usage:
    %   [data, tracker] = narwc.processing.steps.remove_duplicates(data, tracker);
    
    if nargin < 3
        config = struct();
        config.key_fields = {'FILEID', 'EVENTNO', 'LAT_DD', 'LONG_DD', 'TIME'};
    end
    
    % FIXME: do not use. Duplicates are allowed as long as event number is the same

    % Find duplicates based on key fields
    fields_present = config.key_fields(ismember(config.key_fields, ...
        data_in.Properties.VariableNames));
    
    if isempty(fields_present)
        data_out = data_in;
        return;
    end
    
    % Find duplicate rows
    [~, unique_idx, ~] = unique(data_in(:, fields_present), 'rows', 'stable');
    duplicate_idx = setdiff(1:height(data_in), unique_idx);
    
    if ~isempty(duplicate_idx)
        % Record deletion
        tracker.recordDeletion('remove_duplicates', duplicate_idx, ...
            sprintf('Removed %d duplicate rows', length(duplicate_idx)));
        
        % Remove duplicates
        data_out = data_in(unique_idx, :);
    else
        data_out = data_in;
    end
end