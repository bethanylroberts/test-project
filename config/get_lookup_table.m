function data = get_lookup_table(table_name)
    % GET_LOOKUP_TABLE Load a lookup table by name
    %
    % Usage:
    %   behave = get_lookup_table('behave')
    %   speccode = get_lookup_table('speccode')
    %   cloud = get_lookup_table('cloud')
    %
    % Returns empty table if file not found.
    
    paths = get_config('paths');
    
    % Convert to lowercase for matching
    table_name_lower = lower(table_name);
    
    if isfield(paths.lookup_tables, table_name_lower)
        table_path = paths.lookup_tables.(table_name_lower);
    else
        warning('get_lookup_table:UnknownTable', ...
            'Unknown lookup table: %s', table_name);
        data = table();
        return;
    end
    
    if ~exist(table_path, 'file')
        warning('get_lookup_table:FileNotFound', ...
            'Lookup table not found: %s', table_path);
        data = table();
        return;
    end
    
    try
        % Use proper import options for CSV with quoted strings
        opts = detectImportOptions(table_path, 'Delimiter', ',');
        
        % Preserve original variable names
        opts.VariableNamingRule = 'preserve';
        
        % Read as strings first to handle mixed content
        opts = setvartype(opts, opts.VariableNames, 'string');
        
        data = readtable(table_path, opts);
        
        % Try to convert Value column to numeric if appropriate
        if ismember('Value', data.Properties.VariableNames)
            numeric_values = str2double(data.Value);
            if all(~isnan(numeric_values) | ismissing(data.Value))
                data.Value = numeric_values;
            end
        end
        
    catch ME
        warning('get_lookup_table:ReadError', ...
            'Error reading %s: %s', table_path, ME.message);
        data = table();
    end
end