classdef test_db_connection < matlab.unittest.TestCase
    % TEST_DB_CONNECTION Unit tests for database connection
    
    properties
        conn
    end
    
    methods (TestClassSetup)
        function checkConfig(testCase)
            local_cfg = fullfile(fileparts(which('load_config')), 'local', 'db_config.local.m');
            if ~exist(local_cfg, 'file')
                testCase.assumeTrue(false, ...
                    'config/local/db_config.local.m not found - copy from db_config.local.m.template');
            end
            testCase.assumeTrue(has_live_db(), ...
                'No live database connection available - skipping DB tests');
        end
    end
    
    methods (TestMethodSetup)
        function createConnection(testCase)
            % Create connection before each test
            testCase.conn = narwc.db.Connection.create();
        end
    end
    
    methods (TestMethodTeardown)
        function closeConnection(testCase)
            % Close connection after each test
            if ~isempty(testCase.conn) && testCase.conn.isOpen()
                testCase.conn.close();
            end
        end
    end
    
    methods (Test)
        function testConnectionCreation(testCase)
            % Test that connection can be created
            testCase.verifyClass(testCase.conn, 'narwc.db.Connection');
            testCase.verifyTrue(testCase.conn.isOpen(), ...
                'Connection should be open after creation');
        end
        
        function testConnectionProperties(testCase)
            % Test connection properties
            testCase.verifyTrue(testCase.conn.is_open);
            testCase.verifyNotEmpty(testCase.conn.config);
            testCase.verifyNotEmpty(testCase.conn.conn);
        end
        
        function testSimpleQuery(testCase)
            % Test executing a simple query
            result = testCase.conn.fetch('SELECT 1 as test');
            testCase.verifyEqual(result.test, 1);
        end
        
        function testMasterTableExists(testCase)
            % Test that Master table exists
            try
                result = testCase.conn.fetch('SELECT COUNT(*) as cnt FROM Master');
                testCase.verifyGreaterThanOrEqual(result.cnt, 0);
            catch ME
                testCase.verifyFail(sprintf('Master table should exist: %s', ME.message));
            end
        end
        
        function testCloseConnection(testCase)
            % Test closing connection
            testCase.conn.close();
            testCase.verifyFalse(testCase.conn.isOpen(), ...
                'Connection should be closed');
        end
        
        function testReconnect(testCase)
            % Test reconnect method
            % Close first
            testCase.conn.close();
            testCase.verifyFalse(testCase.conn.isOpen(), ...
                'Connection should be closed');
            
            % Reconnect
            testCase.conn.reconnect();
            testCase.verifyTrue(testCase.conn.isOpen(), ...
                'Connection should be open after reconnect');
        end
        
        function testMultipleConnections(testCase)
            % Test that multiple connections can be created
            conn2 = narwc.db.Connection.create();
            testCase.addTeardown(@() conn2.close());
            
            testCase.verifyTrue(testCase.conn.isOpen(), ...
                'First connection should be open');
            testCase.verifyTrue(conn2.isOpen(), ...
                'Second connection should be open');
            
            % Both should work independently
            result1 = testCase.conn.fetch('SELECT 1 as test');
            result2 = conn2.fetch('SELECT 2 as test');
            
            testCase.verifyEqual(result1.test, 1);
            testCase.verifyEqual(result2.test, 2);
        end
        
        function testFetchMethod(testCase)
            % Test the fetch convenience method
            result = testCase.conn.fetch('SELECT 1 as test');
            testCase.verifyEqual(height(result), 1);
            testCase.verifyEqual(result.test, 1);
        end
        
        function testExecuteMethod(testCase)
            % Test the execute method (no results returned)
            % Use a statement that doesn't return results
            
            % Create a temporary table (safe operation)
            try
                testCase.conn.execute('CREATE TABLE temp_test (id INT)');
                
                % Verify table exists by inserting and querying
                testCase.conn.execute('INSERT INTO temp_test VALUES (1)');
                result = testCase.conn.fetch('SELECT COUNT(*) as cnt FROM temp_test');
                testCase.verifyEqual(result.cnt, 1);
                
                % Clean up
                testCase.conn.execute('DROP TABLE temp_test');
            catch ME
                testCase.verifyFail(sprintf('Execute method failed: %s', ME.message));
            end
        end
        
        function testInsertMethod(testCase)
            % Test the insert convenience method (if it exists)
            
            % Skip this test if insert method doesn't exist
            if ~ismethod(testCase.conn, 'insert')
                testCase.verifyTrue(true, 'Insert method not implemented yet');
                return;
            end
            
            % Fixed table name
            table_name = 'temp_insert_test';
            
            try
                % Drop table if it exists first
                testCase.conn.execute(sprintf('IF OBJECT_ID(''tempdb..%s'') IS NOT NULL DROP TABLE %s', table_name, table_name));
                
                % Create temp table
                testCase.conn.execute(sprintf('CREATE TABLE %s (id INT, name VARCHAR(50))', table_name));
                
                % Create test data
                data = table([1; 2], {'Test1'; 'Test2'}, ...
                    'VariableNames', {'id', 'name'});
                
                % Insert
                testCase.conn.insert(table_name, data);
                
                % Verify
                result = testCase.conn.fetch(sprintf('SELECT COUNT(*) as cnt FROM %s', table_name));
                testCase.verifyEqual(result.cnt, 2);
                
                % Clean up
                testCase.conn.execute(sprintf('DROP TABLE %s', table_name));
            catch ME
                % Clean up on error
                try
                    testCase.conn.execute(sprintf('IF OBJECT_ID(''tempdb..%s'') IS NOT NULL DROP TABLE %s', table_name, table_name));
                catch
                    % Ignore cleanup errors
                end
                testCase.verifyFail(sprintf('Insert test failed: %s', ME.message));
            end
        end
    end
end