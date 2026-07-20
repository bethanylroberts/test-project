function startup()
    % STARTUP Initialize NARWC Database Project
    % Automatically adds all necessary paths and performs basic checks
    
    fprintf('=== NARWC Database Project Startup ===\n');
    
    % Get project root directory
    project_root = fileparts(mfilename('fullpath'));
    
    % Add paths
    fprintf('Adding paths...\n');
    addpath(fullfile(project_root, 'src'));
    addpath(fullfile(project_root, 'lib'));
    addpath(fullfile(project_root, 'apps'));
    addpath(fullfile(project_root, 'scripts'));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'config', 'defaults'));
    addpath(fullfile(project_root, 'config', 'batches'));
    addpath(fullfile(project_root, 'config', 'local'));
    addpath(fullfile(project_root, 'tests'));
    
    % Add all script subdirectories
    script_dirs = {'migration', 'ingestion', 'import', 'validation', 'maintenance', 'setup'};
    for i = 1:length(script_dirs)
        script_path = fullfile(project_root, 'scripts', script_dirs{i});
        if exist(script_path, 'dir')
            addpath(script_path);
        end
    end
    
    % Add test subdirectories
    test_dirs = {'unit', 'integration', 'fixtures'};
    for i = 1:length(test_dirs)
        test_path = fullfile(project_root, 'tests', test_dirs{i});
        if exist(test_path, 'dir')
            addpath(test_path);
        end
    end
    
    fprintf('Paths added successfully.\n');
    
    % Check for required toolboxes
    fprintf('\nChecking for required toolboxes...\n');
    required_toolboxes = {
        'Database Toolbox', 'database_toolbox'
    };
    
    optional_toolboxes = {
        'Mapping Toolbox', 'map_toolbox'
        'Statistics and Machine Learning Toolbox', 'statistics_toolbox'
    };
    
    missing_required = {};
    for i = 1:size(required_toolboxes, 1)
        if ~license('test', required_toolboxes{i, 2})
            missing_required{end+1} = required_toolboxes{i, 1};
            fprintf('  ✗ %s - NOT FOUND\n', required_toolboxes{i, 1});
        else
            fprintf('  ✓ %s\n', required_toolboxes{i, 1});
        end
    end
    
    if ~isempty(missing_required)
        warning('Missing required toolboxes: %s', strjoin(missing_required, ', '));
    end
    
    % Check optional toolboxes
    fprintf('\nOptional toolboxes:\n');
    for i = 1:size(optional_toolboxes, 1)
        if license('test', optional_toolboxes{i, 2})
            fprintf('  ✓ %s\n', optional_toolboxes{i, 1});
        else
            fprintf('  - %s (not installed)\n', optional_toolboxes{i, 1});
        end
    end
    
    % Check for logging toolbox
    fprintf('\nChecking external dependencies...\n');
    if exist('logging.Logger', 'class')
        fprintf('  ✓ Logging toolbox found\n');
    else
        fprintf('  ✗ Logging toolbox not found\n');
        fprintf('    Add logging toolbox to lib/ directory\n');
    end
    
    % Create necessary directories if they don't exist
    fprintf('\nChecking directory structure...\n');
    required_dirs = {
        'data/raw/pending'
        'data/raw/processed'
        'data/raw/rejected'
        'data/legacy/original_csv'
        'data/legacy/extracted_surveys'
        'data/exports/surveys'
        'data/exports/reports'
        'data/archives'
        'reports/processing'
        'reports/validation'
        'reports/migration'
        'reports/quality'
        'logs'
    };
    
    for i = 1:length(required_dirs)
        dir_path = fullfile(project_root, required_dirs{i});
        if ~exist(dir_path, 'dir')
            mkdir(dir_path);
            fprintf('  Created: %s\n', required_dirs{i});
        end
    end
    
    % Check for configuration files
    fprintf('\nChecking configuration files...\n');
    local_config = fullfile(project_root, 'config', 'local', 'db_config_local.m');
    if ~exist(local_config, 'file')
        fprintf('  ✗ config/local/db_config_local.m not found\n');
        fprintf('    Copy config/local/db_config_local.m.template to db_config_local.m and add credentials\n');
    else
        fprintf('  ✓ config/local/db_config_local.m found\n');
    end

    % Test database connection (if configured)
    fprintf('\nTesting database connection...\n');
    try
        conn = narwc.db.Connection.create();
        fprintf('  ✓ Database connection successful\n');
        conn.close();
    catch ME
        fprintf('  ✗ Database connection failed: %s\n', ME.message);
        fprintf('    Configure config/local/db_config_local.m with your database credentials\n');
    end
    
    % Display available functions
    fprintf('\n=== Available Commands ===\n');
    fprintf('Type "help narwc" for toolbox documentation\n');
    fprintf('Type "NARWCDatabaseApp" to launch main application\n');
    fprintf('Type "runtests(''tests'')" to run all tests\n');
    
    fprintf('\n=== Startup Complete ===\n\n');
end