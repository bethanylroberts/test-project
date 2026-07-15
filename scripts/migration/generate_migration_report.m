% GENERATE_MIGRATION_REPORT creates a report after migrating the old files
% 
% This is run by step3_validate_migration.m and runs towards the end of the
% migration process to generate a human readable report.
% 
% 2026 russ.shomberg@marinerobotics.com

function generate_migration_report(validation_results, output_file, format)
    % GENERATE_MIGRATION_REPORT Generate migration report
    %
    % Usage:
    %   generate_migration_report(results, 'report.md', 'markdown')
    %   generate_migration_report(results, 'report.txt', 'text')
    
    if nargin < 2
        output_file = 'reports/migration/migration_report.md';
    end
    
    if nargin < 3
        format = 'markdown';
    end
    
    fprintf('Generating migration report...\n');
    
    % Create output directory if needed
    output_dir = fileparts(output_file);
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Generate report based on format
    if strcmp(format, 'markdown')
        report = generateMarkdown(validation_results);
    else
        report = generateText(validation_results);
    end
    
    % Write to file
    fid = fopen(output_file, 'w');
    fprintf(fid, '%s', report);
    fclose(fid);
    
    fprintf('Report generated: %s\n', output_file);
end

function md = generateMarkdown(results)
    % GENERATEMARKDOWN Generate Markdown report
    
    md = sprintf('# NARWC Database Migration Report\n\n');
    md = [md sprintf('**Generated:** %s\n\n', char(datetime('now')))];
    md = [md sprintf('---\n\n')];
    
    % Check if we have metrics
    if ~isfield(results, 'metrics')
        md = [md sprintf('⚠️ No metrics available\n\n')];
        return;
    end
    
    m = results.metrics;
    
    % Overall Status
    md = [md sprintf('## Overall Status\n\n')];
    
    if m.success_rate >= 95
        md = [md sprintf('✅ **Migration Status: EXCELLENT** (≥95%% success)\n\n')];
        md = [md sprintf('Migration completed with excellent results.\n\n')];
    elseif m.success_rate >= 90
        md = [md sprintf('✔️ **Migration Status: GOOD** (≥90%% success)\n\n')];
        md = [md sprintf('Migration completed successfully with minor issues.\n\n')];
    elseif m.success_rate >= 80
        md = [md sprintf('⚠️ **Migration Status: ACCEPTABLE** (≥80%% success)\n\n')];
        md = [md sprintf('Migration completed but requires review.\n\n')];
    else
        md = [md sprintf('❌ **Migration Status: NEEDS ATTENTION** (<80%% success)\n\n')];
        md = [md sprintf('Significant issues detected. Manual intervention required.\n\n')];
    end
    
    % Summary Statistics
    md = [md sprintf('## Summary Statistics\n\n')];
    md = [md sprintf('| Metric | Count | Percentage |\n')];
    md = [md sprintf('|--------|-------|------------|\n')];
    md = [md sprintf('| **Total Surveys** | %d | 100.0%% |\n', m.total_records)];
    md = [md sprintf('| ✅ Successfully Processed | %d | %.2f%% |\n', ...
        m.successful_uploads, m.success_rate)];
    md = [md sprintf('| ❌ Failed | %d | %.2f%% |\n', ...
        m.failed_uploads, m.failure_rate)];
    if m.pending_uploads > 0
        md = [md sprintf('| ⏳ Pending | %d | %.2f%% |\n', ...
            m.pending_uploads, m.pending_rate)];
    end
    md = [md sprintf('\n')];
    
    % Success rate progress bar
    md = [md sprintf('### Success Rate Visualization\n\n')];
    md = [md sprintf('```\n')];
    bar_width = 50; % FIXME: magic number move to top of function or options
    filled = round((m.success_rate / 100) * bar_width);
    md = [md sprintf('[%s%s] %.1f%%\n', ...
        repmat('█', 1, filled), repmat('░', 1, bar_width - filled), m.success_rate)];
    md = [md sprintf('```\n\n')];
    
    % Error Breakdown
    if isfield(results, 'error_analysis') && isfield(results.error_analysis, 'error_breakdown')
        md = [md sprintf('## Error Analysis\n\n')];
        
        error_breakdown = results.error_analysis.error_breakdown;
        error_fields = fieldnames(error_breakdown);
        total_errors = 0;
        for i = 1:length(error_fields)
            total_errors = total_errors + error_breakdown.(error_fields{i});
        end
        
        if total_errors > 0
            md = [md sprintf('### Error Distribution\n\n')];
            md = [md sprintf('| Error Type | Count | Percentage |\n')];
            md = [md sprintf('|------------|-------|------------|\n')];
            
            for i = 1:length(error_fields)
                count = error_breakdown.(error_fields{i});
                if count > 0
                    field_name = format_field_name(error_fields{i});
                    md = [md sprintf('| %s | %d | %.1f%% |\n', ...
                        field_name, count, (count / total_errors) * 100)];
                end
            end
            md = [md sprintf('\n')];
            
            % Sample errors
            if isfield(results.error_analysis, 'detailed_errors') && ~isempty(results.error_analysis.detailed_errors)
                md = [md sprintf('### Sample Errors\n\n')];
                for i = 1:min(5, length(results.error_analysis.detailed_errors))
                    md = [md sprintf('%d. `%s`\n', i, results.error_analysis.detailed_errors{i})];
                end
                md = [md sprintf('\n')];
            end
        end
    end
    

    % Survey Type Breakdown
    if isfield(m, 'by_survey_type') && ~isempty(fieldnames(m.by_survey_type))
        md = [md sprintf('## Success Rates by Survey Type\n\n')];
        md = [md sprintf('Survey types identified by first 2 characters of filename.\n\n')];
        md = [md sprintf('| Type | Successful | Failed | Total | Success Rate |\n')];
        md = [md sprintf('|------|------------|--------|-------|-------------|\n')];
        
        type_fields = fieldnames(m.by_survey_type);
        
        % Sort by type code
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
            
            md = [md sprintf('| **%s** | %d | %d | %d | %.1f%% |\n', ...
                type_code, type_data.successful, type_data.failed, ...
                type_data.total, type_data.success_rate)];
        end
        md = [md sprintf('\n')];
    end
    
    % Database Statistics
    if isfield(m, 'database_stats') && m.database_stats.available
        md = [md sprintf('## Database Statistics\n\n')];
        md = [md sprintf('- **Total records in database:** %d\n', m.database_stats.total_surveys)];
        if isfield(m.database_stats, 'date_range')
            md = [md sprintf('- **Date range:** %s to %s\n', ...
                char(m.database_stats.date_range.min_date), ...
                char(m.database_stats.date_range.max_date))];
        end
        md = [md sprintf('\n')];
    end
    
    % File Lists
    md = [md sprintf('## Migration Details\n\n')];
    
    if isfield(results, 'processed_files') && ~isempty(results.processed_files)
        md = [md sprintf('### Successfully Processed Surveys\n\n')];
        md = [md sprintf('Total: %d surveys\n\n', length(results.processed_files))];
        
        if length(results.processed_files) <= 20
            md = [md sprintf('<details>\n<summary>View all processed surveys</summary>\n\n')];
            for i = 1:length(results.processed_files)
                md = [md sprintf('- `%s`\n', results.processed_files{i})];
            end
            md = [md sprintf('\n</details>\n\n')];
        else
            md = [md sprintf('*Too many to list individually (%d files)*\n\n', ...
                length(results.processed_files))];
        end
    end
    
    if isfield(results, 'failed_files') && ~isempty(results.failed_files)
        md = [md sprintf('### Failed Surveys\n\n')];
        md = [md sprintf('Total: %d surveys\n\n', length(results.failed_files))];
        
        md = [md sprintf('<details>\n<summary>View failed surveys</summary>\n\n')];
        for i = 1:length(results.failed_files)
            md = [md sprintf('- `%s`\n', results.failed_files{i})];
        end
        md = [md sprintf('\n</details>\n\n')];
    end
    
    if isfield(results, 'pending_files') && ~isempty(results.pending_files)
        md = [md sprintf('### Pending Surveys\n\n')];
        md = [md sprintf('Total: %d surveys\n\n', length(results.pending_files))];
        
        if length(results.pending_files) <= 50
            md = [md sprintf('<details>\n<summary>View pending surveys</summary>\n\n')];
            for i = 1:length(results.pending_files)
                md = [md sprintf('- `%s`\n', results.pending_files{i})];
            end
            md = [md sprintf('\n</details>\n\n')];
        end
    end
    
    % Recommendations
    md = [md sprintf('## Recommendations\n\n')];
    
    if m.success_rate >= 95
        md = [md sprintf('- ✅ Migration quality is excellent\n')];
        md = [md sprintf('- Review any failed surveys to understand edge cases\n')];
    elseif m.success_rate >= 90
        md = [md sprintf('- ✔️ Migration quality is good\n')];
        md = [md sprintf('- Investigate failed surveys to improve success rate\n')];
    elseif m.success_rate >= 80
        md = [md sprintf('- ⚠️ Review failed surveys carefully\n')];
        md = [md sprintf('- Consider re-running migration for failed items after fixes\n')];
    else
        md = [md sprintf('- ❌ Significant issues detected\n')];
        md = [md sprintf('- Manual review and intervention required\n')];
        md = [md sprintf('- Check error logs and database constraints\n')];
    end
    md = [md sprintf('\n')];
    
    % Footer
    md = [md sprintf('---\n\n')];
    md = [md sprintf('*Report generated by NARWC Database Migration Tools*\n')];
    md = [md sprintf('*Generated at: %s*\n', char(datetime('now')))];
