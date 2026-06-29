function config = db_config_template()
    % DB_CONFIG_TEMPLATE Database configuration template
    %
    % INSTRUCTIONS:
    %   1. Copy this file to 'db_config.m'
    %   2. Fill in your database credentials
    %   3. Do NOT commit db_config.m to version control

    % FIXME: this is now stored in `get_config.m`. That needs to use a template
    % because it should not be exposed to the public repo. (Fine for now because
    % localhost and passwords will change.)
    
    % Database type: 'MySQL', 'PostgreSQL', or 'SQLServer'
    config.Type = 'MySQL';
    
    % Connection parameters
    config.Server = 'localhost';
    config.Port = 3306;  % MySQL default: 3306, PostgreSQL default: 5432
    config.DatabaseName = 'NARWCDB';
    config.Username = 'your_username';
    config.Password = 'your_password';
    
    % Optional: SQL Server data source name (if using ODBC)
    config.DataSource = 'NARWC_DSN';
    
    % Connection options
    config.Timeout = 10;  % seconds
end