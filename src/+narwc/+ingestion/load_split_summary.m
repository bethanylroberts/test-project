function [source, summary_file] = load_split_summary(split_summary_dir)
    % LOAD_SPLIT_SUMMARY Find and parse the most recent split-summary log.
    %
    % SurveyFileWriter.finalize() writes '_split_summary_<timestamp>.log'
    % directly inside the extraction output directory (e.g.
    % 'data/legacy/surveys/pending/' — the same directory passed as
    % SurveyExtractor.extractAll's output_dir / step1_extract_surveys'
    % OutputDir). This is the shared reader for that file, used by both
    % verify_migration_results.m (DB reconciliation) and
    % step3_validate_migration.m (stage-funnel baseline).
    %
    % Inputs:
    %   split_summary_dir - Directory to search for '_split_summary_*.log'
    %                        (the same output_dir used at extraction time)
    %
    % Outputs:
    %   source - struct with fields: total_surveys, total_rows,
    %            elapsed_minutes, counts (containers.Map: sanitized FILEID -> row count)
    %   summary_file - full path to the log file that was parsed

    files = dir(fullfile(split_summary_dir, '_split_summary_*.log'));
    if isempty(files)
        error('narwc:ingestion:load_split_summary:NoSplitSummary', ...
            ['No _split_summary_*.log file found in %s. Run step1_extract_surveys ' ...
             '(or convert_contributor_batch) first, or point at the directory that ' ...
             'contains it.'], split_summary_dir);
    end

    [~, idx] = max([files.datenum]);
    summary_file = fullfile(files(idx).folder, files(idx).name);

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
