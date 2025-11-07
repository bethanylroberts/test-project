classdef ErrorCollector < handle
    % ERRORCOLLECTOR Collect and categorize validation errors
    %
    % Usage:
    %   collector = ErrorCollector();
    %   collector.addError('LAT_DD', 123, 'Latitude out of range', 'error');
    %   errors = collector.getErrors();
    
    properties (Access = private)
        errors = struct('field', {}, 'row', {}, 'message', {}, 'severity', {})
    end
    
    methods
        function addError(obj, field, row, message, severity)
            % ADDERROR Add an error to the collection
            %
            % Inputs:
            %   field - Field name (e.g., 'LAT_DD')
            %   row - Row number (or array of row numbers)
            %   message - Error description
            %   severity - 'error', 'warning', or 'info'
            
            if nargin < 5
                severity = 'error';
            end
            
            idx = length(obj.errors) + 1;
            obj.errors(idx).field = field;
            obj.errors(idx).row = row;
            obj.errors(idx).message = message;
            obj.errors(idx).severity = lower(severity);
        end
        
        function errors = getErrors(obj, severity)
            % GETERRORS Get all errors (optionally filtered by severity)
            
            if nargin < 2
                errors = obj.errors;
            else
                mask = strcmp({obj.errors.severity}, lower(severity));
                errors = obj.errors(mask);
            end
        end
        
        function count = getErrorCount(obj, severity)
            % GETERRORCOUNT Count errors by severity
            
            if nargin < 2
                count = length(obj.errors);
            else
                errors = obj.getErrors(severity);
                count = length(errors);
            end
        end
        
        function clear(obj)
            % CLEAR Clear all errors
            obj.errors = struct('field', {}, 'row', {}, 'message', {}, 'severity', {});
        end
        
        function summary = getSummary(obj)
            % GETSUMMARY Get summary statistics
            
            summary.total = length(obj.errors);
            summary.errors = obj.getErrorCount('error');
            summary.warnings = obj.getErrorCount('warning');
            summary.info = obj.getErrorCount('info');
            
            % Group by field
            if ~isempty(obj.errors)
                fields = unique({obj.errors.field});
                summary.by_field = struct();
                for i = 1:length(fields)
                    field = fields{i};
                    field_errors = obj.errors(strcmp({obj.errors.field}, field));
                    
                    % Sanitize field name for struct (replace invalid chars)
                    clean_field = obj.sanitizeFieldName(field);
                    summary.by_field.(clean_field) = length(field_errors);
                end
            else
                summary.by_field = struct();
            end
        end
    end

    methods (Static, Access = private)
        function clean = sanitizeFieldName(field)
            % SANITIZEFIELDNAME Convert field name to valid struct field
            %
            % Replaces invalid characters with underscores
            
            % Replace commas, spaces, and other invalid chars with underscore
            clean = regexprep(field, '[^a-zA-Z0-9_]', '_');
            
            % Ensure it starts with a letter
            if ~isempty(clean) && ~isletter(clean(1))
                clean = ['field_' clean];
            end
            
            % Ensure it's not empty
            if isempty(clean)
                clean = 'unknown_field';
            end
        end
    end

end