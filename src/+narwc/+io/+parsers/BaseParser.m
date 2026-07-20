classdef (Abstract) BaseParser < handle
    % BASE PARSER Abstract base class for all survey format parsers

    % TODO: go through all parsers
    
    properties (Access = protected)
        file_path
        logger
    end
    
    properties (Abstract, Constant)
        FORMAT_NAME
        DESCRIPTION
    end
    
    methods
        function obj = BaseParser()
            % obj.file_path = file_path;
            % class(obj) is already fully-qualified (e.g.
            % 'narwc.io.parsers.StandardFormat') -- do not prefix it again.
            obj.logger = logging.Logger(class(obj));
            
            % if ~exist(file_path, 'file')
            %     error('File not found: %s', file_path);
            % end
        end
        
        function [data, metadata] = read(obj, file_path)
            obj.logger.info(sprintf('Parsing file: %s', file_path));
            
            try
                [data, metadata] = obj.parse(file_path);
                data = obj.standardize(data);
                
                metadata.file_path = file_path;
                metadata.format = obj.FORMAT_NAME;
                metadata.parse_time = datetime('now');
                
                obj.logger.info(sprintf('Successfully parsed %d records', height(data)));
                
            catch ME
                obj.logger.error(sprintf('Parse failed: %s', ME.message));
                rethrow(ME);
            end
        end
        
        function standardized = standardize(obj, data)
            standardized = data;
            required_fields = narwc.io.parsers.BaseParser.getStandardFieldsStatic();
            
            for i = 1:length(required_fields)
                field = required_fields{i};
                if ~ismember(field, standardized.Properties.VariableNames)
                    if narwc.io.parsers.BaseParser.isNumericField(field)
                        standardized.(field) = nan(height(standardized), 1);
                    else
                        standardized.(field) = repmat({''}, height(standardized), 1);
                    end
                    obj.logger.debug(sprintf('Added missing field: %s', field));
                end
            end
            
            standardized = standardized(:, required_fields);
        end
    end
    
    methods (Abstract)
        [data, metadata] = parse(obj, file_path)
    end
    
    methods (Static, Abstract)
        confidence = detectFormat(file_path)
    end
    
    methods (Static)
        function fields = getStandardFieldsStatic()
            % GETSTANDARDFIELDSSTATIC Get standard field names
            fields = narwc.db.FieldDefinitions.getFieldNames();
        end
        
        function is_numeric = isNumericField(field_name)
            % ISNUMERICFIELD Check if field should be numeric
            is_numeric = narwc.db.FieldDefinitions.isNumeric(field_name);
        end
    end
end