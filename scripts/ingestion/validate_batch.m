% VALIDATE_BATCH validates one pipeline batch by looking at its files and the database
%
% Generalizes what used to be migration-only step3_validate_migration.m so
% any source (legacy or contributor) can validate a batch, not just the
% legacy migration. "Batch" here is the same concept convert_contributor_batch
% and upload_contributor_batch use: a batch_id recorded as rows in the
% batch ledger (data/surveys/batch_log.csv, see narwc.ingestion.append_batch_log).
%
% Without an explicit BatchId, this looks up the most recent 'convert' row
% in the ledger (optionally narrowed to one Source) and uses that -- so
% "the current batch" is always answerable from the ledger, not guessed
% from "whatever's most recently modified in pending/".

% FIXME: this script generates a single report, but it doesn't have a clear
% method for analyzing a after multiple runs or for distinguishing between those
% runs. Need to think through how to handle this.

% FIXME: where does this compare the splitting of the database into surveys vs
% the upload process. I think right now, it just produces a report. A true
% validator would look at the results and compare the old database to the new
% one. I'm not sure that will be possible without doing a targeted pull from the
% old SAS database and replicating that pull on the SQL database. I can maybe
% write a script that generates equivalent pulls and another that compares the results.

function results = validate_batch(options)
    % VALIDATE_BATCH Validate one batch's files and generate a report
    %
    % Analyzes processed/rejected/pending surveys belonging to one batch
    % (scoped by that batch's split-summary FILEID list, so stats don't
    % blend across batches once pending/processed/ hold more than one).
    % The error/warning breakdown re-runs apply_known_fixes + SurveyValidator
    % in-memory (read-only, no DB writes) against the current config, rather
    % than scraping free-text log files — see tally_validation_by_rule below.
    %
    % Usage:
    %   validate_batch()
    %   validate_batch('Source', 'legacy')
    %   validate_batch('BatchId', '2026-07-26_14-30-12_legacy')
    %   validate_batch('GenerateCharts', true, 'ReportFormat', 'markdown')

    arguments
        options.BaseDir char = 'data/surveys'
        options.BatchId char = ''
        options.Source char = ''
        options.ConfigProfile char = 'routine'
        options.GenerateCharts logical = true
        options.ReportFormat char {mustBeMember(options.ReportFormat, {'markdown', 'text', 'html'})} = 'markdown'
        options.DetailedErrorAnalysis logical = true
    end

    fprintf('=== Validating Batch ===\n\n');

    [batch_id, split_summary_file] = resolve_batch(options.BatchId, options.Source);
    fprintf('Batch ID: %s\n', batch_id);
    fprintf('Split summary: %s\n\n', split_summary_file);

    report_dir = fullfile('reports', 'batches', batch_id);
    if ~exist(report_dir, 'dir')
        mkdir(report_dir);
    end

    % Define directories
    processed_dir = fullfile(options.BaseDir, 'processed');
    rejected_dir = fullfile(options.BaseDir, 'rejected');
    pending_dir = fullfile(options.BaseDir, 'pending');
    log_dir = fileparts(options.BaseDir);

    % Verify directories exist
    if ~exist(processed_dir, 'dir')
        error('Processed directory not found: %s', processed_dir);
    end
    if ~exist(rejected_dir, 'dir')
        warning('Rejected directory not found: %s. Creating it.', rejected_dir);
        mkdir(rejected_dir);
    end

    try
        [batch_source, ~] = narwc.ingestion.load_split_summary(split_summary_file);
        batch_fileids = keys(batch_source.counts);

        % Collect statistics from directories, scoped to this batch's FILEIDs
        fprintf('Analyzing batch results...\n');
        results = analyze_batch_directories(processed_dir, rejected_dir, pending_dir, batch_fileids);

        results.baseline = batch_source;
        results.baseline.available = true;
        results.baseline_file = split_summary_file;

        % Calculate metrics
        fprintf('Calculating metrics...\n');
        results.metrics = calculate_batch_metrics(results, options.BaseDir);

        % Analyze errors in detail if requested
        if options.DetailedErrorAnalysis && results.metrics.failed_uploads > 0
            fprintf('Analyzing errors (re-validating rejected/pending surveys by rule)...\n');
            try
                batch_config = load_config(options.ConfigProfile);
            catch
                batch_config = load_config();
            end
            csv_files = collect_survey_csv_paths(batch_fileids, rejected_dir, pending_dir);
            results.error_analysis = narwc.ingestion.tally_validation_by_rule(csv_files, batch_config);

            [flat_errors, detail_errors] = narwc.ingestion.flatten_tally_map(results.error_analysis.errors_by_rule);
            [flat_warn, detail_warn]     = narwc.ingestion.flatten_tally_map(results.error_analysis.warnings_outstanding_by_rule);
            [~, detail_ack]              = narwc.ingestion.flatten_tally_map(results.error_analysis.warnings_acknowledged_by_rule);

            results.error_analysis.error_breakdown = narwc.ingestion.merge_flat_counts(flat_errors, flat_warn);
            results.error_analysis.detail_errors_by_rule                = detail_errors;
            results.error_analysis.detail_warnings_outstanding_by_rule  = detail_warn;
            results.error_analysis.detail_warnings_acknowledged_by_rule = detail_ack;

            results.metrics.error_breakdown = results.error_analysis.error_breakdown;
        end

        % Display summary
        display_validation_summary(results, rejected_dir, log_dir);

        % Generate visualizations
        if options.GenerateCharts
            try
                generate_validation_charts(results, report_dir);
            catch chartErr
                warning('Failed to generate charts: %s', chartErr.message);
                fprintf('Continuing without charts...\n');
            end
        end

        % Save results
        try
            results_file = fullfile(report_dir, 'validation_results.mat');
            save(results_file, 'results');
            fprintf('✓ Validation results saved to: %s\n\n', results_file);
        catch saveErr
            warning('Failed to save results: %s', saveErr.message);
        end

        % Generate comprehensive report
        try
            report_file = fullfile(report_dir, sprintf('report.%s', ...
                get_file_extension(options.ReportFormat)));
            generate_migration_report(results, report_file, options.ReportFormat);
            fprintf('Report saved to: %s\n', report_file);
        catch reportErr
            warning('Failed to generate report: %s', reportErr.message);
        end

        fprintf('\n✓ Batch validation complete!\n\n');

        narwc.ingestion.append_batch_log(struct( ...
            'batch_id', batch_id, 'stage', 'validate', ...
            'input', report_dir, 'output', report_dir, ...
            'notes', sprintf('%.1f%% success (%d/%d)', results.metrics.success_rate, ...
                results.metrics.successful_uploads, results.metrics.total_records)));

    catch ME
        % Detailed error reporting
        fprintf(2, '\nERROR during validation:\n');
        fprintf(2, 'Message: %s\n', ME.message);
        fprintf(2, 'Location: %s (line %d)\n\n', ME.stack(1).name, ME.stack(1).line);

        fprintf('Stack trace:\n');
        for i = 1:min(3, length(ME.stack))
            fprintf('  %d. %s (line %d)\n', i, ME.stack(i).name, ME.stack(i).line);
        end
        fprintf('\n');

        rethrow(ME);
    end
