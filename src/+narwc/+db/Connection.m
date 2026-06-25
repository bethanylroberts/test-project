classdef Connection < handle
    % CONNECTION Database connection manager for NARWC project
    %
    % Example:
    %   conn = narwc.db.Connection.create();
    %   data = fetch(conn.conn, 'SELECT * FROM Master LIMIT 10');
    %   conn.close();
    %
    % Or use try-finally for automatic cleanup:
    %   conn = narwc.db.Connection.create();
    %   try
    %       data = fetch(conn.conn, 'SELECT * FROM Master');
    %   finally
    %       conn.close();
    %   end
    
    properties (SetAccess = private)
        conn        % MATLAB database connection object
        config      % Configuration structure
        is_open     % Connection status
    end
    
    properties (Access = private)
        logger      % Logger instance
    end
    
    methods
        function obj = Connection(config)
            % CONNECTION Constructor (use Connection.create() instead)
            obj.config = config;
            obj.is_open = false;
            
            % Initialize logger if available
            if exist('logging.Logger', 'class')
                obj.logger = logging.Logger('narwc.db.Connection');
            else
                obj.logger = [];
            end
            
            % Open connection
            obj.open();
        end
        
        function delete(obj)
            % DELETE Destructor - ensures connection is closed
            if obj.is_open
                obj.close();
            end
        end
        
        function open(obj)
            % OPEN Open database connection
            
            if obj.is_open
                obj.log('warning', 'Connection already open');
                return;
            end
            
            try
                obj.log('info', sprintf('Connecting to %s database at %s...', ...
                    obj.config.Type, obj.config.Server));
                
                % Create database connection based on type
                switch lower(obj.config.Type)
                    case 'mysql'
                        obj.conn = database(obj.config.DatabaseName, ...
                                          obj.config.Username, ...
                                          obj.config.Password, ...
                                          'Vendor', 'MySQL', ...
                                          'Server', obj.config.Server, ...
                                          'PortNumber', obj.config.Port);
                    
                    case 'postgresql'
                        obj.conn = database(obj.config.DatabaseName, ...
                                          obj.config.Username, ...
                                          obj.config.Password, ...
                                          'Vendor', 'PostgreSQL', ...
                                          'Server', obj.config.Server, ...
                                          'PortNumber', obj.config.Port);
                    
                    case 'sqlserver'
                        datasource = obj.config.DataSource;
                        obj.conn = database(datasource, ...
                                          obj.config.Username, ...
                                          obj.config.Password);
                    
                    otherwise
                        error('Unsupported database type: %s', obj.config.Type);
                end
                
                % Check connection
                if isopen(obj.conn)
                    obj.is_open = true;
                    obj.log('info', 'Database connection established');
                else
                    error('Failed to establish database connection: %s', obj.conn.Message);
                end
                
            catch ME
                obj.log('error', sprintf('Connection failed: %s', ME.message));
                rethrow(ME);
            end
        end
        
        function close(obj)
            % CLOSE Close database connection
            
            if ~obj.is_open
                return;
            end
            
            try
                close(obj.conn);
                obj.is_open = false;
                obj.log('info', 'Database connection closed');
            catch ME
                obj.log('warning', sprintf('Error closing connection: %s', ME.message));
            end
        end
        
        function reconnect(obj)
            % RECONNECT Reconnect to database
            obj.close();
            obj.open();
        end
        
        function tf = isOpen(obj)
            % ISOPEN Check if connection is open
            tf = obj.is_open && isopen(obj.conn);
        end
        
        function execute(obj, sql_query)
            % EXECUTE Execute SQL query without returning results
            % Use for INSERT, UPDATE, DELETE, CREATE TABLE, etc.
            %
            % Example:
            %   conn.execute('DELETE FROM Master WHERE FILEID = ''TEST''')
            %   conn.execute('CREATE TABLE test (id INT)')
            
            if ~obj.isOpen()
                error('Database connection is not open');
            end
            
            try
                execute(obj.conn, sql_query);  % No return value
                obj.log('debug', sprintf('Executed: %s', sql_query));
            catch ME
                obj.log('error', sprintf('Query failed: %s', ME.message));
                obj.log('debug', sprintf('Query was: %s', sql_query));
                rethrow(ME);
            end
        end
        
        function data = fetch(obj, sql_query)
            % FETCH Execute SQL query and return results
            %
            % Example:
            %   data = conn.fetch('SELECT * FROM Master WHERE YEAR = 1998')
            
            if ~obj.isOpen()
                error('Database connection is not open');
            end
            
            try
                data = fetch(obj.conn, sql_query);
                obj.log('debug', sprintf('Fetched %d rows', height(data)));
            catch ME
                obj.log('error', sprintf('Query failed: %s', ME.message));
                obj.log('debug', sprintf('Query was: %s', sql_query));
                rethrow(ME);
            end
        end
        
        function insert(obj, tablename, data)
            % INSERT Insert data into table
            %
            % Example:
            %   conn.insert('Master', survey_data)
            
            if ~obj.isOpen()
                error('Database connection is not open');
            end
            
            try
                sqlwrite(obj.conn, tablename, data);
                obj.log('info', sprintf('Inserted %d rows into %s', height(data), tablename));
            catch ME
                obj.log('error', sprintf('Insert failed: %s', ME.message));
                rethrow(ME);
            end
        end
        
        function ac = getAutoCommit(obj)
            % GETAUTOCOMMIT Query current AutoCommit state
            % Returns 'on' if the state cannot be read (driver limitation).
            try
                ac = obj.conn.AutoCommit;
            catch
                ac = 'on';
            end
        end

        function setAutoCommit(obj, value)
            % SETAUTOCOMMIT Restore AutoCommit state
            % Falls back to 'on' if value cannot be set.
            try
                obj.conn.AutoCommit = value;
            catch
                try
                    obj.conn.AutoCommit = 'on';
                catch
                end
            end
        end

        function beginTransaction(obj)
            % BEGINTRANSACTION Begin a database transaction
            % Sets AutoCommit = 'off'.  Throws if the driver does not
            % support transactions so the caller can fall back.
            if ~obj.isOpen()
                error('Database connection is not open');
            end
            try
                obj.conn.AutoCommit = 'off';
            catch ME
                obj.log('warning', sprintf('Driver does not support transactions: %s', ME.message));
                rethrow(ME);
            end
        end

        function commit(obj)
            % COMMIT Commit the current transaction
            if ~obj.isOpen()
                error('Database connection is not open');
            end
            try
                commit(obj.conn);
            catch ME
                obj.log('error', sprintf('Commit failed: %s', ME.message));
                rethrow(ME);
            end
        end

        function rollback(obj)
            % ROLLBACK Roll back the current transaction
            if ~obj.isOpen()
                error('Database connection is not open');
            end
            try
                rollback(obj.conn);
            catch ME
                obj.log('error', sprintf('Rollback failed: %s', ME.message));
                rethrow(ME);
            end
        end

        function update(obj, tablename, data, where_clause)
            % UPDATE Update records in table
            %
            % Example:
            %   conn.update('Master', new_data, 'WHERE FILEID = ''F098027''')
            
            if ~obj.isOpen()
                error('Database connection is not open');
            end
            
            try
                sqlupdate(obj.conn, tablename, data, where_clause);
                obj.log('info', sprintf('Updated records in %s', tablename));
            catch ME
                obj.log('error', sprintf('Update failed: %s', ME.message));
                rethrow(ME);
            end
        end
        
        function tableExists(obj, tablename)
            % TABLEEXISTS Check if table exists
            %
            % Returns:
            %   true if table exists, false otherwise
            
            try
                result = fetch(obj.conn, sprintf(...
                    "SELECT COUNT(*) as cnt FROM information_schema.tables WHERE table_name = '%s'", ...
                    tablename));
                tableExists = result.cnt > 0;
            catch
                tableExists = false;
            end
        end
        
    end
    
    methods (Access = private)
        function log(obj, level, message)
            % LOG Internal logging method
            if ~isempty(obj.logger)
                switch lower(level)
                    case 'debug'
                        obj.logger.debug(message);
                    case 'info'
                        obj.logger.info(message);
                    case 'warning'
                        obj.logger.warning(message);
                    case 'error'
                        obj.logger.error(message);
                end
            else
                % Fallback to fprintf if logger not available
                fprintf('[%s] %s\n', upper(level), message);
            end
        end
    end
    
    methods (Static)
        function obj = create(config_file)
            % CREATE Create database connection using config file
            %
            % Usage:
            %   conn = narwc.db.Connection.create()                    % Use default config
            %   conn = narwc.db.Connection.create('my_db_config.m')    % Use custom config
            
            if nargin < 1
                config_file = 'db_config';
            end
            
            % Load configuration
            try
                config = feval(config_file);
            catch ME
                error('Failed to load config file ''%s'': %s', config_file, ME.message);
            end
            
            % Create connection
            obj = narwc.db.Connection(config);
        end
    end
end