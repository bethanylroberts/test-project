% src/+narwc/+io/+parsers/NEAQFormat.m

classdef NEAQFormat < narwc.io.parsers.BaseParser
    % NEAQFORMAT Parser for NEAQ-specific format
    %
    % Example of how other formats can have different column orders
    % and still map to the standard database schema
    
    properties (Constant)
        FORMAT_NAME = 'NEAQ Format'
        DESCRIPTION = 'NEAQ tab-delimited format with headers'
        
        % NEAQ might have different column order
        CSV_FIELD_ORDER = {
            'FILEID', 'YEAR', 'MONTH', 'DAY', 'TIME', ...
            'LAT_DD', 'LONG_DD', 'SPECCODE', 'NUMBER', 'CONFIDNC', ...
            % ... other fields in NEAQ order
        };
    end
    
    methods
        function [data, metadata] = parse(obj)
            % Similar structure to StandardFormat but with NEAQ-specific order
            import_opts = narwc.io.parsers.NEAQFormat.createImportOptions();
            raw_data = readtable(obj.file_path, import_opts);
            
            % Remap to database order
            data = narwc.io.parsers.StandardFormat.remapToDatabase(raw_data);
            
            metadata.row_count = height(data);
            metadata.column_count = width(data);
            metadata.format = narwc.io.parsers.NEAQFormat.FORMAT_NAME;
        end
    end
    
    % ... implement createImportOptions and detectFormat ...
end