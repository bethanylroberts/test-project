function prior = check_prior_conversion(input_path, log_path)
    % CHECK_PRIOR_CONVERSION Look up prior 'convert' ledger rows matching input_path.
    %
    % Returns a table of matching rows (possibly empty) so the caller can
    % warn "this input was already converted in batch <batch_id>" without
    % blocking the run. Matches on an exact string match of the ledger's
    % 'input' column. For contributor batches 'input' is the whole
    % input_dir, so this is directory-level, not file-level: if a
    % contributor delivers additional files into an already-converted
    % folder, this will still (falsely) report a match -- acceptable since
    % it's a warning, not a gate.

    arguments
        input_path char
        log_path char = fullfile('data', 'surveys', 'batch_log.csv')
    end

    tbl = narwc.ingestion.read_batch_log(log_path);
    if height(tbl) == 0
        prior = tbl;
        return;
    end

    is_convert = strcmp(tbl.stage, 'convert');
    is_match   = strcmp(tbl.input, input_path);
    prior = tbl(is_convert & is_match, :);
end
