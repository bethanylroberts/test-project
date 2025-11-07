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
    
    % Overall Status
    md = [md sprintf('## Overall Status\n\n')];
    
    if results.is_valid
        md = [md sprintf('✅ **Migration Validated Successfully**\n\n')];
        md = [md sprintf('All checks passed. Data integrity confirmed.\n\n')];
    else
        md = [md sprintf('❌ **Migration Validation Failed**\n\n')];
        md = [md sprintf('Issues detected. See details below.\n\n')];
    end
    
    % Summary Statistics
    md = [md sprintf('## Summary Statistics\n\n')];
    md = [md sprintf('| Metric | CSV | Database | Status |\n')];
    md = [md sprintf('|--------|-----|----------|--------|\n')];
    
    % Survey count
    match = results.csv_survey_count == results.db_survey_count;
    md = [md sprintf('| Survey Count | %d | %d | %s |\n', ...
        results.csv_survey_count, results.db_survey_count, ...
        getStatusMD(match))];
    
    % Record count
    match = results.csv_total_records == results.db_total_records;
    md = [md sprintf('| Total Records | %d | %d | %s |\n\n', ...
        results.csv_total_records, results.db_total_records, ...
        getStatusMD(match))];
    
    % Survey Comparison
    md = [md sprintf('## Survey Comparison\n\n')];
    md = [md sprintf('| Category | Count |\n')];
    md = [md sprintf('|----------|-------|\n')];
    md = [md sprintf('| Surveys in both CSV and DB | %d |\n', ...
        results.survey_comparison.in_both)];
    md = [md sprintf('| Missing from database | %d |\n', ...
        results.survey_comparison.missing_from_db)];
    md = [md sprintf('| Extra in database | %d |\n\n', ...
        results.survey_comparison.extra_in_db)];
    
    % List missing surveys if any
    if results.survey_comparison.missing_from_db > 0
        md = [md sprintf('### Surveys Missing from Database\n\n')];
        for i = 1:min(20, length(results.survey_comparison.missing_from_db_list))
            md = [md sprintf('- %s\n', results.survey_comparison.missing_from_db_list{i})];
        end
        if length(results.survey_comparison.missing_from_db_list) > 20
            md = [md sprintf('- ... and %d more\n', ...
                length(results.survey_comparison.missing_from_db_list) - 20)];
        end
        md = [md sprintf('\n')];
    end
    
    % Sample Validation
    md = [md sprintf('## Sample Validation Results\n\n')];
    md = [md sprintf('Validated %d surveys in detail.\n\n', ...
        length(results.survey_validations))];
    
    matching = sum([results.survey_validations.matches]);
    mismatched = length(results.survey_validations) - matching;
    
    md = [md sprintf('| Result | Count | Percentage |\n')];
    md = [md sprintf('|--------|-------|------------|\n')];
    md = [md sprintf('| Matching | %d | %.1f%% |\n', ...
        matching, 100*matching/length(results.survey_validations))];
    md = [md sprintf('| Mismatched | %d | %.1f%% |\n\n', ...
        mismatched, 100*mismatched/length(results.survey_validations))];
    
    % List mismatched surveys
    if mismatched > 0
        md = [md sprintf('### Mismatched Surveys\n\n')];
        md = [md sprintf('| Survey ID | CSV Rows | DB Rows | Issues |\n')];
        md = [md sprintf('|-----------|----------|---------|--------|\n')];
        
        for i = 1:length(results.survey_validations)
            val = results.survey_validations(i);
            if ~val.matches
                issues_str = strjoin(val.issues, '; ');
                md = [md sprintf('| %s | %d | %d | %s |\n', ...
                    val.survey_id, val.csv_rows, val.db_rows, issues_str)];
            end
        end
        md = [md sprintf('\n')];
    end
    
    % Issues
    if ~isempty(results.issues)
        md = [md sprintf('## Issues Detected\n\n')];
        for i = 1:length(results.issues)
            md = [md sprintf('- ⚠️ %s\n', results.issues{i})];
        end
        md = [md sprintf('\n')];
    end
    
    % Footer
    md = [md sprintf('---\n\n')];
    md = [md sprintf('**Source CSV:** `%s`\n\n', results.csv_file)];
    md = [md sprintf('**Validation Time:** %s\n\n', char(results.validation_time))];
    md = [md sprintf('*Report generated by NARWC Database Migration Tools*\n')];
end