end

%% Helper Functions

function [batch_id, split_summary_file] = resolve_batch(batch_id_option, source_option)
    % RESOLVE_BATCH Resolve a batch_id + its split-summary log path, either
    % from an explicit BatchId or by picking the most recent 'convert' row
    % in the ledger (optionally narrowed to one source).

    ledger = narwc.ingestion.read_batch_log();

    if ~isempty(batch_id_option)
        is_match = strcmp(ledger.stage, 'convert') & strcmp(ledger.batch_id, batch_id_option);
        matches = ledger(is_match, :);
        if height(matches) == 0
            error('validate_batch:UnknownBatchId', ...
                'No convert entry found in the batch ledger for batch_id ''%s''.', batch_id_option);
        end
        batch_id = batch_id_option;
        split_summary_file = matches.output{end};
        return;
    end

    is_convert = strcmp(ledger.stage, 'convert');
    if ~isempty(source_option)
        is_convert = is_convert & strcmp(ledger.source, source_option);
    end
    candidates = ledger(is_convert, :);
    if height(candidates) == 0
        error('validate_batch:NoBatchFound', ...
            ['No convert entries found in the batch ledger%s. Run convert_contributor_batch ' ...
             'first, or pass ''BatchId'' explicitly.'], ...
            merge_source_suffix(source_option));
    end

    [~, order] = sort(candidates.timestamp);
    batch_id = candidates.batch_id{order(end)};
    split_summary_file = candidates.output{order(end)};
end

