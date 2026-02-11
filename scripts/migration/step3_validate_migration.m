function results = step3_validate_migration(options)
    % STEP3_VALIDATE_MIGRATION Step 3: Validate migration and generate report
    %
    % Analyzes processed and failed surveys from the migration directories
    %
    % Usage:
    %   step3_validate_migration()
    %   results = step3_validate_migration('BaseDir', 'data/legacy/surveys')
    %   step3_validate_migration('GenerateCharts', true, 'ReportFormat', 'markdown')
    
    arguments
        options.BaseDir char = 'data/legacy/surveys'
        options.GenerateCharts logical = true
        options.ReportFormat char {mustBeMember(options.ReportFormat, {'markdown', 'text', 'html'})} = 'markdown'
        options.DetailedErrorAnalysis logical = true
    end
    
    fprintf('=== Step 3: Validating Migration ===\n\n');
    
    % Define directories
    processed_dir = fullfile(options.BaseDir, 'processed');
    failed_dir = fullfile(options.BaseDir, 'failed');
    pending_dir = fullfile(options.BaseDir, 'pending');
    
    % Verify directories exist
    if ~exist(processed_dir, 'dir')
        error('Processed directory not found: %s', processed_dir);
    end
    if ~exist(failed_dir, 'dir')
        warning('Failed directory not found: %s. Creating it.', failed_dir);
        mkdir(failed_dir);
    end
    
    try
        % Collect statistics from directories
        fprintf('Analyzing migration results...\n');
        results = analyze_migration_directories(processed_dir, failed_dir, pending_dir);
        
        % Calculate metrics
        fprintf('Calculating metrics...\n');
        results.metrics = calculate_migration_metrics(results, options.BaseDir);
        
        % Analyze errors in detail if requested
        if options.DetailedErrorAnalysis && results.metrics.failed_uploads > 0
            fprintf('Analyzing errors...\n');
            results.error_analysis = analyze_failed_surveys(failed_dir);
            results.metrics.error_breakdown = results.error_analysis.error_breakdown;
        end
        
        % Display summary
        display_validation_summary(results, failed_dir);
        
        % Generate visualizations
        if options.GenerateCharts
            try
                generate_validation_charts(results);
            catch chartErr
                warning('Failed to generate charts: %s', chartErr.message);
                fprintf('Continuing without charts...\n');
            end
        end
        
        % Save results
        try
            results_dir = fileparts('data/legacy/validation_results.mat');
            if ~exist(results_dir, 'dir')
                mkdir(results_dir);
            end
            results_file = 'data/legacy/validation_results.mat';
            save(results_file, 'results');
            fprintf('✓ Validation results saved to: %s\n\n', results_file);
        catch saveErr
            warning('Failed to save results: %s', saveErr.message);
        end
        
        % Generate comprehensive report
        try
            report_file = sprintf('reports/migration/migration_report.%s', ...
                get_file_extension(options.ReportFormat));
            
            % Ensure directory exists
            report_dir = fileparts(report_file);
            if ~exist(report_dir, 'dir')
                mkdir(report_dir);
            end
            
            generate_migration_report(results, report_file, options.ReportFormat);
            fprintf('✓ Report saved to: %s\n', report_file);
        catch reportErr
            warning('Failed to generate report: %s', reportErr.message);
        end
        
        fprintf('\n✓ Migration validation complete!\n\n');
        
    catch ME
        % Detailed error reporting
        fprintf(2, '\n❌ ERROR during validation:\n');
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

function results = analyze_migration_directories(processed_dir, failed_dir, pending_dir)
    % ANALYZE_MIGRATION_DIRECTORIES Analyze the three directories
    
    results = struct();
    
    % Get list of files in each directory
    processed_files = dir(fullfile(processed_dir, '*.csv'));
    failed_files = dir(fullfile(failed_dir, '*.csv'));
    
    % Remove summary files
    processed_files = processed_files(~startsWith({processed_files.name}, '_'));
    failed_files = failed_files(~startsWith({failed_files.name}, '_'));
    
    % Count pending files if directory exists
    pending_count = 0;
    if exist(pending_dir, 'dir')
        pending_files = dir(fullfile(pending_dir, '*.csv'));
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
    
    fprintf('Found:\n');
    fprintf('  - %d processed surveys\n', results.processed_count);
    fprintf('  - %d failed surveys\n', results.failed_count);
    fprintf('  - %d pending surveys\n', results.pending_count);
    fprintf('  - %d total surveys\n', results.total_count);
