function config = get_config(section)
    % GET_CONFIG Get configuration settings for NARWC database tools
    %
    % Usage:
    %   config = get_config()           % Get all config
    %   config = get_config('validation') % Get validation section only
    %   config = get_config('paths')    % Get paths section only
    %
    % Sections:
    %   'paths'      - File and directory paths
    %   'validation' - Validation rule settings
    %   'processing' - Data processing settings
    %   'database'   - Database connection settings
    %   'logging'    - Logging settings
    
    persistent cached_config
    
    % Build config if not cached
    if isempty(cached_config)
        cached_config = build_config();
    end
    
    % Return requested section or all
    if nargin < 1 || isempty(section)
        config = cached_config;
    elseif isfield(cached_config, section)
        config = cached_config.(section);
    else
        error('get_config:UnknownSection', ...
            'Unknown config section: %s. Valid sections: %s', ...
            section, strjoin(fieldnames(cached_config), ', '));
    end
end

function config = build_config()
    % Build complete configuration structure
    
    % Get project root first - everything else depends on this
    config.paths = get_path_config();
    
    % Load other sections
    config.validation = get_validation_config(config.paths);
    config.processing = get_processing_config(config.paths);
    config.database = get_database_config();
    config.logging = get_logging_config();
    
    % Load user overrides if they exist
    config = apply_user_overrides(config);
end

function paths = get_path_config()
    % Get all path configurations
    
    % Project root - based on this file's location
    this_file = mfilename('fullpath');
    [config_dir, ~, ~] = fileparts(this_file);
    paths.project_root = fullfile(config_dir, '..');
    
    % Resolve to absolute path
    paths.project_root = char(java.io.File(paths.project_root).getCanonicalPath());
    
    % Main directories
    paths.src_dir = fullfile(paths.project_root, 'src');
    paths.data_dir = fullfile(paths.project_root, 'data');
    paths.config_dir = fullfile(paths.project_root, 'config');
    paths.tests_dir = fullfile(paths.project_root, 'tests');
    paths.output_dir = fullfile(paths.project_root, 'output');
    
    % Data subdirectories
    paths.tables_dir = fullfile(paths.data_dir, 'tables');
    paths.raw_dir = fullfile(paths.data_dir, 'raw');
    paths.processed_dir = fullfile(paths.data_dir, 'processed');
    
    % Lookup table paths
    paths.lookup_tables = struct();
    paths.lookup_tables.behave = fullfile(paths.tables_dir, 'Behave.csv');
    paths.lookup_tables.beaufort = fullfile(paths.tables_dir, 'Beaufort.csv');
    paths.lookup_tables.speccode = fullfile(paths.tables_dir, 'SPECCODE.csv');
    paths.lookup_tables.taxcode = fullfile(paths.tables_dir, 'TAXCODE.csv');
    paths.lookup_tables.cloud = fullfile(paths.tables_dir, 'Cloud.csv');
    paths.lookup_tables.glare = fullfile(paths.tables_dir, 'GLARE.csv');
    paths.lookup_tables.wx = fullfile(paths.tables_dir, 'WX.csv');
    paths.lookup_tables.platform = fullfile(paths.tables_dir, 'PLATFORM.csv');
    paths.lookup_tables.contrib = fullfile(paths.tables_dir, 'Contrib.csv');
    paths.lookup_tables.idrel = fullfile(paths.tables_dir, 'IDREL.csv');
    paths.lookup_tables.confidnc = fullfile(paths.tables_dir, 'Confidnc.csv');
    
    paths.lookup_tables.strip = fullfile(paths.tables_dir, 'STRIP.csv');
    paths.lookup_tables.photos = fullfile(paths.tables_dir, 'PHOTOS.csv');
    paths.lookup_tables.anhead = fullfile(paths.tables_dir, 'ANHEAD.csv');
    paths.lookup_tables.block = fullfile(paths.tables_dir, 'BLOCK.csv');
    paths.lookup_tables.ddsource = fullfile(paths.tables_dir, 'DDSOURCE.csv');
    paths.lookup_tables.idsource = fullfile(paths.tables_dir, 'IDSOURCE.csv');
    paths.lookup_tables.legstage = fullfile(paths.tables_dir, 'LEGSTAGE.csv');
    paths.lookup_tables.legtype = fullfile(paths.tables_dir, 'LEGTYPE.csv');
    paths.lookup_tables.stratum = fullfile(paths.tables_dir, 'STRATUM.csv');
        
    % User config file (optional overrides)
    paths.user_config = fullfile(paths.config_dir, 'user_config.m');
end