function s = merge_source_suffix(source_option)
    if isempty(source_option)
        s = '';
    else
        s = sprintf(' for source ''%s''', source_option);
    end
end

function results = analyze_batch_directories(processed_dir, rejected_dir, pending_dir, batch_fileids)
    % ANALYZE_BATCH_DIRECTORIES Analyze the three directories, scoped to
    % this batch's FILEIDs (matching is case-insensitive, mirroring
    % load_split_summary's own upper()-normalized counts map).

    results = struct();

    processed_files = filter_files_to_batch(dir(fullfile(processed_dir, '*.csv')), batch_fileids);
    failed_files = filter_files_to_batch(dir(fullfile(rejected_dir, '*.csv')), batch_fileids);

    % Remove summary files
    processed_files = processed_files(~startsWith({processed_files.name}, '_'));
    failed_files = failed_files(~startsWith({failed_files.name}, '_'));

    % Count pending files if directory exists
    pending_count = 0;
    if exist(pending_dir, 'dir')
        pending_files = filter_files_to_batch(dir(fullfile(pending_dir, '*.csv')), batch_fileids);
        pending_files = pending_files(~startsWith({pending_files.name}, '_'));
        pending_count = length(pending_files);
        results.pending_files = {pending_files.name}';
    end

    % Store counts
    results.processed_count = length(processed_files);
    results.failed_count = length(failed_files);
    results.pending_count = pending_count;
    results.total_count = results.processed_count + results.failed_count + results.pending_count;

    % Store file lists
    results.processed_files = {processed_files.name}';
    results.failed_files = {failed_files.name}';

    % Get file sizes (optional but useful)
    results.processed_total_size = sum([processed_files.bytes]);
    results.failed_total_size = sum([failed_files.bytes]);

    fprintf('Found (this batch):\n');
    fprintf('  - %d processed surveys\n', results.processed_count);
    fprintf('  - %d failed surveys\n', results.failed_count);
    fprintf('  - %d pending surveys\n', results.pending_count);
    fprintf('  - %d total surveys\n', results.total_count);
end

function filtered = filter_files_to_batch(files, batch_fileids)
    % FILTER_FILES_TO_BATCH Keep only entries whose filename stem (FILEID)
    % appears in batch_fileids. Same technique as BatchUploader.filterToBatch.
    if isempty(batch_fileids)
        filtered = files;
        return;
    end
    names = {files.name};
    [~, stems] = cellfun(@fileparts, names, 'UniformOutput', false);
    keep = ismember(upper(stems), batch_fileids);
    filtered = files(keep);
end

function metrics = calculate_batch_metrics(results, base_dir)
    % Calculate comprehensive success/failure metrics

    metrics = struct();

    % Overall metrics
    metrics.total_records = results.total_count;
    metrics.successful_uploads = results.processed_count;
    metrics.failed_uploads = results.failed_count;
    metrics.pending_uploads = results.pending_count;

    if metrics.total_records > 0
        metrics.success_rate = (metrics.successful_uploads / metrics.total_records) * 100;
        metrics.failure_rate = (metrics.failed_uploads / metrics.total_records) * 100;
        metrics.pending_rate = (metrics.pending_uploads / metrics.total_records) * 100;
    else
        metrics.success_rate = 0;
        metrics.failure_rate = 0;
        metrics.pending_rate = 0;
    end

    % Extraction (convert-stage) baseline, so the funnel covers
    % raw-rows -> extracted-surveys -> attempted -> uploaded, not just
    % the post-upload folder split.
    if isfield(results, 'baseline') && results.baseline.available
        metrics.extracted_surveys = results.baseline.total_surveys;
        metrics.extracted_rows    = results.baseline.total_rows;
        if metrics.extracted_surveys > 0
            metrics.extraction_to_upload_rate = ...
                (metrics.successful_uploads / metrics.extracted_surveys) * 100;
        end
    end

    % Analyze survey types from filenames
    if ~isempty(results.processed_files) || ~isempty(results.failed_files)
        metrics.by_survey_type = analyze_survey_types(results);
    end

    % Get database statistics if possible
    try
        conn = narwc.db.Connection.create();
        try
            metrics.database_stats = get_database_statistics(conn);
        finally
            conn.close();
        end
    catch
        % Database stats optional
        metrics.database_stats = struct('available', false);
    end
end