end

function metrics = calculate_migration_metrics(results, base_dir)
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


function error_analysis = analyze_failed_surveys(failed_dir)
    % ANALYZE_FAILED_SURVEYS Analyze error logs from failed surveys
    
    error_analysis = struct();
    error_analysis.error_breakdown = struct();
    error_analysis.error_breakdown.parsing_errors = 0;
    error_analysis.error_breakdown.validation_errors = 0;
    error_analysis.error_breakdown.database_errors = 0;
    error_analysis.error_breakdown.missing_required_fields = 0;
    error_analysis.error_breakdown.data_type_mismatches = 0;
    error_analysis.error_breakdown.constraint_violations = 0;
    error_analysis.error_breakdown.other_errors = 0;
    
    error_analysis.detailed_errors = {};
    error_analysis.survey_errors = struct('filename', {}, 'error_type', {}, 'message', {});
    
    % Look for error log file
    error_log_file = fullfile(failed_dir, '_errors.log');
    
    if ~exist(error_log_file, 'file')
        fprintf('⚠️  No error log found at: %s\n', error_log_file);
        fprintf('   Counting failed files instead...\n');
        
        failed_files = dir(fullfile(failed_dir, '*.csv'));
        failed_files = failed_files(~startsWith({failed_files.name}, '_'));
        error_analysis.error_breakdown.other_errors = length(failed_files);
        
        % List failed files
        for i = 1:min(10, length(failed_files))
            error_analysis.detailed_errors{end+1} = sprintf('Failed file: %s (no error details available)', ...
                failed_files(i).name);
        end
        return;
    end
    
    % Read entire error log
    fprintf('📄 Reading error log: %s\n', error_log_file);
    fid = fopen(error_log_file, 'r');
    all_lines = {};
    while ~feof(fid)
        line = fgetl(fid);
        if ischar(line)
            all_lines{end+1} = line;
        end
    end
    fclose(fid);
    
    fprintf('   Found %d lines in error log\n', length(all_lines));
    
    % Parse error entries
    error_count = 0;
    i = 1;
    
    while i <= length(all_lines)
        line = all_lines{i};
        
        % Look for error entry start: [timestamp] filename
        if startsWith(line, '[') && contains(line, ']')
            error_count = error_count + 1;
            
            % Extract timestamp and filename
            parts = split(line, '] ');
            if length(parts) >= 2
                filename = strtrim(parts{2});
            else
                filename = 'unknown';
            end
            
            % Collect error details (next few lines)
            error_msg = '';
            error_type = '';
            error_id = '';
            
            % Read next lines until separator or end
            j = i + 1;
            while j <= length(all_lines) && ...
                  ~startsWith(all_lines{j}, '---') && ...
                  ~startsWith(all_lines{j}, '===') && ...
                  ~(startsWith(all_lines{j}, '[') && contains(all_lines{j}, ']'))
                
                current_line = all_lines{j};
                
                if startsWith(current_line, 'Type:')
                    error_type = strtrim(strrep(current_line, 'Type:', ''));
                elseif startsWith(current_line, 'Error:')
                    error_msg = strtrim(strrep(current_line, 'Error:', ''));
                elseif startsWith(current_line, 'ID:')
                    error_id = strtrim(strrep(current_line, 'ID:', ''));
                elseif ~isempty(strtrim(current_line))
                    % Additional error details
                    if ~isempty(error_msg)
                        error_msg = [error_msg ' | ' current_line];
                    else
                        error_msg = current_line;
                    end
                end
                
                j = j + 1;
            end
            
            % Store structured error
            error_analysis.survey_errors(error_count).filename = filename;
            error_analysis.survey_errors(error_count).error_type = error_type;
            error_analysis.survey_errors(error_count).message = error_msg;
            error_analysis.survey_errors(error_count).error_id = error_id;
            
            % Categorize error - FIX: Call function and update struct directly
            error_analysis.error_breakdown = categorize_error(error_analysis.error_breakdown, error_msg, error_type);
            
            % Add to detailed errors (first 20)
            if error_count <= 20
                error_analysis.detailed_errors{end+1} = sprintf('%s: %s - %s', ...
                    filename, error_type, error_msg);
            end
            
            % Move to next error entry
            i = j;
        else
            i = i + 1;
        end
    end
    
    fprintf('   ✅ Analyzed %d error entries\n', error_count);
    fprintf('   📊 Error categories:\n');
    fprintf('      - Parsing: %d\n', error_analysis.error_breakdown.parsing_errors);
    fprintf('      - Validation: %d\n', error_analysis.error_breakdown.validation_errors);
    fprintf('      - Database: %d\n', error_analysis.error_breakdown.database_errors);
    fprintf('      - Missing fields: %d\n', error_analysis.error_breakdown.missing_required_fields);
    fprintf('      - Type mismatches: %d\n', error_analysis.error_breakdown.data_type_mismatches);
    fprintf('      - Constraints: %d\n', error_analysis.error_breakdown.constraint_violations);
    fprintf('      - Other: %d\n', error_analysis.error_breakdown.other_errors);
