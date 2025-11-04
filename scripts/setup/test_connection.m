function test_connection()
    % TEST_CONNECTION Simple database connection test
    %
    % Usage:
    %   test_connection()
    
    fprintf('=== Database Connection Test ===\n\n');
    
    % Test 1: Load configuration
    fprintf('Test 1: Loading configuration...\n');
    try
        config = db_config();
        fprintf('  ✓ Configuration loaded\n');
        fprintf('    Type: %s\n', config.Type);
        fprintf('    Server: %s\n', config.Server);
        fprintf('    Database: %s\n', config.DatabaseName);
        fprintf('\n');
    catch ME
        fprintf('  ✗ Failed to load configuration\n');
        fprintf('    Error: %s\n', ME.message);
        fprintf('    Make sure config/db_config.m exists and is on the path\n');
        return;
    end
    
    % Test 2: Create connection object
    fprintf('Test 2: Creating connection object...\n');
    try
        conn = narwc.db.Connection.create();
        fprintf('  ✓ Connection object created\n\n');
    catch ME
        fprintf('  ✗ Failed to create connection\n');
        fprintf('    Error: %s\n', ME.message);
        fprintf('\nTroubleshooting:\n');
        fprintf('  - Check database credentials in config/db_config.m\n');
        fprintf('  - Verify server is running and accessible\n');
        fprintf('  - Check firewall settings\n');
        fprintf('  - Verify Database Toolbox is installed\n');
        return;
    end
    
    % Test 3: Check connection status
    fprintf('Test 3: Checking connection status...\n');
    if conn.isOpen()
        fprintf('  ✓ Connection is open\n\n');
    else
        fprintf('  ✗ Connection failed to open\n');
        fprintf('    Message: %s\n', conn.conn.Message);
        return;
    end
    
    % Test 4: Execute simple query
    fprintf('Test 4: Executing test query...\n');
    try
        % Try to get database version or similar
        switch lower(config.Type)
            case 'mysql'
                result = fetch(conn.conn, 'SELECT VERSION() as version');
                version_str = result.version{1};
            case 'postgresql'
                result = fetch(conn.conn, 'SELECT version()');
                version_str = result.version{1};
            case 'sqlserver'
                result = fetch(conn.conn, 'SELECT @@VERSION as version');
                version_str = result.version{1};  % Access table properly
        end
        fprintf('  ✓ Query executed successfully\n');
        fprintf('    Database version: %s\n\n', version_str);
    catch ME
        fprintf('  ✗ Query failed\n');
        fprintf('    Error: %s\n', ME.message);
        fprintf('\n');
    end

    % Test 5: Check for Master table
    fprintf('Test 5: Checking for Master table...\n');
    try
        result = fetch(conn.conn, 'SELECT COUNT(*) as cnt FROM Master');
        fprintf('  ✓ Master table exists\n');
        fprintf('    Record count: %d\n\n', result.cnt);
    catch ME
        fprintf('  ✗ Master table not found or not accessible\n');
        fprintf('    Error: %s\n', ME.message);
        fprintf('    You may need to create the table first\n\n');
    end
    
    % Test 6: Test a sample query
    fprintf('Test 6: Testing sample data query...\n');
    try
        result = fetch(conn.conn, 'SELECT TOP 5 FILEID, YEAR, EVENTNO FROM Master ORDER BY YEAR DESC');
        fprintf('  ✓ Sample query successful\n');
        fprintf('    Retrieved %d records\n', height(result));
        if height(result) > 0
            fprintf('\n    Sample data:\n');
            disp(result);
        end
    catch ME
        fprintf('  ⚠ Sample query failed (may be expected if table is empty)\n');
        fprintf('    Error: %s\n', ME.message);
    end
    
    % Clean up
    fprintf('\nTest 7: Closing connection...\n');
    try
        conn.close();
        fprintf('  ✓ Connection closed successfully\n');
    catch ME
        fprintf('  ⚠ Error closing connection: %s\n', ME.message);
    end
    
    fprintf('\n=== Connection Test Complete ===\n');
    fprintf('If all tests passed, your database connection is working!\n\n');
end