function type_metrics = analyze_survey_types(results)
    % ANALYZE_SURVEY_TYPES Extract survey type statistics from filenames
    % Uses first 2 characters of filename as survey type identifier

    all_files = [results.processed_files; results.failed_files];

    % Track survey types
    survey_types = containers.Map();

    for i = 1:length(all_files)
        filename = all_files{i};

        % Extract first 2 characters as survey type
        if length(filename) >= 2
            survey_type = upper(filename(1:2));
        else
            survey_type = 'XX';  % Unknown
        end

        % Track success/failure for this type
        is_successful = ismember(filename, results.processed_files);

        if isKey(survey_types, survey_type)
            stats = survey_types(survey_type);
            stats.total = stats.total + 1;
            if is_successful
                stats.successful = stats.successful + 1;
            else
                stats.failed = stats.failed + 1;
            end
            survey_types(survey_type) = stats;
        else
            stats = struct();
            stats.total = 1;
            stats.successful = double(is_successful);
            stats.failed = double(~is_successful);
            survey_types(survey_type) = stats;
        end
    end

    % Convert to struct with success rates
    type_metrics = struct();
    type_names = keys(survey_types);

    for i = 1:length(type_names)
        type_name = type_names{i};
        stats = survey_types(type_name);
        stats.success_rate = (stats.successful / stats.total) * 100;

        % Use type code directly as field name (e.g., Type_RU, Type_CA)
        safe_name = matlab.lang.makeValidName(['Type_' type_name]);
        type_metrics.(safe_name) = stats;
    end
end

function paths = collect_survey_csv_paths(batch_fileids, varargin)
    % COLLECT_SURVEY_CSV_PATHS Full paths of survey CSVs (excluding files
    % starting with '_', e.g. the split-summary log) across one or more
    % dirs, scoped to this batch's FILEIDs.
    paths = {};
    for i = 1:numel(varargin)
        d = varargin{i};
        if ~exist(d, 'dir')
            continue;
        end
        files = filter_files_to_batch(dir(fullfile(d, '*.csv')), batch_fileids);
        files = files(~startsWith({files.name}, '_'));
        for j = 1:numel(files)
            paths{end+1} = fullfile(files(j).folder, files(j).name); %#ok<AGROW>
        end
    end
end

function db_stats = get_database_statistics(conn)
    % GET_DATABASE_STATISTICS Get statistics from database

    db_stats = struct();

    try
        % Count total surveys
        query = 'SELECT COUNT(DISTINCT FILEID) as total FROM Master';
        result = conn.fetch(query);
        db_stats.total_surveys = result.total;

        db_stats.available = true;

    catch ME
        warning('Could not retrieve database statistics: %s', ME.message);
        db_stats.available = false;
    end
end

