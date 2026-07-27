function tbl = read_batch_log(log_path)
    % READ_BATCH_LOG Read the batch ledger (see append_batch_log) as a table.
    %
    % Returns an empty table with the correct columns if the ledger doesn't
    % exist yet (e.g. before the first convert run has ever happened).

    arguments
        log_path char = fullfile('data', 'surveys', 'batch_log.csv')
    end

    var_names = {'batch_id', 'stage', 'source', 'timestamp', 'input', ...
        'output', 'total_surveys', 'total_rows', 'notes'};

    if ~exist(log_path, 'file')
        tbl = cell2table(cell(0, numel(var_names)), 'VariableNames', var_names);
        return;
    end

    tbl = readtable(log_path, 'Delimiter', ',', 'TextType', 'char', ...
        'VariableNamingRule', 'preserve');
end
