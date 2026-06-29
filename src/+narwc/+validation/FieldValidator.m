classdef FieldValidator
    % FIELDVALIDATOR Field-level validation utilities
    %
    % Static methods for common validation patterns

    % NOTE: only run by test_validation
    
    methods (Static)
        function [is_valid, invalid_rows] = validateRange(values, min_val, max_val)
            % VALIDATERANGE Check if values are within range
            
            is_valid = values >= min_val & values <= max_val & ~ismissing(values);
            invalid_rows = find(~is_valid);
        end
        
        function [is_valid, invalid_rows] = validateNotMissing(values)
            % VALIDATENOTMISSING Check for missing values
            
            is_valid = ~ismissing(values);
            invalid_rows = find(~is_valid);
        end
        
        function [is_valid, invalid_rows] = validateInSet(values, valid_set)
            % VALIDATEINSET Check if values are in a valid set
            
            is_valid = ismember(values, valid_set);
            invalid_rows = find(~is_valid);
        end
        
        function [is_valid, invalid_rows] = validatePattern(values, pattern)
            % VALIDATEPATTERN Check if strings match a pattern
            
            if isstring(values) || iscellstr(values)
                is_valid = ~cellfun(@isempty, regexp(values, pattern));
                invalid_rows = find(~is_valid);
            else
                error('Values must be string or cell array of strings');
            end
        end
        
        function [is_valid, invalid_rows] = validateType(values, expected_type)
            % VALIDATETYPE Check if values are of expected type
            
            switch lower(expected_type)
                case 'numeric'
                    is_valid = isnumeric(values);
                case 'string'
                    is_valid = isstring(values) | iscellstr(values);
                case 'datetime'
                    is_valid = isdatetime(values);
                otherwise
                    error('Unknown type: %s', expected_type);
            end
            
            if ~is_valid
                invalid_rows = 1:length(values);
            else
                invalid_rows = [];
            end
        end
    end
end