function display_validation_summary(results, rejected_dir, log_dir) %#ok<INUSD>
    % Display comprehensive validation summary

    try
        fprintf('\n╔════════════════════════════════════════════════╗\n');
        fprintf('║           BATCH VALIDATION SUMMARY            ║\n');
        fprintf('╚════════════════════════════════════════════════╝\n\n');

        if ~isfield(results, 'metrics')
            fprintf('No metrics available\n');
            return;
        end

        m = results.metrics;

        % Stage funnel (extraction baseline -> attempted -> uploaded), when
        % a convert-stage split-summary log is available.
        if isfield(m, 'extracted_surveys')
            fprintf('Stage Funnel:\n');
            fprintf('   Extracted (convert):  %d surveys, %d rows\n', ...
                m.extracted_surveys, m.extracted_rows);
            fprintf('   Attempted (upload):    %d surveys\n', m.total_records);
            fprintf('   Uploaded:              %d surveys (%.1f%% of extracted)\n\n', ...
                m.successful_uploads, m.extraction_to_upload_rate);
        end

        % Overall statistics
        fprintf('Overall Statistics:\n');
        fprintf('   Total Surveys:            %d\n', m.total_records);
        fprintf('   Successfully Processed: %d (%.2f%%)\n', m.successful_uploads, m.success_rate);
        fprintf('   Failed:                 %d (%.2f%%)\n', m.failed_uploads, m.failure_rate);
        if m.pending_uploads > 0
            fprintf('   Pending:                %d (%.2f%%)\n', m.pending_uploads, m.pending_rate);
        end
        fprintf('\n');

        % Success rate visualization
        fprintf('   Success Rate: ');
        print_progress_bar(m.success_rate);
        fprintf('\n\n');

        % Rule-based error/warning breakdown
        if isfield(results, 'error_analysis')
            ea = results.error_analysis;

            print_rule_table('Blocking Errors by Rule', ea.detail_errors_by_rule, 15);
            print_rule_table('Outstanding (Unacknowledged) Warnings by Rule', ...
                ea.detail_warnings_outstanding_by_rule, 15);
            print_rule_table('Acknowledged Warnings by Rule', ...
                ea.detail_warnings_acknowledged_by_rule, 15);

            fprintf('Surveys analyzed for this breakdown: %d (%d with errors, %d with outstanding warnings)\n', ...
                ea.surveys_analyzed, ea.surveys_with_errors, ea.surveys_with_warnings);

            if ~isempty(ea.would_now_pass)
                fprintf('%d survey(s) currently in rejected/ now re-validate CLEAN ', ...
                    numel(ea.would_now_pass));
                fprintf('(config/overrides/lookup tables changed since last run -- re-run, don''t investigate):\n');
                shown = ea.would_now_pass(1:min(10, numel(ea.would_now_pass)));
                fprintf('   %s\n', strjoin(shown, ', '));
                if numel(ea.would_now_pass) > numel(shown)
                    fprintf('   ... and %d more\n', numel(ea.would_now_pass) - numel(shown));
                end
            end
            fprintf('\n');

            % Show sample errors
            if ~isempty(ea.detailed_errors)
                fprintf('Sample Errors:\n');
                num_to_show = min(10, length(ea.detailed_errors));
                for i = 1:num_to_show
                    error_text = ea.detailed_errors{i};
                    if length(error_text) > 100
                        error_text = [error_text(1:97) '...'];
                    end
                    fprintf('   %d. %s\n', i, error_text);
                end
                if length(ea.detailed_errors) > num_to_show
                    fprintf('   ... and %d more (see the rule tables above)\n', ...
                        length(ea.detailed_errors) - num_to_show);
                end
                fprintf('\n');
            end
        end

        % Survey type breakdown
        if isfield(m, 'by_survey_type') && ~isempty(fieldnames(m.by_survey_type))
            fprintf('Success Rates by Survey Type (2-char code):\n');
            type_fields = fieldnames(m.by_survey_type);

            % Sort by type name for consistent display
            [~, sort_idx] = sort(type_fields);

            for i = 1:length(type_fields)
                idx = sort_idx(i);
                field_name = type_fields{idx};
                type_data = m.by_survey_type.(field_name);

                % Extract 2-char code from field name (remove 'Type_' prefix)
                if startsWith(field_name, 'Type_')
                    type_code = field_name(6:end);
                else
                    type_code = field_name;
                end

                fprintf('   %s: %d/%d (%.1f%%) ', ...
                    type_code, ...
                    type_data.successful, ...
                    type_data.total, ...
                    type_data.success_rate);
                print_progress_bar(type_data.success_rate, 30);
                fprintf('\n');
            end
            fprintf('\n');
        end

        % Database statistics
        if isfield(m, 'database_stats') && m.database_stats.available
            fprintf('Database Statistics:\n');
            fprintf('   Records in database: %d\n', m.database_stats.total_surveys);
            if isfield(m.database_stats, 'date_range')
                fprintf('   Date range: %s to %s\n', ...
                    char(m.database_stats.date_range.min_date), ...
                    char(m.database_stats.date_range.max_date));
            end
            fprintf('\n');
        end

        % Overall status
        if m.success_rate >= 95
            fprintf('Batch Status: EXCELLENT (≥95%% success)\n');
        elseif m.success_rate >= 90
            fprintf('Batch Status: GOOD (≥90%% success)\n');
        elseif m.success_rate >= 80
            fprintf('Batch Status: ACCEPTABLE (≥80%% success)\n');
        else
            fprintf('Batch Status: NEEDS ATTENTION (<80%% success)\n');
        end

        fprintf('\n%s\n', repmat('─', 1, 50));

    catch ME
        fprintf(2, 'ERROR displaying summary: %s\n', ME.message);
    end
end