function txt = generateText(results)
    % GENERATETEXT Generate plain text report
    
    txt = sprintf('================================================================================\n');
    txt = [txt sprintf('                    NARWC DATABASE MIGRATION REPORT\n')];
    txt = [txt sprintf('================================================================================\n\n')];
    txt = [txt sprintf('Generated: %s\n\n', char(datetime('now')))];
    
    % Overall Status
    txt = [txt sprintf('OVERALL STATUS\n')];
    txt = [txt sprintf('--------------------------------------------------------------------------------\n')];
    
    if results.is_valid
        txt = [txt sprintf('✓ Migration Validated Successfully\n')];
        txt = [txt sprintf('  All checks passed. Data integrity confirmed.\n\n')];
    else
        txt = [txt sprintf('✗ Migration Validation Failed\n')];
        txt = [txt sprintf('  Issues detected. See details below.\n\n')];
    end
    
    % Summary Statistics
    txt = [txt sprintf('SUMMARY STATISTICS\n')];
    txt = [txt sprintf('--------------------------------------------------------------------------------\n')];
    txt = [txt sprintf('%-20s %15s %15s %10s\n', 'Metric', 'CSV', 'Database', 'Status')];
    txt = [txt sprintf('%-20s %15s %15s %10s\n', '------', '---', '--------', '------')];
    
    match = results.csv_survey_count == results.db_survey_count;
    txt = [txt sprintf('%-20s %15d %15d %10s\n', 'Survey Count', ...
        results.csv_survey_count, results.db_survey_count, getStatusText(match))];
    
    match = results.csv_total_records == results.db_total_records;
    txt = [txt sprintf('%-20s %15d %15d %10s\n\n', 'Total Records', ...
        results.csv_total_records, results.db_total_records, getStatusText(match))];
    
    % Survey Comparison
    txt = [txt sprintf('SURVEY COMPARISON\n')];
    txt = [txt sprintf('--------------------------------------------------------------------------------\n')];
    txt = [txt sprintf('%-40s %10d\n', 'Surveys in both CSV and DB:', ...
        results.survey_comparison.in_both)];
    txt = [txt sprintf('%-40s %10d\n', 'Missing from database:', ...
        results.survey_comparison.missing_from_db)];
    txt = [txt sprintf('%-40s %10d\n\n', 'Extra in database:', ...
        results.survey_comparison.extra_in_db)];
    
    % List missing surveys
    if results.survey_comparison.missing_from_db > 0
        txt = [txt sprintf('Surveys Missing from Database:\n')];
        for i = 1:min(20, length(results.survey_comparison.missing_from_db_list))
            txt = [txt sprintf('  - %s\n', results.survey_comparison.missing_from_db_list{i})];
        end
        if length(results.survey_comparison.missing_from_db_list) > 20
            txt = [txt sprintf('  - ... and %d more\n', ...
                length(results.survey_comparison.missing_from_db_list) - 20)];
        end
        txt = [txt sprintf('\n')];
    end
    
    % Sample Validation
    txt = [txt sprintf('SAMPLE VALIDATION RESULTS\n')];
    txt = [txt sprintf('--------------------------------------------------------------------------------\n')];
    txt = [txt sprintf('Validated %d surveys in detail\n\n', length(results.survey_validations))];
    
    matching = sum([results.survey_validations.matches]);
    mismatched = length(results.survey_validations) - matching;
    
    txt = [txt sprintf('%-20s %10d (%5.1f%%)\n', 'Matching:', matching, ...
        100*matching/length(results.survey_validations))];
    txt = [txt sprintf('%-20s %10d (%5.1f%%)\n\n', 'Mismatched:', mismatched, ...
        100*mismatched/length(results.survey_validations))];
    
    % List mismatched surveys
    if mismatched > 0
        txt = [txt sprintf('Mismatched Surveys:\n')];
        for i = 1:length(results.survey_validations)
            val = results.survey_validations(i);
            if ~val.matches
                txt = [txt sprintf('  %s: CSV=%d rows, DB=%d rows\n', ...
                    val.survey_id, val.csv_rows, val.db_rows)];
                for j = 1:length(val.issues)
                    txt = [txt sprintf('    - %s\n', val.issues{j})];
                end
            end
        end
        txt = [txt sprintf('\n')];
    end
    
    % Issues
    if ~isempty(results.issues)
        txt = [txt sprintf('ISSUES DETECTED\n')];
        txt = [txt sprintf('--------------------------------------------------------------------------------\n')];
        for i = 1:length(results.issues)
            txt = [txt sprintf('  ⚠ %s\n', results.issues{i})];
        end
        txt = [txt sprintf('\n')];
    end
    
    % Footer
    txt = [txt sprintf('================================================================================\n')];
    txt = [txt sprintf('Source CSV: %s\n', results.csv_file)];
    txt = [txt sprintf('Validation Time: %s\n', char(results.validation_time))];
    txt = [txt sprintf('================================================================================\n')];
end

function status = getStatusMD(is_ok)
    if is_ok
        status = '✅';
    else
        status = '❌';
    end
end

function status = getStatusText(is_ok)
    if is_ok
        status = 'OK';
    else
        status = 'FAIL';
    end
end