end

function breakdown = categorize_error(breakdown, error_msg, error_type)
    % CATEGORIZE_ERROR Categorize an error message
    % Now returns the modified breakdown struct
    
    error_text = lower([error_msg ' ' error_type]);
    
    if contains(error_text, {'parse', 'parsing', 'syntax', 'csv', 'format'})
        breakdown.parsing_errors = breakdown.parsing_errors + 1;
    elseif contains(error_text, {'validation', 'invalid', 'verify'})
        breakdown.validation_errors = breakdown.validation_errors + 1;
    elseif contains(error_text, {'database', 'connection', 'sql', 'insert', 'query', 'odbc'})
        breakdown.database_errors = breakdown.database_errors + 1;
    elseif contains(error_text, {'required', 'missing', 'null', 'empty'})
        breakdown.missing_required_fields = breakdown.missing_required_fields + 1;
    elseif contains(error_text, {'type', 'cast', 'conversion', 'datatype'})
        breakdown.data_type_mismatches = breakdown.data_type_mismatches + 1;
    elseif contains(error_text, {'constraint', 'violation', 'foreign key', 'primary key'})
        breakdown.constraint_violations = breakdown.constraint_violations + 1;
    else
        breakdown.other_errors = breakdown.other_errors + 1;
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
        
        % Get date range
        % query = 'SELECT MIN(SURVEYDATE) as min_date, MAX(SURVEYDATE) as max_date FROM Master';
        % result = conn.fetch(query);
        % db_stats.date_range = result;
        
        db_stats.available = true;
        
    catch ME
        warning('Could not retrieve database statistics: %s', ME.message);
        db_stats.available = false;
    end
end

function display_validation_summary(results, failed_dir)
    % Display comprehensive validation summary
    
    try
        fprintf('\n╔════════════════════════════════════════════════╗\n');
        fprintf('║         MIGRATION VALIDATION SUMMARY          ║\n');
        fprintf('╚════════════════════════════════════════════════╝\n\n');
        
        if ~isfield(results, 'metrics')
            fprintf('⚠️  No metrics available\n');
            return;
        end
        
        m = results.metrics;
        
        % Overall statistics
        fprintf('📊 Overall Statistics:\n');
        fprintf('   Total Surveys:            %d\n', m.total_records);
        fprintf('   ✓ Successfully Processed: %d (%.2f%%)\n', m.successful_uploads, m.success_rate);
        fprintf('   ✗ Failed:                 %d (%.2f%%)\n', m.failed_uploads, m.failure_rate);
        if m.pending_uploads > 0
            fprintf('   ⏳ Pending:                %d (%.2f%%)\n', m.pending_uploads, m.pending_rate);
        end
        fprintf('\n');
        
        % Success rate visualization
        fprintf('   Success Rate: ');
        print_progress_bar(m.success_rate);
        fprintf('\n\n');
        
        % Error breakdown
        if isfield(results, 'error_analysis') && isfield(results.error_analysis, 'error_breakdown')
            fprintf('🔍 Error Breakdown:\n');
            error_breakdown = results.error_analysis.error_breakdown;
            error_fields = fieldnames(error_breakdown);
            total_errors = 0;
            for i = 1:length(error_fields)
                count = error_breakdown.(error_fields{i});
                total_errors = total_errors + count;
            end
            
            for i = 1:length(error_fields)
                count = error_breakdown.(error_fields{i});
                if count > 0 && total_errors > 0
                    fprintf('   - %-25s: %d (%.1f%%)\n', ...
                        format_field_name(error_fields{i}), ...
                        count, ...
                        (count / total_errors) * 100);
                end
            end
            fprintf('\n');
            
        % Show sample errors
        if isfield(results.error_analysis, 'detailed_errors') && ~isempty(results.error_analysis.detailed_errors)
            fprintf('📝 Sample Errors:\n');
            num_to_show = min(10, length(results.error_analysis.detailed_errors));
            for i = 1:num_to_show
                error_text = results.error_analysis.detailed_errors{i};
                % Truncate if too long
                if length(error_text) > 100
                    error_text = [error_text(1:97) '...'];
                end
                fprintf('   %d. %s\n', i, error_text);
            end
            
            if length(results.error_analysis.detailed_errors) > num_to_show
                fprintf('   ... and %d more errors (see error log)\n', ...
                    length(results.error_analysis.detailed_errors) - num_to_show);
            end
            fprintf('\n');
        end
        
        % Show error log location
        if isfield(results, 'error_analysis')
            error_log = fullfile(failed_dir, '_errors.log');
            if exist(error_log, 'file')
                fprintf('📋 Full error log: %s\n\n', error_log);
            end
        end
        end
        
        % Survey type breakdown
        if isfield(m, 'by_survey_type') && ~isempty(fieldnames(m.by_survey_type))
            fprintf('📋 Success Rates by Survey Type (2-char code):\n');
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
            fprintf('🗄️  Database Statistics:\n');
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
            fprintf('✅ Migration Status: EXCELLENT (≥95%% success)\n');
        elseif m.success_rate >= 90
            fprintf('✔️  Migration Status: GOOD (≥90%% success)\n');
        elseif m.success_rate >= 80
            fprintf('⚠️  Migration Status: ACCEPTABLE (≥80%% success)\n');
        else
            fprintf('❌ Migration Status: NEEDS ATTENTION (<80%% success)\n');
        end
        
        fprintf('\n%s\n', repmat('─', 1, 50));
        
    catch ME
        fprintf(2, 'ERROR displaying summary: %s\n', ME.message);
    end
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

