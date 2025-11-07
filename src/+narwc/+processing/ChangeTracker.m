classdef ChangeTracker < handle
    % CHANGETRACKER Track all changes made during processing
    %
    % Usage:
    %   tracker = narwc.processing.ChangeTracker();
    %   tracker.recordChange('remove_duplicates', 3, 'Removed duplicate row');
    %   changes = tracker.getChanges();
    
    properties (Access = private)
        changes = struct('step', {}, 'row', {}, 'field', {}, ...
                        'old_value', {}, 'new_value', {}, 'description', {})
        step_stats = containers.Map()
    end
    
    methods
        function recordChange(obj, step, row, field, old_value, new_value, description)
            % RECORDCHANGE Record a single change
            
            if nargin < 4
                field = '';
            end
            if nargin < 5
                old_value = [];
            end
            if nargin < 6
                new_value = [];
            end
            if nargin < 7
                description = '';
            end
            
            idx = length(obj.changes) + 1;
            obj.changes(idx).step = step;
            obj.changes(idx).row = row;
            obj.changes(idx).field = field;
            obj.changes(idx).old_value = old_value;
            obj.changes(idx).new_value = new_value;
            obj.changes(idx).description = description;
            
            % Update step stats - count number of rows affected
            num_rows = length(row);
            if obj.step_stats.isKey(step)
                obj.step_stats(step) = obj.step_stats(step) + num_rows;
            else
                obj.step_stats(step) = num_rows;
            end
        end
        
           
        function recordDeletion(obj, step, rows, description)
            % RECORDDELETION Record row deletions
            % Records as single change event but counts all affected rows
            
            obj.recordChange(step, rows, 'ROW', 'deleted', '', description);
        end

        function recordModification(obj, step, row, field, old_val, new_val)
            % RECORDMODIFICATION Record field modification
            description = sprintf('Changed %s from %s to %s', ...
                field, obj.valueToString(old_val), obj.valueToString(new_val));
            obj.recordChange(step, row, field, old_val, new_val, description);
        end
        
        function recordFlag(obj, step, rows, flag_type, description)
            % RECORDFLAG Record quality control flag
            obj.recordChange(step, rows, 'QC_FLAG', '', flag_type, description);
        end
        
        function changes = getChanges(obj, step)
            % GETCHANGES Get all changes (optionally filtered by step)
            
            if nargin < 2
                changes = obj.changes;
            else
                mask = strcmp({obj.changes.step}, step);
                changes = obj.changes(mask);
            end
        end
        
        function count = getChangeCount(obj, step)
            % GETCHANGECOUNT Count of change entries (not affected rows)
            
            if nargin < 2
                count = length(obj.changes);
            else
                changes = obj.getChanges(step);
                count = length(changes);
            end
        end
        
        function count = getAffectedRowCount(obj, step)
            % GETAFFECTEDROWCOUNT Count of affected rows across all changes
            
            if nargin < 2
                % Count all affected rows
                count = 0;
                for i = 1:length(obj.changes)
                    count = count + length(obj.changes(i).row);
                end
            else
                if obj.step_stats.isKey(step)
                    count = obj.step_stats(step);
                else
                    count = 0;
                end
            end
        end
        
        function summary = getSummary(obj)
            % GETSUMMARY Get summary of all changes
            
            summary = struct();
            summary.total_changes = length(obj.changes);
            summary.steps = keys(obj.step_stats);
            summary.by_step = containers.Map();
            
            for i = 1:length(summary.steps)
                step = summary.steps{i};
                summary.by_step(step) = obj.step_stats(step);
            end
        end
        
        function displaySummary(obj)
            % DISPLAYSUMMARY Display summary of changes
            
            fprintf('\n=== Processing Changes Summary ===\n');
            fprintf('Total changes: %d\n\n', length(obj.changes));
            
            if obj.step_stats.Count > 0
                fprintf('Changes by step:\n');
                steps = keys(obj.step_stats);
                for i = 1:length(steps)
                    step = steps{i};
                    fprintf('  %-30s: %d\n', step, obj.step_stats(step));
                end
            end
            fprintf('\n');
        end
        
        function clear(obj)
            % CLEAR Clear all tracked changes
            obj.changes = struct('step', {}, 'row', {}, 'field', {}, ...
                                'old_value', {}, 'new_value', {}, 'description', {});
            obj.step_stats = containers.Map();
        end
    end
    
    methods (Access = private)
        function str = valueToString(obj, value)
            % VALUETOSTRING Convert value to string for display
            
            if isempty(value)
                str = '<empty>';
            elseif ismissing(value)
                str = '<missing>';
            elseif isnumeric(value)
                str = num2str(value);
            elseif ischar(value) || isstring(value)
                str = char(value);
            else
                str = '<complex>';
            end
        end
    end
end