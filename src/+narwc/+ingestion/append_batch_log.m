function append_batch_log(entry, log_path)
    % APPEND_BATCH_LOG Append one row to the human-readable batch ledger.
    %
    % The ledger (default data/surveys/batch_log.csv) is an append-only CSV
    % recording every convert/upload/validate run against the survey
    % pipeline -- one row per stage-event, all sharing a batch_id. It is
    % what answers "has this raw input already been converted" and "what's
    % the current/most recent batch" without needing any directory
    % restructuring.
    %
    % entry is a struct with fields: batch_id, stage ('convert'|'upload'|
    % 'validate'), source, input, output, total_surveys, total_rows, notes.
    % Missing fields default to empty. timestamp is stamped automatically.
    % Free-text fields have commas replaced with semicolons to keep the CSV
    % flat (same convention as BatchUploader.appendRunSummaryRow).
    %
    % Usage:
    %   narwc.ingestion.append_batch_log(struct( ...
    %       'batch_id', '20260726_143012_legacy', 'stage', 'convert', ...
    %       'source', 'legacy', ...
    %       'input', 'data/surveys/raw/legacy/RUSS_24_VALID.CSV', ...
    %       'output', 'data/surveys/pending/_split_summary_....log', ...
    %       'total_surveys', 1234, 'total_rows', 567890));

    arguments
        entry struct
        log_path char = fullfile('data', 'surveys', 'batch_log.csv')
    end

    fields = {'batch_id', 'stage', 'source', 'input', 'output', ...
        'total_surveys', 'total_rows', 'notes'};
    for i = 1:numel(fields)
        if ~isfield(entry, fields{i})
            entry.(fields{i}) = '';
        end
    end

    log_dir = fileparts(log_path);
    if ~isempty(log_dir) && ~exist(log_dir, 'dir')
        mkdir(log_dir);
    end

    write_header = ~exist(log_path, 'file');

    fid = fopen(log_path, 'a');
    if fid == -1
        error('narwc:ingestion:append_batch_log:CannotOpenLog', ...
            'Could not open %s', log_path);
    end

    if write_header
        fprintf(fid, ['batch_id,stage,source,timestamp,input,output,' ...
            'total_surveys,total_rows,notes\n']);
    end

    ts = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
    csv_safe = @(s) strrep(char(string(s)), ',', ';');

    fprintf(fid, '%s,%s,%s,%s,%s,%s,%s,%s,%s\n', ...
        csv_safe(entry.batch_id), csv_safe(entry.stage), csv_safe(entry.source), ts, ...
        csv_safe(entry.input), csv_safe(entry.output), ...
        csv_safe(entry.total_surveys), csv_safe(entry.total_rows), csv_safe(entry.notes));

    fclose(fid);
end