end

function txt = generateText(results)
    % GENERATETEXT Generate plain text report
    
    txt = sprintf('================================================================================\n');
    txt = [txt sprintf('                    NARWC DATABASE MIGRATION REPORT\n')];
    txt = [txt sprintf('================================================================================\n\n')];
    txt = [txt sprintf('Generated: %s\n\n', char(datetime('now')))];
    
    if ~isfield(results, 'metrics')
        txt = [txt sprintf('No metrics available\n\n')];
        return;
    end
    
    m = results.metrics;
    
    % Overall Status
    txt = [txt sprintf('OVERALL STATUS\n')];
    txt = [txt sprintf('--------------------------------------------------------------------------------\n')];
    
    if m.success_rate >= 95
        txt = [txt sprintf('✓ Migration Status: EXCELLENT (>=95%% success)\n\n')];
    elseif m.success_rate >= 90
        txt = [txt sprintf('✓ Migration Status: GOOD (>=90%% success)\n\n')];
    elseif m.success_rate >= 80
        txt = [txt sprintf('⚠ Migration Status: ACCEPTABLE (>=80%% success)\n\n')];
    else
        txt = [txt sprintf('✗ Migration Status: NEEDS ATTENTION (<80%% success)\n\n')];
    end
    
    % Summary Statistics
    txt = [txt sprintf('SUMMARY STATISTICS\n')];
    txt = [txt sprintf('--------------------------------------------------------------------------------\n')];
    txt = [txt sprintf('%-30s %15d %15s\n', 'Total Surveys:', m.total_records, '(100.0%)')];
    txt = [txt sprintf('%-30s %15d %15s\n', 'Successfully Processed:', ...
        m.successful_uploads, sprintf('(%.2f%%)', m.success_rate))];
    txt = [txt sprintf('%-30s %15d %15s\n', 'Failed:', ...
        m.failed_uploads, sprintf('(%.2f%%)', m.failure_rate))];
    if m.pending_uploads > 0
        txt = [txt sprintf('%-30s %15d %15s\n', 'Pending:', ...
            m.pending_uploads, sprintf('(%.2f%%)', m.pending_rate))];
    end
    txt = [txt sprintf('\n')];
    
    % Success rate bar
    txt = [txt sprintf('Success Rate: ')];
    bar_width = 50;
    filled = round((m.success_rate / 100) * bar_width);
    txt = [txt sprintf('[%s%s] %.1f%%\n\n', ...
        repmat('#', 1, filled), repmat('-', 1, bar_width - filled), m.success_rate)];
    
    % Error Breakdown
    if isfield(results, 'error_analysis') && isfield(results.error_analysis, 'error_breakdown')
        error_breakdown = results.error_analysis.error_breakdown;
        error_fields = fieldnames(error_breakdown);
        total_errors = 0;
        for i = 1:length(error_fields)
            total_errors = total_errors + error_breakdown.(error_fields{i});
        end
        
        if total_errors > 0
            txt = [txt sprintf('ERROR ANALYSIS\n')];
            txt = [txt sprintf('--------------------------------------------------------------------------------\n')];
            
            for i = 1:length(error_fields)
                count = error_breakdown.(error_fields{i});
                if count > 0
                    field_name = format_field_name(error_fields{i});
                    txt = [txt sprintf('%-30s %10d %15s\n', field_name, count, ...
                        sprintf('(%.1f%%)', (count / total_errors) * 100))];
                end
            end
            txt = [txt sprintf('\n')];
        end
    end
    
    % Survey Type Breakdown
    if isfield(m, 'by_survey_type') && ~isempty(fieldnames(m.by_survey_type))
        txt = [txt sprintf('SUCCESS RATES BY SURVEY TYPE\n')];
        txt = [txt sprintf('--------------------------------------------------------------------------------\n')];
        
        type_fields = fieldnames(m.by_survey_type);
        for i = 1:length(type_fields)
            type_data = m.by_survey_type.(type_fields{i});
            type_name = format_field_name(type_fields{i});
            txt = [txt sprintf('%-20s: %d/%d (%.1f%%)\n', ...
                type_name, type_data.successful, type_data.total, type_data.success_rate)];
        end
        txt = [txt sprintf('\n')];
    end
    
    % Database Statistics
    if isfield(m, 'database_stats') && m.database_stats.available
        txt = [txt sprintf('DATABASE STATISTICS\n')];
        txt = [txt sprintf('--------------------------------------------------------------------------------\n')];
        txt = [txt sprintf('Total records in database: %d\n', m.database_stats.total_surveys)];
        if isfield(m.database_stats, 'date_range')
            txt = [txt sprintf('Date range: %s to %s\n', ...
                char(m.database_stats.date_range.min_date), ...
                char(m.database_stats.date_range.max_date))];
        end
        txt = [txt sprintf('\n')];
    end
    
    % Footer
    txt = [txt sprintf('================================================================================\n')];
    txt = [txt sprintf('Report generated by NARWC Database Migration Tools\n')];
    txt = [txt sprintf('Generated at: %s\n', char(datetime('now')))];
    txt = [txt sprintf('================================================================================\n')];
end

function formatted = format_field_name(field_name)
    % Convert field_name to readable format
    formatted = strrep(field_name, '_', ' ');
    formatted = regexprep(formatted, '\<(\w)', '${upper($1)}');
end