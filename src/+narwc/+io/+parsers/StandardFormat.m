% src/+narwc/+io/+parsers/StandardFormat.m

classdef StandardFormat < narwc.io.parsers.BaseParser
    % STANDARDFORMAT Parser for standard NARWC CSV format (legacy file)
    %
    % This format has 55 columns with a specific order that differs from
    % the database schema. This parser reads the CSV in its native order
    % and remaps to the database field order.

    % FIXME: seperate the standard and legacy even though they are the same.
    % That may change later. I think the re-map method below is the major difference.
    
    properties (Constant)
        FORMAT_NAME = 'Standard NARWC Format'
        DESCRIPTION = 'Comma-delimited CSV with 55 fields in legacy order'
        
        % Define the CSV column order (as it appears in the file)
        CSV_FIELD_ORDER = {
            'ALT', 'ANHEAD', 'BEAUFORT', 'BEHAV1', 'BEHAV2', 'BEHAV3', ...
            'BEHAV4', 'BEHAV5', 'BEHAV6', 'BEHAV7', 'BEHAV8', 'BEHAV9', ...
            'BEHAV10', 'BEHAV11', 'BEHAV12', 'BEHAV13', 'BEHAV14', 'BEHAV15', ...
            'BLOCK', 'CLOUD', 'CONFIDNC', 'DAY', 'DDSOURCE', 'EVENTNO', 'FILEID', ...
            'GLAREL', 'GLARER', 'HEADING', 'IDREL', 'IDSOURCE', 'LAT_DD', ...
            'LEGNO', 'LEGSTAGE', 'LEGTYPE', 'LONG_DD', 'MONTH', 'NUMBER', ...
            'NUMCALF', 'PHOTOS', 'PLATFORM', 'S_LAT', 'S_LONG', 'S_TIME', ...
            'SIGHTNO', 'SPECCODE', 'STRATUM', 'STRIP', 'SURFTEMP', 'TAXCODE', ...
            'TIME', 'VISIBLTY', 'WX', 'YEAR', 'ANGLEL', 'ANGLER'
        };
    end
    
    methods (Static)
        function [data, metadata] = parse(file_path)   % FIXME: obj is not used?
            % PARSE Parse standard format file

            if ~exist(file_path, 'file')
                error('File not found: %s', file_path);
            end

            % Read with CSV field order
            import_opts = narwc.io.parsers.StandardFormat.createImportOptions();
            raw_data = readtable(file_path, import_opts);
            
            % Remove the unused column
            if ismember('UNUSED', raw_data.Properties.VariableNames)
                raw_data.UNUSED = [];
            end
            
            % Remap to database field order
            data = narwc.io.parsers.StandardFormat.remapToDatabase(raw_data);
            
            % Create metadata
            metadata.row_count = height(data);
            metadata.column_count = width(data);
            metadata.format = narwc.io.parsers.StandardFormat.FORMAT_NAME;
            metadata.source_column_order = narwc.io.parsers.StandardFormat.CSV_FIELD_ORDER;
        end
    end
    
    methods (Static)
        function import_opts = createImportOptions()
            % CREATEIMPORTOPTIONS Create import options for CSV field order
            
            num_vars = length(narwc.io.parsers.StandardFormat.CSV_FIELD_ORDER);
            import_opts = delimitedTextImportOptions('NumVariables', num_vars);
            import_opts.Delimiter = ',';
            import_opts.DataLines = [2, Inf];  % No header in legacy file
            
            % Set variable names from CSV order
            import_opts.VariableNames = narwc.io.parsers.StandardFormat.CSV_FIELD_ORDER;
            
            % Set all types based on field definitions
            field_defs = narwc.db.FieldDefinitions.getAll();
            field_map = containers.Map(field_defs(:,1), field_defs(:,2));
            
            var_types = cell(1, num_vars);
            for i = 1:num_vars
                field_name = narwc.io.parsers.StandardFormat.CSV_FIELD_ORDER{i};
                if strcmp(field_name, 'UNUSED')
                    var_types{i} = 'string';  % Placeholder for unused column
                elseif isKey(field_map, field_name)
                    var_types{i} = field_map(field_name);
                else
                    var_types{i} = 'string';  % Default to string
                end
            end
            import_opts.VariableTypes = var_types;
            
            % String field options
            string_fields = [narwc.db.FieldDefinitions.getStringFields()];
            import_opts = setvaropts(import_opts, string_fields, ...
                "WhitespaceRule", "trim", "EmptyFieldRule", "missing");
            
            % Missing value handling
            import_opts = setvaropts(import_opts, 'TreatAsMissing', ["NULL", ".", ""]);
            import_opts.ExtraColumnsRule = 'ignore';
            import_opts.EmptyLineRule = 'skip';
        end
        
        function db_data = remapToDatabase(csv_data)
            % REMAPTODATABASE Remap CSV column order to database order
            %
            % Input: Table with fields in CSV order
            % Output: Table with fields in database order
            
            % Get database field order
            db_order = narwc.db.FieldDefinitions.getDatabaseOrder();
            
            % Create new table with database order
            num_rows = height(csv_data);
            db_data = table();
            
            for i = 1:length(db_order)
                field_name = db_order{i};
                
                if ismember(field_name, csv_data.Properties.VariableNames)
                    % Field exists in CSV data
                    db_data.(field_name) = csv_data.(field_name);
                else
                    % Field doesn't exist - create empty column
                    field_defs = narwc.db.FieldDefinitions.getAll();
                    field_idx = find(strcmp(field_defs(:,1), field_name), 1);
                    
                    if ~isempty(field_idx)
                        field_type = field_defs{field_idx, 2};
                        if strcmp(field_type, 'string')
                            db_data.(field_name) = repmat({''}, num_rows, 1);
                        else
                            db_data.(field_name) = nan(num_rows, 1);
                        end
                    end
                end
            end
        end
        
        function confidence = detectFormat(file_path)
            % DETECTFORMAT Detect if file is in standard format
            
            try
                if ~exist(file_path, 'file')
                    confidence = 0;
                    return;
                end
                
                % Read first few lines
                fid = fopen(file_path, 'r');
                line1 = fgetl(fid);
                line2 = fgetl(fid);
                fclose(fid);
                
                % Check for comma delimiter
                if ~contains(line1, ',')
                    confidence = 0;
                    return;
                end
                
                % Count fields in first line
                fields = strsplit(line1, ',');
                num_fields = length(fields);
                
                % Should have 55 fields
                if num_fields == 55
                    % Check if it looks like data (not headers)
                    % Legacy format has no headers - first line is data
                    has_quotes = contains(line1, '"');
                    has_numbers = any(isstrprop(line1, 'digit'));
                    
                    if has_quotes && has_numbers
                        confidence = 0.9;  % High confidence
                    else
                        confidence = 0.5;
                    end
                else
                    confidence = 0.1;  % Wrong number of fields
                end
                
            catch
                confidence = 0;
            end
        end
    end
end