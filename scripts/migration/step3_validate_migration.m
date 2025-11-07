function results = step3_validate_migration(csv_file, options)
    % STEP3_VALIDATE_MIGRATION Step 3: Validate migration and generate report
    %
    % Usage:
    %   step3_validate_migration('data/legacy/original_csv/RUSS_24_VALID.CSV')
    %   results = step3_validate_migration('legacy.csv', 'SampleSize', 100)
    
    arguments
        csv_file char
        options.SampleSize double = inf
        options.CheckAllFields logical = false
        options.ReportFormat char {mustBeMember(options.ReportFormat, {'markdown', 'text'})} = 'markdown'
    end
    
    fprintf('=== Step 3: Validating Migration ===\n\n');
    
    % Connect to database
    conn = narwc.db.Connection.create();
    
    try
        % Create validator
        validator = migration.ConversionValidator(conn);
        
        % Run validation
        results = validator.validate(csv_file, ...
            'SampleSize', options.SampleSize, ...
            'CheckAllFields', options.CheckAllFields);
        
        % Display summary
        fprintf('%s\n', results.summary);
        
        % Save results
        results_file = 'data/legacy/validation_results.mat';
        save(results_file, 'results');
        fprintf('Validation results saved to: %s\n\n', results_file);
        
        % Generate report
        if strcmp(options.ReportFormat, 'markdown')
            report_file = 'reports/migration/migration_report.md';
        else
            report_file = 'reports/migration/migration_report.txt';
        end
        
        generate_migration_report(results, report_file, options.ReportFormat);
        
        fprintf('\n✓ Migration complete!\n\n');
        
    finally
        conn.close();
    end
end