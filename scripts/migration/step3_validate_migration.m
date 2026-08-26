% STEP3_VALIDATE_MIGRATION validates the migration batch and generates a report
%
% Thin, migration-flavored wrapper over the shared
% scripts/ingestion/validate_batch.m ('legacy' source, 'migration' config
% profile) -- kept as an ergonomic entry point for the familiar
% step1/step2/step3 migration workflow. Any source can call validate_batch
% directly; this just fixes the defaults for the legacy batch.
%
% 2026 russ.shomberg@marineacoustics.com

function results = step3_validate_migration(options)
    % STEP3_VALIDATE_MIGRATION Step 3: Validate the legacy migration batch and generate a report
    %
    % Usage:
    %   step3_validate_migration()
    %   step3_validate_migration('BatchId', '2026-07-26_14-30-12_legacy')
    %   step3_validate_migration('GenerateCharts', true, 'ReportFormat', 'markdown')

    arguments
        options.BatchId char = ''
        options.GenerateCharts logical = true
        options.ReportFormat char {mustBeMember(options.ReportFormat, {'markdown', 'text', 'html'})} = 'markdown'
        options.DetailedErrorAnalysis logical = true
    end

    fprintf('=== Step 3: Validating Migration Batch ===\n\n');

    results = validate_batch('Source', 'legacy', 'BatchId', options.BatchId, ...
        'ConfigProfile', 'migration', ...
        'GenerateCharts', options.GenerateCharts, ...
        'ReportFormat', options.ReportFormat, ...
        'DetailedErrorAnalysis', options.DetailedErrorAnalysis);
end
