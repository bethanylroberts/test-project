classdef TabDeliminatedFormat < narwc.io.parsers.BaseParser
    % TABDELIMINATEDFORMAT Parser for standard NARWC format
    %
    % Alternative standard format is tab-delimited with all 55 fields in standard order
    
    properties (Constant)
        FORMAT_NAME = 'Standard NARWC Format'
        DESCRIPTION = 'Tab-delimited, 55 fields in standard order'
    end
    
    methods
        function [data, metadata] = parse(obj)
            % PARSE Parse standard format file
            
            % Create import options
            import_opts = delimitedTextImportOptions('NumVariables', 55);
            import_opts.Delimiter = '\t';
            import_opts.DataLines = [2, Inf];
            
            % Set variable names
            import_opts.VariableNames = narwc.io.parsers.BaseParser.getStandardFieldsStatic();
            
            % Set variable types
            var_types = cell(1, 55);
            for i = 1:55
                if narwc.io.parsers.BaseParser.isNumericField(import_opts.VariableNames{i})
                    var_types{i} = 'double';
                else
                    var_types{i} = 'string';
                end
            end
            import_opts.VariableTypes = var_types;
            
            % String options
            string_fields = {};
            for i = 1:length(import_opts.VariableNames)
                if ~narwc.io.parsers.BaseParser.isNumericField(import_opts.VariableNames{i})
                    string_fields{end+1} = import_opts.VariableNames{i};
                end
            end
            
            import_opts = setvaropts(import_opts, string_fields, ...
                'WhitespaceRule', 'trim', 'EmptyFieldRule', 'missing');
            
            % Missing values
            import_opts = setvaropts(import_opts, 'TreatAsMissing', ["NULL", "."]);
            import_opts.ExtraColumnsRule = 'ignore';
            import_opts.EmptyLineRule = 'skip';
            
            % Read file
            data = readtable(obj.file_path, import_opts);
            
            % Metadata
            metadata.row_count = height(data);
            metadata.column_count = width(data);
        end
    end
    
methods (Static)
        function confidence = detectFormat(file_path)
            % DETECTFORMAT Detect if file is in standard format
            
            try
                % Check if file exists
                if ~exist(file_path, 'file')
                    confidence = 0;
                    return;
                end
                
                % Read first few lines
                fid = fopen(file_path, 'r');
                header = fgetl(fid);
                fclose(fid);
                
                % Check for tab delimiter
                if ~contains(header, sprintf('\t'))
                    confidence = 0;
                    return;
                end
                
                % Check for standard field names
                fields = strsplit(header, '\t');
                standard_fields = narwc.io.parsers.BaseParser.getStandardFieldsStatic();
                
                % Calculate match percentage
                matches = sum(ismember(fields, standard_fields));
                confidence = matches / length(standard_fields);
                
            catch
                confidence = 0;
            end
        end
    end    
end