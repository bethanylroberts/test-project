classdef DataTypeConverter
    % DATATYPECONVERTER Ensure correct data types for database upload
    %
    % Usage:
    %   data = narwc.io.DataTypeConverter.prepareForUpload(data);

    methods (Static)

    function data = prepareForUpload(data)
        % PREPAREFORUPLOAD Convert data types for database compatibility

        % NOTE: prepare for upload gets called by BatchUploader
        
        % Get field definitions from central location
        string_fields = narwc.db.FieldDefinitions.getStringFields();
        numeric_fields = narwc.db.FieldDefinitions.getNumericFields();
        
        % Convert string fields to cell arrays of char
        for i = 1:length(string_fields)
            field = string_fields{i};
            if ismember(field, data.Properties.VariableNames)
                data.(field) = narwc.io.DataTypeConverter.ensureCellStr(data.(field));
            end
        end
        
        % Convert numeric fields to double
        for i = 1:length(numeric_fields)
            field = numeric_fields{i};
            if ismember(field, data.Properties.VariableNames)
                data.(field) = narwc.io.DataTypeConverter.ensureDouble(data.(field));
            end
        end
        
        % Convert NaN to missing (SQL NULL) for all numeric fields
        for i = 1:length(numeric_fields)
            field = numeric_fields{i};
            if ismember(field, data.Properties.VariableNames)
                data.(field) = standardizeMissing(data.(field), NaN);
            end
        end
        
        % Convert empty strings to missing (SQL NULL) for all string fields
        for i = 1:length(string_fields)
            field = string_fields{i};
            if ismember(field, data.Properties.VariableNames)
                data.(field) = standardizeMissing(data.(field), {''});
            end
        end
    end
        
        function out = ensureCellStr(in)
            % ENSURECELLSTR Convert to cell array of char
            
            if iscell(in)
                % Already cell, but might contain strings - convert to char
                out = cell(size(in));
                for i = 1:length(in)
                    if isstring(in{i})
                        out{i} = char(in{i});
                    elseif ischar(in{i})
                        out{i} = in{i};
                    elseif isnumeric(in{i})
                        out{i} = num2str(in{i});
                    else
                        out{i} = '';
                    end
                end
            elseif isstring(in)
                % String array - convert to cell array of char
                out = cellstr(in);
            elseif isnumeric(in)
                % Numeric - convert to cell array of char
                out = cell(size(in));
                for i = 1:length(in)
                    if isnan(in(i))
                        out{i} = '';
                    else
                        out{i} = num2str(in(i));
                    end
                end
            else
                % Unknown type - try to convert
                out = cellstr(string(in));
            end
        end
        
        function out = ensureDouble(in)
            % ENSUREDOUBLE Convert to double array
            
            if isnumeric(in)
                out = double(in);
            elseif iscell(in)
                % Cell array - convert to double
                out = nan(size(in));
                for i = 1:length(in)
                    if isnumeric(in{i})
                        out(i) = double(in{i});
                    elseif ischar(in{i}) || isstring(in{i})
                        val = str2double(in{i});
                        out(i) = val;
                    end
                end
            elseif isstring(in) || ischar(in)
                out = str2double(in);
            else
                out = double(in);
            end
        end
    end
end