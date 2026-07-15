classdef MockBatchConn < handle
    % MOCKBATCHCONN Minimal connection stub for BatchUploader tests.
    %
    % Records all transaction-related calls so tests can verify that
    % beginTransaction / commit / rollback are called at the right times
    % and that AutoCommit is restored after each operation.
    properties
        fetch_call_count        = 0
        insert_call_count       = 0
        begin_transaction_count = 0
        commit_count            = 0
        rollback_count          = 0
        auto_commit             = 'on'
        is_open                 = true
        insert_should_fail      = false  % set true to simulate insert failure
        fetch_survey_exists     = false  % set true to simulate survey already in DB
    end
    methods
        function result = fetch(obj, ~)
            obj.fetch_call_count = obj.fetch_call_count + 1;
            cnt = double(obj.fetch_survey_exists);
            result = table(cnt, 'VariableNames', {'cnt'});
        end
        function execute(~, ~)
        end
        function insert(obj, ~, ~)
            obj.insert_call_count = obj.insert_call_count + 1;
            if obj.insert_should_fail
                error('MockBatchConn:InsertFailed', 'Simulated insert failure');
            end
        end
        function tf = isOpen(obj)
            tf = obj.is_open;
        end
        function close(~)
        end

        % --- Transaction support ---
        function ac = getAutoCommit(obj)
            ac = obj.auto_commit;
        end
        function setAutoCommit(obj, value)
            obj.auto_commit = value;
        end
        function beginTransaction(obj)
            obj.begin_transaction_count = obj.begin_transaction_count + 1;
            obj.auto_commit = 'off';
        end
        function commit(obj)
            obj.commit_count = obj.commit_count + 1;
        end
        function rollback(obj)
            obj.rollback_count = obj.rollback_count + 1;
        end
    end
end
