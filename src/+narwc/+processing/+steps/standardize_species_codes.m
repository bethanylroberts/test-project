function [data_out, tracker] = standardize_species_codes(data_in, tracker, config)
    % STANDARDIZE_SPECIES_CODES Standardize species codes
    %
    % Converts species codes to standard format
    
    if nargin < 3
        config = struct();
        config.species_map = containers.Map(...
            {'RW', 'RIWH', 'RIGHT', 'NARW'}, ...
            {'RIWH', 'RIWH', 'RIWH', 'RIWH'});
        config.to_upper = true;
    end
    
    data_out = data_in;
    
    if ~ismember('SPECCODE', data_out.Properties.VariableNames)
        return;
    end
    
    old_codes = data_out.SPECCODE;
    
    % Convert to uppercase if requested
    if config.to_upper
        data_out.SPECCODE = upper(data_out.SPECCODE);
    end
    
    % Apply mapping
    for i = 1:height(data_out)
        if ismissing(data_out.SPECCODE(i))
            continue;
        end
        
        code = char(data_out.SPECCODE(i));
        if config.species_map.isKey(code)
            new_code = config.species_map(code);
            if ~strcmp(code, new_code)
                tracker.recordModification('standardize_species_codes', i, ...
                    'SPECCODE', code, new_code);
                
                % Assign as cell or string depending on table type
                if iscell(data_out.SPECCODE)
                    data_out.SPECCODE{i} = new_code;
                else
                    data_out.SPECCODE(i) = string(new_code);
                end
            end
        end
    end
end