function print_rule_table(title, detail_struct, max_rows)
    % PRINT_RULE_TABLE Print the top max_rows entries of a rule-keyed detail
    % struct (as produced by flatten_tally_map), sorted by count descending.
    keys_list = fieldnames(detail_struct);
    if isempty(keys_list)
        return;
    end

    counts = zeros(numel(keys_list), 1);
    for i = 1:numel(keys_list)
        counts(i) = detail_struct.(keys_list{i}).count;
    end
    [~, order] = sort(counts, 'descend');

    fprintf('%s:\n', title);
    n = min(max_rows, numel(order));
    for i = 1:n
        e = detail_struct.(keys_list{order(i)});
        survey_word = 'surveys';
        if e.survey_count == 1
            survey_word = 'survey';
        end
        fprintf('   %-55s %5d  (%d %s)\n', e.rule_id, e.count, e.survey_count, survey_word);
    end
    if numel(order) > n
        fprintf('   ... and %d more rule(s)\n', numel(order) - n);
    end
    fprintf('\n');
end

function print_progress_bar(percentage, width)
    % Print a text-based progress bar

    if nargin < 2
        width = 40;
    end

    filled = round((percentage / 100) * width);
    empty = width - filled;

    fprintf('[%s%s] %.1f%%', ...
        repmat('█', 1, filled), ...
        repmat('░', 1, empty), ...
        percentage);
end

function formatted = format_field_name(field_name)
    % Convert field_name to readable format
    formatted = strrep(field_name, '_', ' ');
    formatted = regexprep(formatted, '\<(\w)', '${upper($1)}');
end

function ext = get_file_extension(format)
    switch format
        case 'markdown'
            ext = 'md';
        case 'html'
            ext = 'html';
        otherwise
            ext = 'txt';
    end
end