function generate_validation_charts(results)
    % GENERATE_VALIDATION_CHARTS Generate visualization charts
    
    fprintf('Generating validation charts...\n');
    
    if ~isfield(results, 'metrics')
        warning('No metrics available for chart generation');
        return;
    end
    
    m = results.metrics;
    
    % Create figure with multiple subplots
    fig = figure('Name', 'Migration Validation Results', ...
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
    
    % 2. Error Types Bar Chart
    subplot(2, 3, 2);
    if isfield(results, 'error_analysis') && isfield(results.error_analysis, 'error_breakdown')
        error_breakdown = results.error_analysis.error_breakdown;
        error_fields = fieldnames(error_breakdown);
        error_counts = structfun(@(x) x, error_breakdown);
        
        % Only show non-zero errors
        non_zero_idx = error_counts > 0;
        if any(non_zero_idx)
            error_counts = error_counts(non_zero_idx);
            error_labels = error_fields(non_zero_idx);
            
            % Format labels
            for i = 1:length(error_labels)
                error_labels{i} = format_field_name(error_labels{i});
            end
            
            bar(error_counts, 'FaceColor', [0.8 0.3 0.3]);
            set(gca, 'XTickLabel', error_labels);
            xtickangle(45);
            title('Error Type Distribution', 'FontSize', 12, 'FontWeight', 'bold');
            ylabel('Count');
            grid on;
        else
            text(0.5, 0.5, 'No errors detected', ...
                'HorizontalAlignment', 'center', 'FontSize', 12);
            axis off;
            title('Error Type Distribution', 'FontSize', 12, 'FontWeight', 'bold');
        end
    else
        text(0.5, 0.5, 'No error data available', ...
            'HorizontalAlignment', 'center', 'FontSize', 12);
        axis off;
        title('Error Type Distribution', 'FontSize', 12, 'FontWeight', 'bold');
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
    
    text(0.05, y_pos, '\bfMigration Summary', 'FontSize', 13);
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
    charts_dir = 'reports/migration';
    if ~exist(charts_dir, 'dir')
        mkdir(charts_dir);
    end
    
    chart_file = fullfile(charts_dir, 'validation_charts.png');
    saveas(fig, chart_file);
    
    % Also save as fig for interactive viewing
    fig_file = fullfile(charts_dir, 'validation_charts.fig');
    savefig(fig, fig_file);
    
    fprintf('📊 Charts saved to:\n');
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
        status = '✅ EXCELLENT';
    elseif success_rate >= 90
        status = '✔️ GOOD';
    elseif success_rate >= 80
        status = '⚠️ ACCEPTABLE';
    else
        status = '❌ NEEDS ATTENTION';
    end
end
