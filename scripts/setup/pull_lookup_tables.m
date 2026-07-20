% PULL_LOOKUP_TABLES - Pull lookup tables from the database into local CSVs.
%
% Connects to the database and downloads every lookup table (all tables except
% Master) into data/tables/ as CSV files. These snapshots are committed to the
% repository so validation rules can run on machines without direct DB access.
%
% This script is the DB-to-CSV direction. The inverse (CSV-to-DB) is
% scripts/setup/push_lookup_tables.m.
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
    
    logging.info('Lookup tables pulled successfully.');

% TODO: add catch statement
    
finally
    % Always close connection
    conn.close();
end