function generate_validation_charts(results, charts_dir)
    % GENERATE_VALIDATION_CHARTS Generate visualization charts

    fprintf('Generating validation charts...\n');

    if ~isfield(results, 'metrics')
        warning('No metrics available for chart generation');
        return;
    end

    m = results.metrics;

    % Create figure with multiple subplots
    fig = figure('Name', 'Batch Validation Results', ...
                 'Position', [100, 100, 1400, 900], ...
                 'Color', 'white');

    % 1. Success/Failure Pie Chart
    subplot(2, 3, 1);
    labels = {'Successful', 'Failed'};
    values = [m.successful_uploads, m.failed_uploads];

    if m.pending_uploads > 0
        labels{end+1} = 'Pending';
        values(end+1) = m.pending_uploads;
    end

    pie(values, labels);
    title('Upload Status Distribution', 'FontSize', 12, 'FontWeight', 'bold');
    colormap([0.2 0.8 0.2; 0.8 0.2 0.2; 0.8 0.8 0.2]);

    % 2. Error/Warning-by-Rule Bar Chart (top 10 by count)
    subplot(2, 3, 2);
    if isfield(m, 'error_breakdown') && ~isempty(fieldnames(m.error_breakdown))
        error_breakdown = m.error_breakdown;
        error_fields = fieldnames(error_breakdown);
        error_counts = structfun(@(x) x, error_breakdown);

        [sorted_counts, sort_idx] = sort(error_counts, 'descend');
        top_n = min(10, numel(sorted_counts));
        error_counts = sorted_counts(1:top_n);
        error_labels = error_fields(sort_idx(1:top_n));

        non_zero_idx = error_counts > 0;
        if any(non_zero_idx)
            error_counts = error_counts(non_zero_idx);
            error_labels = error_labels(non_zero_idx);

            for i = 1:length(error_labels)
                error_labels{i} = format_field_name(error_labels{i});
            end

            bar(error_counts, 'FaceColor', [0.8 0.3 0.3]);
            set(gca, 'XTickLabel', error_labels);
            xtickangle(45);
            title('Top Rule Violations (errors + outstanding warnings)', ...
                'FontSize', 11, 'FontWeight', 'bold');
            ylabel('Count');
            grid on;
        else
            text(0.5, 0.5, 'No errors detected', ...
                'HorizontalAlignment', 'center', 'FontSize', 12);
            axis off;
            title('Rule Violations', 'FontSize', 12, 'FontWeight', 'bold');
        end
    else
        text(0.5, 0.5, 'No error data available', ...
            'HorizontalAlignment', 'center', 'FontSize', 12);
        axis off;
        title('Rule Violations', 'FontSize', 12, 'FontWeight', 'bold');
    end

    % 3. Success Rate by Survey Type
    subplot(2, 3, 3);
    if isfield(m, 'by_survey_type') && ~isempty(fieldnames(m.by_survey_type))
        type_fields = fieldnames(m.by_survey_type);
        success_rates = zeros(length(type_fields), 1);
        type_labels = cell(length(type_fields), 1);

        for i = 1:length(type_fields)
            success_rates(i) = m.by_survey_type.(type_fields{i}).success_rate;
            % Extract 2-char code
            if startsWith(type_fields{i}, 'Type_')
                type_labels{i} = type_fields{i}(6:end);
            else
                type_labels{i} = type_fields{i};
            end
        end

        barh(success_rates);
        set(gca, 'YTickLabel', type_labels);
        xlabel('Success Rate (%)');
        title('Success Rate by Survey Type', 'FontSize', 12, 'FontWeight', 'bold');
        xlim([0, 100]);
        grid on;

        % Color bars based on success rate
        h = get(gca, 'Children');
        if ~isempty(h)
            colors = zeros(length(success_rates), 3);
            for i = 1:length(success_rates)
                if success_rates(i) >= 90
                    colors(i, :) = [0.2 0.8 0.2];  % Green
                elseif success_rates(i) >= 70
                    colors(i, :) = [0.8 0.8 0.2];  % Yellow
                else
                    colors(i, :) = [0.8 0.2 0.2];  % Red
                end
            end
            set(h, 'FaceColor', 'flat');
            h.CData = colors;
        end
    else
        text(0.5, 0.5, 'No survey type data', ...
            'HorizontalAlignment', 'center', 'FontSize', 12);
        axis off;
        title('Success Rate by Survey Type', 'FontSize', 12, 'FontWeight', 'bold');
    end

    % 4. Success Rate Gauge
    subplot(2, 3, 4);
    draw_gauge(m.success_rate);
    title(sprintf('Overall Success Rate: %.1f%%', m.success_rate), ...
        'FontSize', 12, 'FontWeight', 'bold');

    % 5. Stacked Bar Chart - Success/Failure by Type
    subplot(2, 3, 5);
    if isfield(m, 'by_survey_type') && ~isempty(fieldnames(m.by_survey_type))
        type_fields = fieldnames(m.by_survey_type);
        successful_counts = zeros(length(type_fields), 1);
        failed_counts = zeros(length(type_fields), 1);
        type_labels = cell(length(type_fields), 1);

        for i = 1:length(type_fields)
            successful_counts(i) = m.by_survey_type.(type_fields{i}).successful;
            failed_counts(i) = m.by_survey_type.(type_fields{i}).failed;
            % Extract 2-char code
            if startsWith(type_fields{i}, 'Type_')
                type_labels{i} = type_fields{i}(6:end);
            else
                type_labels{i} = type_fields{i};
            end
        end

        bar([successful_counts, failed_counts], 'stacked');
        set(gca, 'XTickLabel', type_labels);
        ylabel('Count');
        title('Survey Counts by Type', 'FontSize', 12, 'FontWeight', 'bold');
        legend({'Successful', 'Failed'}, 'Location', 'best');
        grid on;
        xtickangle(45);
    else
        text(0.5, 0.5, 'No survey type data', ...
            'HorizontalAlignment', 'center', 'FontSize', 12);
        axis off;
        title('Survey Counts by Type', 'FontSize', 12, 'FontWeight', 'bold');
    end

    % 6. Summary Statistics Table
    subplot(2, 3, 6);
    axis off;

    % Create text summary
    y_pos = 0.9;
    line_height = 0.08;

    text(0.05, y_pos, '\bfBatch Summary', 'FontSize', 13);
    y_pos = y_pos - line_height * 1.5;

    text(0.05, y_pos, sprintf('Total Surveys: %d', m.total_records), 'FontSize', 11);
    y_pos = y_pos - line_height;

    text(0.05, y_pos, sprintf('✓ Successful: %d (%.1f%%)', ...
        m.successful_uploads, m.success_rate), 'FontSize', 11, 'Color', [0.2 0.6 0.2]);
    y_pos = y_pos - line_height;

    text(0.05, y_pos, sprintf('✗ Failed: %d (%.1f%%)', ...
        m.failed_uploads, m.failure_rate), 'FontSize', 11, 'Color', [0.8 0.2 0.2]);
    y_pos = y_pos - line_height;

    if m.pending_uploads > 0
        text(0.05, y_pos, sprintf('⏳ Pending: %d (%.1f%%)', ...
            m.pending_uploads, m.pending_rate), 'FontSize', 11, 'Color', [0.6 0.6 0.2]);
        y_pos = y_pos - line_height;
    end

    y_pos = y_pos - line_height * 0.5;

    % Status indicator
    status_text = get_status_text(m.success_rate);
    if m.success_rate >= 95
        status_color = [0.2 0.7 0.2];
    elseif m.success_rate >= 90
        status_color = [0.4 0.7 0.3];
    elseif m.success_rate >= 80
        status_color = [0.8 0.6 0.2];
    else
        status_color = [0.8 0.2 0.2];
    end

    text(0.05, y_pos, '\bfStatus:', 'FontSize', 11);
    y_pos = y_pos - line_height;
    text(0.05, y_pos, status_text, 'FontSize', 11, 'Color', status_color);

    % Database stats if available
    if isfield(m, 'database_stats') && m.database_stats.available
        y_pos = y_pos - line_height * 1.5;
        text(0.05, y_pos, '\bfDatabase Info:', 'FontSize', 11);
        y_pos = y_pos - line_height;
        text(0.05, y_pos, sprintf('Records: %d', m.database_stats.total_surveys), 'FontSize', 10);
    end

    title('Summary', 'FontSize', 12, 'FontWeight', 'bold');

    % Save figure
    if ~exist(charts_dir, 'dir')
        mkdir(charts_dir);
    end

    chart_file = fullfile(charts_dir, 'validation_charts.png');
    saveas(fig, chart_file);

    % Also save as fig for interactive viewing
    fig_file = fullfile(charts_dir, 'validation_charts.fig');
    savefig(fig, fig_file);

    fprintf('Charts saved to:\n');
    fprintf('   - %s\n', chart_file);
    fprintf('   - %s\n', fig_file);
