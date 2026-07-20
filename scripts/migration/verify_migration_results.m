% VERIFY_MIGRATION_RESULTS checks the live database against the original source
%
% Reconciles what's actually in the SQL Server Master table against the
% per-survey counts recorded when the legacy CSV was split, and re-runs the
% foreign-key integrity checks from scripts/sql/verification/check_fk_integrity.sql
% directly against the database. Produces real, current numbers suitable for
% a status report or presentation — safe to re-run at any time; does not
% modify step1/step2/step3 or their output directories.
%
% Requires a live database connection (config/local/db_config_local.m) and at
% least one data/legacy/_split_summary_*.log file from a prior extraction run.
%
% Usage:
%   results = verify_migration_results();
%   results = verify_migration_results('SplitSummaryDir', 'data/legacy');

function results = verify_migration_results(options)
    arguments
        options.SplitSummaryDir char = 'data/legacy'
        options.ReportDir char = 'reports/migration'
        options.TableName char = 'Master'
        options.MaxListed double = 25   % cap on rows listed in the console summary
    end

    fprintf('=== Migration Verification: Database vs. Source ===\n\n');

    results = struct();
    results.generated_at = datetime('now');

    % --- Source-of-truth: most recent split summary -----------------------
    fprintf('Loading source-of-truth split summary...\n');
    [source, summary_file] = load_latest_split_summary(options.SplitSummaryDir);
    results.source = source;
    results.source_file = summary_file;
    fprintf('  Using: %s\n', summary_file);
    fprintf('  Source surveys: %d | Source rows: %d\n\n', ...
        source.total_surveys, source.total_rows);

    % --- Live database -------------------------------------------------
    fprintf('Connecting to database...\n');
    conn = narwc.db.Connection.create();
    cleanup_conn = onCleanup(@() conn.close()); %#ok<NASGU> % ensures connection closes even on error

    db = query_database_counts(conn, options.TableName);
    results.database = db;
    fprintf('  Database surveys: %d | Database rows: %d\n\n', ...
        db.total_surveys, db.total_rows);

    fprintf('Running foreign-key integrity checks...\n');
    results.fk_violations = check_fk_integrity(conn, options.TableName);
    fprintf('\n');

    % --- Reconcile source vs. database ----------------------------------
    fprintf('Reconciling source vs. database...\n\n');
    results.reconciliation = reconcile_counts(source, db);

    % --- Report -----------------------------------------------------------
    print_console_summary(results, options.MaxListed);

    if ~exist(options.ReportDir, 'dir')
        mkdir(options.ReportDir);
    end
    report_file = fullfile(options.ReportDir, ...
        sprintf('migration_verification_%s.md', datestr(now, 'yyyymmdd_HHMMSS')));
    write_report(results, report_file);
    fprintf('\nFull report written to: %s\n', report_file);
end

%% Helper Functions

