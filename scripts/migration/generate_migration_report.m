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

    % Stage Funnel (extraction baseline -> attempted -> uploaded), when a
    % step1 split-summary log was available.
    if isfield(m, 'extracted_surveys')
        md = [md sprintf('## Stage Funnel\n\n')];
        md = [md sprintf('| Stage | Surveys | Rows |\n')];
        md = [md sprintf('|-------|---------|------|\n')];
        md = [md sprintf('| Extracted (step 1) | %d | %d |\n', ...
            m.extracted_surveys, m.extracted_rows)];
        md = [md sprintf('| Attempted (step 2) | %d | — |\n', m.total_records)];
        md = [md sprintf('| Uploaded | %d (%.1f%% of extracted) | — |\n', ...
            m.successful_uploads, m.extraction_to_upload_rate)];
        md = [md sprintf('\n')];
    end

    % Success rate progress bar
    md = [md sprintf('### Success Rate Visualization\n\n')];
    md = [md sprintf('```\n')];
    bar_width = 50; % FIXME: magic number move to top of function or options
    filled = round((m.success_rate / 100) * bar_width);
    md = [md sprintf('[%s%s] %.1f%%\n', ...
        repmat('█', 1, filled), repmat('░', 1, bar_width - filled), m.success_rate)];
    md = [md sprintf('```\n\n')];
    
    % Error Breakdown -- by rule_id, from re-validating failed/pending
    % surveys in memory (see tally_validation_by_rule in step3_validate_migration.m),
    % not from scraping free-text log files.
    if isfield(results, 'error_analysis')
        ea = results.error_analysis;
        md = [md sprintf('## Error Analysis\n\n')];
        md = [md sprintf('Surveys re-validated for this breakdown: %d (%d with blocking errors, %d with outstanding warnings)\n\n', ...
            ea.surveys_analyzed, ea.surveys_with_errors, ea.surveys_with_warnings)];

        md = [md rule_table_markdown('Blocking Errors by Rule', ea.detail_errors_by_rule)];
        md = [md rule_table_markdown('Outstanding (Unacknowledged) Warnings by Rule', ea.detail_warnings_outstanding_by_rule)];
        md = [md rule_table_markdown('Acknowledged Warnings by Rule', ea.detail_warnings_acknowledged_by_rule)];

        if ~isempty(ea.would_now_pass)
            md = [md sprintf('### Surveys That Would Now Pass\n\n')];
            md = [md sprintf(['%d survey(s) currently in `failed/` re-validate CLEAN under the ' ...
                'current config/overrides/lookup tables. These need a re-run, not further investigation:\n\n'], ...
                numel(ea.would_now_pass))];
            for i = 1:numel(ea.would_now_pass)
                md = [md sprintf('- `%s`\n', ea.would_now_pass{i})];
            end
            md = [md sprintf('\n')];
        end

        % Sample errors
        if isfield(ea, 'detailed_errors') && ~isempty(ea.detailed_errors)
            md = [md sprintf('### Sample Errors\n\n')];
            for i = 1:min(5, length(ea.detailed_errors))
                md = [md sprintf('%d. `%s`\n', i, ea.detailed_errors{i})];
            end
            md = [md sprintf('\n')];
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

function md = rule_table_markdown(title, detail_struct)
    % RULE_TABLE_MARKDOWN Render a rule_key -> struct(rule_id, count,
    % survey_count) detail struct (see flatten_tally_map in
    % step3_validate_migration.m) as a sorted Markdown table.
    md = '';
    rule_keys = fieldnames(detail_struct);
    if isempty(rule_keys)
        return;
    end

    counts = zeros(numel(rule_keys), 1);
    for i = 1:numel(rule_keys)
        counts(i) = detail_struct.(rule_keys{i}).count;
    end
    [~, order] = sort(counts, 'descend');

    md = [md sprintf('### %s\n\n', title)];
    md = [md sprintf('| rule_id | Count | Surveys |\n')];
    md = [md sprintf('|---------|-------|---------|\n')];
    for i = 1:numel(order)
        e = detail_struct.(rule_keys{order(i)});
        md = [md sprintf('| `%s` | %d | %d |\n', e.rule_id, e.count, e.survey_count)]; %#ok<AGROW>
    end
    md = [md sprintf('\n')];
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

    % Stage Funnel
    if isfield(m, 'extracted_surveys')
        txt = [txt sprintf('STAGE FUNNEL\n')];
        txt = [txt sprintf('--------------------------------------------------------------------------------\n')];
        txt = [txt sprintf('%-30s %15d surveys, %d rows\n', 'Extracted (step 1):', ...
            m.extracted_surveys, m.extracted_rows)];
        txt = [txt sprintf('%-30s %15d surveys\n', 'Attempted (step 2):', m.total_records)];
        txt = [txt sprintf('%-30s %15d surveys %15s\n', 'Uploaded:', ...
            m.successful_uploads, sprintf('(%.1f%% of extracted)', m.extraction_to_upload_rate))];
        txt = [txt sprintf('\n')];
    end

    % Success rate bar
    txt = [txt sprintf('Success Rate: ')];
    bar_width = 50;
    filled = round((m.success_rate / 100) * bar_width);
    txt = [txt sprintf('[%s%s] %.1f%%\n\n', ...
        repmat('#', 1, filled), repmat('-', 1, bar_width - filled), m.success_rate)];
    
    % Error Breakdown -- by rule_id (see generateMarkdown's version for the
    % full explanation of where this data comes from).
    if isfield(results, 'error_analysis')
        ea = results.error_analysis;
        txt = [txt sprintf('ERROR ANALYSIS\n')];
        txt = [txt sprintf('--------------------------------------------------------------------------------\n')];
        txt = [txt sprintf('Surveys re-validated: %d (%d with errors, %d with outstanding warnings)\n\n', ...
            ea.surveys_analyzed, ea.surveys_with_errors, ea.surveys_with_warnings)];

        txt = [txt rule_table_text('Blocking Errors by Rule', ea.detail_errors_by_rule)];
        txt = [txt rule_table_text('Outstanding Warnings by Rule', ea.detail_warnings_outstanding_by_rule)];
        txt = [txt rule_table_text('Acknowledged Warnings by Rule', ea.detail_warnings_acknowledged_by_rule)];

        if ~isempty(ea.would_now_pass)
            txt = [txt sprintf('%d survey(s) in failed/ now re-validate CLEAN -- re-run, don''t investigate:\n', ...
                numel(ea.would_now_pass))];
            txt = [txt sprintf('   %s\n\n', strjoin(ea.would_now_pass, ', '))];
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

function txt = rule_table_text(title, detail_struct)
    % RULE_TABLE_TEXT Plain-text counterpart to rule_table_markdown.
    txt = '';
    rule_keys = fieldnames(detail_struct);
    if isempty(rule_keys)
        return;
    end

    counts = zeros(numel(rule_keys), 1);
    for i = 1:numel(rule_keys)
        counts(i) = detail_struct.(rule_keys{i}).count;
    end
    [~, order] = sort(counts, 'descend');

    txt = [txt sprintf('%s:\n', title)];
    for i = 1:numel(order)
        e = detail_struct.(rule_keys{order(i)});
        txt = [txt sprintf('   %-55s %5d  (%d survey(s))\n', e.rule_id, e.count, e.survey_count)]; %#ok<AGROW>
    end
    txt = [txt sprintf('\n')];
end

function formatted = format_field_name(field_name)
    % Convert field_name to readable format
    formatted = strrep(field_name, '_', ' ');
    formatted = regexprep(formatted, '\<(\w)', '${upper($1)}');
end