end

function draw_gauge(percentage)
    % DRAW_GAUGE Draw a gauge chart for success rate

    % Draw outer arc
    theta = linspace(pi, 0, 100);
    x = cos(theta);
    y = sin(theta);
    plot(x, y, 'k-', 'LineWidth', 2);
    hold on;

    % Color zones (Red: 0-60%, Yellow: 60-90%, Green: 90-100%)
    % Red zone (180° to 108°)
    fill([cos(linspace(pi, pi*0.6, 50)), 0], ...
         [sin(linspace(pi, pi*0.6, 50)), 0], ...
         [0.9 0.2 0.2], 'EdgeColor', 'none', 'FaceAlpha', 0.3);

    % Yellow zone (108° to 36°)
    fill([cos(linspace(pi*0.6, pi*0.2, 50)), 0], ...
         [sin(linspace(pi*0.6, pi*0.2, 50)), 0], ...
         [0.9 0.9 0.2], 'EdgeColor', 'none', 'FaceAlpha', 0.3);

    % Green zone (36° to 0°)
    fill([cos(linspace(pi*0.2, 0, 50)), 0], ...
         [sin(linspace(pi*0.2, 0, 50)), 0], ...
         [0.2 0.9 0.2], 'EdgeColor', 'none', 'FaceAlpha', 0.3);

    % Add percentage markers
    markers = [0, 25, 50, 75, 100];
    for i = 1:length(markers)
        angle = pi - (markers(i)/100) * pi;
        text(1.15*cos(angle), 1.15*sin(angle), sprintf('%d%%', markers(i)), ...
            'HorizontalAlignment', 'center', 'FontSize', 9);
    end

    % Draw needle
    needle_angle = pi - (percentage/100) * pi;
    needle_length = 0.85;

    % Needle shaft
    plot([0, needle_length*cos(needle_angle)], [0, needle_length*sin(needle_angle)], ...
         'r-', 'LineWidth', 4);

    % Needle tip
    plot(needle_length*cos(needle_angle), needle_length*sin(needle_angle), ...
         'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');

    % Center hub
    plot(0, 0, 'ko', 'MarkerSize', 12, 'MarkerFaceColor', 'k');

    % Display percentage in center
    text(0, -0.3, sprintf('%.1f%%', percentage), ...
        'HorizontalAlignment', 'center', 'FontSize', 14, 'FontWeight', 'bold');

    axis equal;
    axis([-1.3, 1.3, -0.5, 1.3]);
    axis off;
    hold off;
end

function status = get_status_text(success_rate)
    if success_rate >= 95
        status = 'EXCELLENT';
    elseif success_rate >= 90
        status = 'GOOD';
    elseif success_rate >= 80
        status = 'ACCEPTABLE';
    else
        status = 'NEEDS ATTENTION';
    end
end
