function [source, summary_file] = load_split_summary(split_summary_path)
    % LOAD_SPLIT_SUMMARY Find and parse a split-summary log.
    %
    % SurveyFileWriter.finalize() writes '_split_summary_<timestamp>.log'
    % directly inside the extraction output directory (e.g.
    % 'data/surveys/pending/' — the same directory passed as
    % SurveyExtractor.extractAll's output_dir / convert_contributor_batch's
    % OutputDir). This is the shared reader for that file, used by
    % verify_migration_results.m (DB reconciliation), validate_batch.m
    % (stage-funnel baseline), and BatchUploader (batch-scoped uploads).
    %
    % Inputs:
    %   split_summary_path - Either a specific '_split_summary_*.log' file
    %                        (e.g. the exact log recorded for a batch_id in
    %                        the batch ledger, see append_batch_log), or a
    %                        directory to search, in which case the most
    %                        recently written '_split_summary_*.log' in it
    %                        is used.
    %
    % Outputs:
    %   source - struct with fields: total_surveys, total_rows,
    %            elapsed_minutes, counts (containers.Map: sanitized FILEID -> row count)
    %   summary_file - full path to the log file that was parsed

    if exist(split_summary_path, 'file') == 2
        summary_file = split_summary_path;
    else
        files = dir(fullfile(split_summary_path, '_split_summary_*.log'));
        if isempty(files)
            error('narwc:ingestion:load_split_summary:NoSplitSummary', ...
                ['No _split_summary_*.log file found in %s. Run convert_contributor_batch ' ...
                 'first, or point at the directory that contains it.'], split_summary_path);
        end

        [~, idx] = max([files.datenum]);
        summary_file = fullfile(files(idx).folder, files(idx).name);
    end

    source = struct();
    source.total_surveys = NaN;
    source.total_rows = NaN;
    source.elapsed_minutes = NaN;
    source.counts = containers.Map('KeyType', 'char', 'ValueType', 'double');

    fid = fopen(summary_file, 'r');
    if fid == -1
        error('narwc:ingestion:load_split_summary:CannotOpenSplitSummary', ...
            'Could not open %s', summary_file);
    end

    in_survey_list = false;
    try
        while true
            line = fgetl(fid);
            if ~ischar(line)
                break;
            end

            if startsWith(line, 'Total surveys:')
                source.total_surveys = sscanf(line, 'Total surveys: %d');
            elseif startsWith(line, 'Total rows:')
                source.total_rows = sscanf(line, 'Total rows: %d');
            elseif startsWith(line, 'Time elapsed:')
                source.elapsed_minutes = sscanf(line, 'Time elapsed: %f');
            elseif startsWith(line, 'Survey file row counts:')
                in_survey_list = true;
            elseif in_survey_list
                tok = regexp(line, '^(.+): (\d+) rows$', 'tokens', 'once');
                if ~isempty(tok)
                    fileid = upper(strtrim(tok{1}));
                    source.counts(fileid) = str2double(tok{2});
                end
            end
        end
    catch ME
        fclose(fid);
        rethrow(ME);
    end
    fclose(fid);
end