function validation = get_validation_config(paths)
    % Get validation configuration
    
    % Lookup table paths (at top level for rules that need them)
    validation.behave_table_path = paths.lookup_tables.behave;
    validation.speccode_table_path = paths.lookup_tables.speccode;
    validation.taxcode_table_path = paths.lookup_tables.taxcode;
    
    % ----- Required fields -----
    validation.required_fields = {'LAT_DD', 'LONG_DD', 'YEAR', 'MONTH', 'DAY'};
    
    % ----- Behavioral validation -----
    validation.behavioral = struct();
    validation.behavioral.dead_behaviors = [0, 1, 2, 3];
    validation.behavioral.active_swimming_behaviors = [6, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
    validation.behavioral.incompatible_behavior_pairs = [
        6, 22;
        22, 11;
    ];
    validation.behavioral.calf_associated_behaviors = [40; 41; 42];
    validation.behavioral.taxcode_restrictions = struct();
    validation.behavioral.species_restrictions = struct();
    validation.behavioral.behave_table_path = paths.lookup_tables.behave;
    
    % ----- Coordinate validation -----
    validation.coordinates = struct();
    validation.coordinates.lat_min = -90;
    validation.coordinates.lat_max = 90;
    validation.coordinates.lon_min = -180;
    validation.coordinates.lon_max = 180;
    % Study area bounds (warning if outside)
    validation.coordinates.study_area_lat_min = 20;
    validation.coordinates.study_area_lat_max = 55;
    validation.coordinates.study_area_lon_min = -85;
    validation.coordinates.study_area_lon_max = -40;
    % Aliases for rules that use different names
    validation.coordinates.survey_lat_min = 20;
    validation.coordinates.survey_lat_max = 55;
    validation.coordinates.survey_lon_min = -85;
    validation.coordinates.survey_lon_max = -40;
    
    % ----- Date/time validation -----
    validation.datetime = struct();
    validation.datetime.year_min = 1970;
    validation.datetime.year_max = year(datetime('now')) + 1;
    validation.datetime.year_warning = 1990;  % Warn for data before this year
    
    % ----- Species validation -----
    validation.species = struct();
    validation.species.require_valid_speccode = true;
    validation.species.require_valid_taxcode = true;
    validation.species.speccode_table_path = paths.lookup_tables.speccode;
    validation.species.taxcode_table_path = paths.lookup_tables.taxcode;
    % Global fallback thresholds used when neither SPECCODE nor TAXCODE provides one
    validation.species.thresholds.group_size_default = 1000;
    validation.species.thresholds.calf_count_default  = 100;
    
    % ----- Environmental validation -----
    validation.environmental = struct();
    validation.environmental.cloud_values = 0:8;
    validation.environmental.visibility_max = 50;
    validation.environmental.visibility_allow_negative = true; % FIXME: only for legacy
    validation.environmental.surftemp_min = -2;
    validation.environmental.surftemp_max = 35;
    validation.environmental.glare_values = 0:3;
    validation.environmental.beaufort_values = 0:12;
end

function processing = get_processing_config(paths)
    % Get data processing configuration
    
    processing.output_dir = paths.processed_dir;
    
    % Default processing steps
    processing.default_steps = {
        'remove_duplicates'
        'standardize_coordinates'
        'standardize_species_codes'
        'flag_outliers'
    };
    
    % Duplicate detection
    processing.duplicate_fields = {'LAT_DD', 'LON_DD', 'YEAR', 'MONTH', 'DAY', 'TIME', 'SPECCODE'};
    
    % Coordinate standardization
    processing.coordinate_precision = 6;  % Decimal places
    
    % Outlier detection
    processing.outlier_std_threshold = 3;  % Standard deviations
end

function database = get_database_config()
    % Get database configuration
    
    database.server = 'localhost';
    database.database = 'NARWC';
    database.driver = 'SQL Server';
    database.timeout = 30;
    database.trusted_connection = true;
    
    % Connection string template
    database.connection_string = sprintf(...
        'Driver={%s};Server=%s;Database=%s;Trusted_Connection=yes;', ...
        database.driver, database.server, database.database);
end

function logging = get_logging_config()
    % Get logging configuration
    
    logging.level = 'INFO';  % DEBUG, INFO, WARNING, ERROR
    logging.console_output = true;
    logging.file_output = false;
    logging.log_file = '';  % Set if file_output is true
    logging.timestamp_format = 'dd-MMM-yyyy HH:mm:ss';
end

function config = apply_user_overrides(config)
    % Apply user-specific configuration overrides
    %
    % Users can create config/user_config.m that returns a struct
    % with override values. Only specified values are overridden.
    
    if exist(config.paths.user_config, 'file')
        try
            user_overrides = user_config();
            config = merge_structs(config, user_overrides);
        catch ME
            warning('get_config:UserConfigError', ...
                'Error loading user config: %s', ME.message);
        end
    end
end

function base = merge_structs(base, override)
    % Recursively merge override struct into base struct
    
    if ~isstruct(override)
        return;
    end
    
    fields = fieldnames(override);
    for i = 1:length(fields)
        field = fields{i};
        if isfield(base, field) && isstruct(base.(field)) && isstruct(override.(field))
            % Recursively merge nested structs
            base.(field) = merge_structs(base.(field), override.(field));
        else
            % Override value
            base.(field) = override.(field);
        end
    end
end