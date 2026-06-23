% UPDATE_LOOKUP_TABLES - updates local tables from DB
% 
% Connect to the database and download the look up tables from the database, but
% not the master table. Save the look up tables locally for use in validations.
% 
% 2026 russ.shomberg@marineacoustics.com

% Connect to database
conn = narwc.db.Connection.create();

try
    % Get a list of tables to download (all except Master)
    % SQL Server syntax for getting table names
    query = "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES " + ...
            "WHERE TABLE_SCHEMA = 'dbo' AND TABLE_NAME != 'Master' " + ...
            "ORDER BY TABLE_NAME";
    
    tableList = conn.fetch(query);
    tableNames = string(tableList.TABLE_NAME);
    
    logging.info('Found %d lookup tables to download\n\n', height(tableNames));
    
    % Create output directory if it doesn't exist
    outputDir = './data/tables';
    if ~isfolder(outputDir)
        mkdir(outputDir);
        logging.info('Created directory: %s\n\n', outputDir);
    end
    
    % Download each table & overwrite the local tables
    for i = 1:height(tableNames)
        tableName = tableNames(i);
        logging.info('[%d/%d] Downloading table: %s ... ', i, height(tableNames), tableName);
        
        try
            % Download table from database
            tableData = conn.fetch(sprintf('SELECT * FROM [dbo].[%s]', tableName));
            
            % Save to local CSV file
            outputFile = fullfile(outputDir, sprintf('%s.csv', tableName));
            writetable(tableData, outputFile);
            
            logging.debug('✓ (%d rows)\n', height(tableData));
            
        catch ME
            fprintf('✗ ERROR: %s\n', ME.message);
        end
    end
    
    fprintf('\nLookup tables updated successfully!\n');

% TODO: add catch statement
    
finally
    % Always close connection
    conn.close();
end