function db = db_config_default()
% DB_CONFIG_DEFAULT Default database connection settings.
%
% Credentials (Username, Password) are empty here and must be supplied
% via config/local/db_config_local.m (gitignored).

    db.Type         = 'MySQL';
    db.Server       = 'localhost';
    db.Port         = 3306;
    db.DatabaseName = 'NARWCDB';
    db.DataSource   = 'NARWCDB_DSN';
    db.Username     = '';
    db.Password     = '';
    db.Timeout      = 10;
end
