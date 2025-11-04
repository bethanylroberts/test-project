classdef test_db_connection < matlab.unittest.TestCase
    % TEST_DB_CONNECTION Unit tests for database connection
    
    properties
        conn
    end
    
    methods (TestClassSetup)
        function checkConfig(testCase)
            % Check if config file exists
            if ~exist('db_config', 'file')
                error('db_config.m not found. Copy db_config_template.m to db_config.m');
            end
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
            config = testCase.conn.config;
            
            switch lower(config.Type)
                case 'mysql'
                    result = fetch(testCase.conn.conn, 'SELECT 1 as test');
                case 'postgresql'
                    result = fetch(testCase.conn.conn, 'SELECT 1 as test');
                case 'sqlserver'
                    result = fetch(testCase.conn.conn, 'SELECT 1 as test');
            end
            
            testCase.verifyEqual(result.test, 1);
        end
        
        function testMasterTableExists(testCase)
            % Test that Master table exists
            try
                result = fetch(testCase.conn.conn, 'SELECT COUNT(*) as cnt FROM Master');
                testCase.verifyGreaterThanOrEqual(result.cnt, 0);
            catch ME
                testCase.verifyFail(sprintf('Master table should exist: %s', ME.message));
            end
        end
        
        function testCloseAndReopen(testCase)
            % Test closing and reopening connection
            testCase.conn.close();
            testCase.verifyFalse(testCase.conn.isOpen(), ...
                'Connection should be closed');
            
            testCase.conn.open();
            testCase.verifyTrue(testCase.conn.isOpen(), ...
                'Connection should be open after reconnect');
        end
        
        function testReconnect(testCase)
            % Test reconnect method
            testCase.conn.reconnect();
            testCase.verifyTrue(testCase.conn.isOpen(), ...
                'Connection should be open after reconnect');
        end
        
        function testFetchMethod(testCase)
            % Test the fetch convenience method
            result = testCase.conn.fetch('SELECT 1 as test');
            testCase.verifyEqual(height(result), 1);
        end
        
        function testExecuteMethod(testCase)
            % Test the execute method (no results returned)
            % Use a statement that doesn't return results
            
            % Create a temporary table (safe operation)
            try
                testCase.conn.execute('CREATE TABLE #temp_test (id INT)');
                testCase.verifyTrue(true, 'Execute should work without error');
                
                % Clean up
                testCase.conn.execute('DROP TABLE #temp_test');
            catch ME
                testCase.verifyFail(sprintf('Execute method failed: %s', ME.message));
            end
        end
    end
end