% RUN_FULL_MIGRATION Run complete migration workflow (Steps 1-3)
    
csv_file = 'data/legacy/original_csv/RUSS_24_VALID.CSV';
overwrite   = true;
validate    = true;
sample_size = inf;
chunk_size  = 10000;
pause_on_steps = false;
    
fprintf('=======================================================\n');
fprintf('         NARWC Database Migration - Full Workflow      \n');
fprintf('=======================================================\n\n');

start_time = tic;

try
    % Step 1: Extract
    fprintf('STEP 1 OF 3: Extracting surveys...\n');
    fprintf('-------------------------------------------------------\n');
    step1_extract_surveys(csv_file, 'Overwrite', overwrite,'ChunkSize', chunk_size);
    

    if pause_on_steps
        fprintf('\nPress any key to continue to Step 2...\n');
        pause;
    end

    % Step 2: Upload
    fprintf('\nSTEP 2 OF 3: Uploading to database...\n');
    fprintf('-------------------------------------------------------\n');
    step2_upload_surveys('Overwrite', overwrite, 'Validate', validate);
    
    if pause_on_steps
        fprintf('\nPress any key to continue to Step 3...\n');
        pause;
    end
    
    % Step 3: Validate
    fprintf('\nSTEP 3 OF 3: Validating migration...\n');
    fprintf('-------------------------------------------------------\n');
    % step3_validate_migration(csv_file, 'SampleSize', sample_size, 'GenerateCharts', true,'ReportFormat', 'markdown');
    step3_validate_migration('GenerateCharts', true, 'ReportFormat', 'markdown','DetailedErrorAnalysis', true);
    
    % Summary
    total_time = toc(start_time);
    fprintf('=======================================================\n');
    fprintf('Migration completed successfully!\n');
    fprintf('Total time: %.1f minutes\n', total_time/60);
    fprintf('=======================================================\n\n');
    
catch ME
    fprintf('\n✗ Migration failed: %s\n', ME.message);
    fprintf('Stack trace:\n%s\n', getReport(ME));
end