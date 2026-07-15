classdef ErrorCollector < handle
    % ERRORCOLLECTOR Collect and categorize validation errors
    %
    % Usage:
    %   collector = ErrorCollector();
    %   collector.addError('LAT_DD', 123, 'Latitude out of range', 'error', ...
    %                      'coordinate_rules.lat_out_of_range', 456);
    %   errors = collector.getErrors();

    properties (Access = private)
        errors = struct('field', {}, 'row', {}, 'eventno', {}, 'rule_id', {}, ...
                        'message', {}, 'severity', {})
    end

    methods
        function addError(obj, field, row, message, severity, rule_id, eventno)
            % ADDERROR Add an error to the collection
            %
            % Inputs:
            %   field    - Field name (e.g., 'LAT_DD')
            %   row      - Row number (or array of row numbers)
            %   message  - Error description
            %   severity - 'error', 'warning', or 'info'
            %   rule_id  - Stable rule identifier (e.g., 'coordinate_rules.lat_out_of_range')
            %   eventno  - EVENTNO of the offending record (scalar; use [] if unknown)

            if nargin < 5
                severity = 'error';
            end
            if nargin < 6
                rule_id = '';
            end
            if nargin < 7
                eventno = [];
            end

            idx = length(obj.errors) + 1;
            obj.errors(idx).field    = field;
            obj.errors(idx).row      = row;
            obj.errors(idx).eventno  = eventno;
            obj.errors(idx).rule_id  = rule_id;
            obj.errors(idx).message  = message;
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

        function indices = getWarningIndices(obj)
            % GETWARNINGINDICES Return indices into the internal array for all warnings

            indices = find(strcmp({obj.errors.severity}, 'warning'));
        end

        function demoteToInfo(obj, index)
            % DEMOTETOINFO Change a warning entry to info (no longer blocking)

            if index >= 1 && index <= length(obj.errors) && ...
                    strcmp(obj.errors(index).severity, 'warning')
                obj.errors(index).severity = 'info';
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
            obj.errors = struct('field', {}, 'row', {}, 'eventno', {}, 'rule_id', {}, ...
                                'message', {}, 'severity', {});
        end

        function summary = getSummary(obj)
            % GETSUMMARY Get summary statistics

            summary.total    = length(obj.errors);
            summary.errors   = obj.getErrorCount('error');
            summary.warnings = obj.getErrorCount('warning');
            summary.info     = obj.getErrorCount('info');

            % Group by field
            if ~isempty(obj.errors)
                fields = unique({obj.errors.field});
                summary.by_field = struct();
                for i = 1:length(fields)
                    field = fields{i};
                    field_errors = obj.errors(strcmp({obj.errors.field}, field));
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
            % FIXME: this code is probably repeated. Refactor it to allow reuse.
            clean = regexprep(field, '[^a-zA-Z0-9_]', '_');
            if ~isempty(clean) && ~isletter(clean(1))
                clean = ['field_' clean];
            end
            if isempty(clean)
                clean = 'unknown_field';
            end
        end
    end

end
