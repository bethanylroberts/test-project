# Database Connection Troubleshooting

## Error: "db_config_local.m not found"

**Solution:**
1. Copy the template: `copyfile('config/local/db_config_local.m.template', 'config/local/db_config_local.m')`
   and fill in your credentials (`Username`, `Password`). It's gitignored — never committed.
2. Make sure `config` is on your MATLAB path (run `startup.m`)

## Error: "Failed to establish database connection"

### Check 1: Verify Database Toolbox
```matlab
license('test', 'database_toolbox')
```

Should return 1. If not, install Database Toolbox.


Check 2: Test basic MATLAB database function

```matlab

% For SQL Server
conn = database('NARWCDB', 'username', 'password', ...
    'Vendor', 'Microsoft SQL Server', ...
    'Server', 'your-server');
isopen(conn)
```

Check 3: Verify server connectivity

    Can you ping the server?
    Is the database server running?
    Are you on the correct network/VPN?
    Check firewall settings

Check 4: Verify credentials

    Username correct?
    Password correct (no typos)?
    User has permission to access database?

Error: "Master table not found"

The database connection works, but the Master table doesn't exist yet.

Solution:
You'll create this in Phase 1 (migration). For now, this is expected.
Error: "Connection timeout"

Possible causes:

    Server is slow to respond
    Network issues
    Server is overloaded

Solution:
Increase the timeout — either in `config/defaults/db_config_default.m` (project-wide
default) or `config/local/db_config_local.m` (per-machine override):

```matlab
db.Timeout = 30;  % seconds
```

SQL Server Specific Issues
ODBC Driver Issues

If using SQL Server, you may need to install/configure ODBC drivers.

Check available drivers:

```matlab

drivers = listdrivers
```

Install ODBC Driver:

    Windows: Download "ODBC Driver for SQL Server" from Microsoft
    Mac/Linux: Install unixODBC and FreeTDS

Windows Authentication

For Windows authentication, use:

```matlab

db.Username = '';
db.Password = '';
```

MySQL Specific Issues
Can't connect to MySQL server

    Verify MySQL is running: sudo service mysql status
    Check port is correct (usually 3306)
    Verify user has remote access permission

Access denied error

```sql

-- In MySQL, grant permissions:
GRANT ALL PRIVILEGES ON NARWCDB.* TO 'username'@'%' IDENTIFIED BY 'password';
FLUSH PRIVILEGES;
```

PostgreSQL Specific Issues
Connection refused

    Check PostgreSQL is running
    Check pg_hba.conf allows your connection
    Verify port (usually 5432)

SSL required error

Add to connection string or configure PostgreSQL to not require SSL.

```yaml

```

---

## Quick Start Commands

```matlab
% === Complete test sequence ===

% 1. Setup project
startup

% 2. Quick connection test
test_connection

% 3. If connection works, test with a query
conn = narwc.db.Connection.create();
data = conn.fetch('SELECT TOP 10 * FROM Master');
disp(data)
conn.close()

% 4. Run unit tests (more thorough)
runtests('tests/unit/test_db_connection.m')
```

Expected Output (Success)

```yaml

=== Database Connection Test ===

Test 1: Loading configuration...
  ✓ Configuration loaded
    Type: SQLServer
    Server: your-server-name
    Database: NARWCDB

Test 2: Creating connection object...
  ✓ Connection object created

Test 3: Checking connection status...
  ✓ Connection is open

Test 4: Executing test query...
  ✓ Query executed successfully
    Database version: Microsoft SQL Server 2019...

Test 5: Checking for Master table...
  ✓ Master table exists
    Record count: 12450

Test 6: Testing sample data query...
  ✓ Sample query successful
    Retrieved 5 records

    Sample data:
    FILEID      YEAR    EVENTNO
    _______     ____    _______
    'F098027'   1998    33
    'F098027'   1998    34
    ...

Test 7: Closing connection...
  ✓ Connection closed successfully

=== Connection Test Complete ===
If all tests passed, your database connection is working!
```