function [source, summary_file] = load_latest_split_summary(split_summary_dir)
    % LOAD_LATEST_SPLIT_SUMMARY Find and parse the most recent split summary log
    % files = dir(fullfile(split_summary_dir, '_split_summary_*.log'));
    files = dir(fullfile(split_summary_dir, '_split_summary*.txt'));
    if isempty(files)
        error('verify_migration_results:NoSplitSummary', ...
            ['No _split_summary_*.log file found in %s. Run step1_extract_surveys ' ...
             'first, or point SplitSummaryDir at the folder that contains it.'], ...
            split_summary_dir);
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
        error('verify_migration_results:CannotOpenSplitSummary', ...
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

function db = query_database_counts(conn, table_name)
    % QUERY_DATABASE_COUNTS Pull total/distinct-survey/per-survey counts from Master
    db = struct();

    total_result = conn.fetch(sprintf('SELECT COUNT(*) AS cnt FROM %s', table_name));
    db.total_rows = total_result.cnt(1);

    surveys_result = conn.fetch(sprintf( ...
        'SELECT COUNT(DISTINCT FILEID) AS cnt FROM %s', table_name));
    db.total_surveys = surveys_result.cnt(1);

    per_survey = conn.fetch(sprintf( ...
        'SELECT FILEID, COUNT(*) AS row_count FROM %s GROUP BY FILEID ORDER BY FILEID', ...
        table_name));

    % cellstr() normalizes FILEID regardless of whether the driver returned
    % it as a string array, char matrix, or cell array of char.
    fileid_strs = cellstr(per_survey.FILEID);

    db.counts = containers.Map('KeyType', 'char', 'ValueType', 'double');
    for i = 1:height(per_survey)
        fileid = upper(strtrim(fileid_strs{i}));
        db.counts(fileid) = per_survey.row_count(i);
    end
end

function violations = check_fk_integrity(conn, table_name)
    % CHECK_FK_INTEGRITY Port of scripts/sql/verification/check_fk_integrity.sql
    % Each entry counts rows in Master whose value isn't present in the
    % corresponding lookup table. 0 is clean; NULLs are always excluded.

    checks = {
        'SPECCODE',  sprintf('SELECT COUNT(*) AS cnt FROM %s WHERE SPECCODE IS NOT NULL AND SPECCODE NOT IN (SELECT Value FROM SPECCODE)', table_name)
        'PLATFORM',  sprintf('SELECT COUNT(*) AS cnt FROM %s WHERE PLATFORM IS NOT NULL AND PLATFORM NOT IN (SELECT Value FROM PLATFORM)', table_name)
        'BLOCK',     sprintf('SELECT COUNT(*) AS cnt FROM %s WHERE BLOCK IS NOT NULL AND TRY_CAST(BLOCK AS INT) NOT IN (SELECT Value FROM Block)', table_name)
        'ANHEAD',    sprintf('SELECT COUNT(*) AS cnt FROM %s WHERE ANHEAD IS NOT NULL AND ANHEAD NOT IN (SELECT Value FROM ANHEAD)', table_name)
        'DDSOURCE',  sprintf('SELECT COUNT(*) AS cnt FROM %s WHERE DDSOURCE IS NOT NULL AND DDSOURCE NOT IN (SELECT Value FROM DDSOURCE)', table_name)
        'IDSOURCE',  sprintf('SELECT COUNT(*) AS cnt FROM %s WHERE IDSOURCE IS NOT NULL AND IDSOURCE NOT IN (SELECT Value FROM IDSOURCE)', table_name)
        'TAXCODE',   sprintf('SELECT COUNT(*) AS cnt FROM %s WHERE TAXCODE IS NOT NULL AND TAXCODE NOT IN (SELECT Value FROM TAXCODE)', table_name)
        'WX',        sprintf('SELECT COUNT(*) AS cnt FROM %s WHERE WX IS NOT NULL AND WX NOT IN (SELECT Value FROM WX)', table_name)
    };

    % BEHAV1-BEHAV3 individually, BEHAV4-BEHAV15 combined, matching
    % check_fk_integrity.sql's structure.
    for b = 1:3
        field = sprintf('BEHAV%d', b);
        query = sprintf( ...
            'SELECT COUNT(*) AS cnt FROM %s WHERE %s IS NOT NULL AND %s NOT IN (SELECT Value FROM Behave)', ...
            table_name, field, field);
        checks(end+1, :) = {field, query}; %#ok<AGROW>
    end
    behav_conditions = cell(1, 12);
    for b = 4:15
        field = sprintf('BEHAV%d', b);
        behav_conditions{b-3} = sprintf( ...
            '(%s IS NOT NULL AND %s NOT IN (SELECT Value FROM Behave))', field, field);
    end
    behav_query = sprintf('SELECT COUNT(*) AS cnt FROM %s WHERE %s', ...
        table_name, strjoin(behav_conditions, ' OR '));
    checks(end+1, :) = {'BEHAV4-15', behav_query};

    violations = struct();
    for i = 1:size(checks, 1)
        field = checks{i, 1};
        query = checks{i, 2};
        try
            result = conn.fetch(query);
            count = result.cnt(1);
        catch ME
            warning('verify_migration_results:FKCheckFailed', ...
                'FK check for %s failed: %s', field, ME.message);
            count = NaN;
        end
        violations.(matlab.lang.makeValidName(field)) = count;
        fprintf('  %-10s %s\n', field, format_violation_count(count));
    end
end

function s = format_violation_count(count)
    if isnan(count)
        s = '(check failed)';
    elseif count == 0
        s = 'clean (0 violations)';
    else
        s = sprintf('%d violation(s)', count);
    end
end

function recon = reconcile_counts(source, db)
    % RECONCILE_COUNTS Compare source (split summary) vs. database per-survey counts
    recon = struct();

    source_keys = keys(source.counts);
    db_keys = keys(db.counts);

    recon.missing_in_db = {};      % in source, absent from DB entirely
    recon.mismatched = {};         % in both, row counts differ
    recon.mismatched_detail = [];  % [source_count, db_count] rows, same order as mismatched
    matched_count = 0;

    for i = 1:length(source_keys)
        key = source_keys{i};
        source_count = source.counts(key);
        if ~isKey(db.counts, key)
            recon.missing_in_db{end+1} = key; %#ok<AGROW>
        else
            matched_count = matched_count + 1;
            db_count = db.counts(key);
            if db_count ~= source_count
                recon.mismatched{end+1} = key; %#ok<AGROW>
                recon.mismatched_detail = [recon.mismatched_detail; source_count, db_count]; %#ok<AGROW>
            end
        end
    end

    recon.extra_in_db = setdiff(db_keys, source_keys);

    recon.survey_coverage_pct = 100 * matched_count / max(source.total_surveys, 1);
    recon.row_coverage_pct = 100 * db.total_rows / max(source.total_rows, 1);
    recon.matched_surveys = matched_count;
end

function print_console_summary(results, max_listed)
    fprintf('\n=== SUMMARY (paste-ready) ===\n\n');
    fprintf('Source surveys extracted:     %d\n', results.source.total_surveys);
    fprintf('Source rows extracted:        %d\n', results.source.total_rows);
    fprintf('Database surveys (distinct FILEID): %d\n', results.database.total_surveys);
    fprintf('Database rows:                 %d\n', results.database.total_rows);
    fprintf('Survey coverage:               %.1f%% (%d / %d)\n', ...
        results.reconciliation.survey_coverage_pct, ...
        results.reconciliation.matched_surveys, results.source.total_surveys);
    fprintf('Row coverage:                  %.1f%% (%d / %d)\n', ...
        results.reconciliation.row_coverage_pct, ...
        results.database.total_rows, results.source.total_rows);
    fprintf('Surveys missing from DB:       %d\n', numel(results.reconciliation.missing_in_db));
    fprintf('Surveys with row-count mismatch: %d\n', numel(results.reconciliation.mismatched));
    fprintf('Surveys in DB not in source:    %d\n', numel(results.reconciliation.extra_in_db));

    if ~isempty(results.reconciliation.missing_in_db)
        n = numel(results.reconciliation.missing_in_db);
        shown = results.reconciliation.missing_in_db(1:min(n, max_listed));
        fprintf('\nMissing from DB (showing %d of %d): %s\n', ...
            numel(shown), n, strjoin(shown, ', '));
    end
end

function write_report(results, report_file)
    fid = fopen(report_file, 'w');
    if fid == -1
        warning('verify_migration_results:CannotWriteReport', ...
            'Could not write report to %s', report_file);
        return;
    end

    fprintf(fid, '# Migration Verification Report\n\n');
    fprintf(fid, 'Generated: %s\n\n', char(results.generated_at));
    fprintf(fid, 'Source: `%s`\n\n', results.source_file);
    fprintf(fid, '---\n\n');

    fprintf(fid, '## Headline Numbers\n\n');
    fprintf(fid, '| Metric | Value |\n|---|---|\n');
    fprintf(fid, '| Source surveys extracted | %d |\n', results.source.total_surveys);
    fprintf(fid, '| Source rows extracted | %d |\n', results.source.total_rows);
    fprintf(fid, '| Database surveys (distinct FILEID) | %d |\n', results.database.total_surveys);
    fprintf(fid, '| Database rows | %d |\n', results.database.total_rows);
    fprintf(fid, '| Survey coverage | %.1f%% (%d / %d) |\n', ...
        results.reconciliation.survey_coverage_pct, ...
        results.reconciliation.matched_surveys, results.source.total_surveys);
    fprintf(fid, '| Row coverage | %.1f%% (%d / %d) |\n', ...
        results.reconciliation.row_coverage_pct, ...
        results.database.total_rows, results.source.total_rows);
    fprintf(fid, '\n---\n\n');

    fprintf(fid, '## Foreign-Key Integrity\n\n');
    fprintf(fid, '| Field | Violations |\n|---|---|\n');
    fk_fields = fieldnames(results.fk_violations);
    for i = 1:numel(fk_fields)
        fprintf(fid, '| %s | %s |\n', fk_fields{i}, ...
            format_violation_count(results.fk_violations.(fk_fields{i})));
    end
    fprintf(fid, '\n---\n\n');

    fprintf(fid, '## Surveys Missing from Database (%d)\n\n', ...
        numel(results.reconciliation.missing_in_db));
    write_fileid_list(fid, results.reconciliation.missing_in_db);

    fprintf(fid, '\n## Surveys with Row-Count Mismatch (%d)\n\n', ...
        numel(results.reconciliation.mismatched));
    if isempty(results.reconciliation.mismatched)
        fprintf(fid, '(none)\n');
    else
        fprintf(fid, '| FILEID | Source rows | Database rows |\n|---|---|---|\n');
        for i = 1:numel(results.reconciliation.mismatched)
            fprintf(fid, '| %s | %d | %d |\n', results.reconciliation.mismatched{i}, ...
                results.reconciliation.mismatched_detail(i, 1), ...
                results.reconciliation.mismatched_detail(i, 2));
        end
    end

    fprintf(fid, '\n## Surveys in Database but Not in Source (%d)\n\n', ...
        numel(results.reconciliation.extra_in_db));
    write_fileid_list(fid, results.reconciliation.extra_in_db);

    fprintf(fid, ['\n---\n\n_Note: source/database FILEID matching is case-insensitive and ' ...
        'trimmed. Source counts come from the split-summary log''s sanitized filenames; ' ...
        'if a FILEID contains characters stripped by narwc.utils.sanitize_filename, a ' ...
        'mismatch here may be a naming artifact rather than a real data gap._\n']);

    fclose(fid);
end

function write_fileid_list(fid, fileids)
    if isempty(fileids)
        fprintf(fid, '(none)\n');
        return;
    end
    for i = 1:numel(fileids)
        fprintf(fid, '- %s\n', fileids{i});
    end
end
