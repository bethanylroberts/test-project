classdef MockBatchConn < handle
    % MOCKBATCHCONN Minimal connection stub for BatchUploader guardrail tests.
    properties
        fetch_call_count  = 0
        insert_call_count = 0
        is_open           = true
    end
    methods
        function result = fetch(obj, ~)
            obj.fetch_call_count = obj.fetch_call_count + 1;
            result = table(0, 'VariableNames', {'cnt'});
        end
        function execute(~, ~)
        end
        function insert(obj, ~, ~)
            obj.insert_call_count = obj.insert_call_count + 1;
        end
        function tf = isOpen(obj)
            tf = obj.is_open;
        end
        function close(~)
        end
    end
end
