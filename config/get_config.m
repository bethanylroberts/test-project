function config = get_config(section)
    % GET_CONFIG Get configuration settings for NARWC database tools
    %
    % Usage:
    %   config = get_config()             % Get all config
    %   config = get_config('validation') % Get validation section only
    %   config = get_config('paths')      % Get paths section only
    %
    % Sections: 'paths', 'validation', 'processing', 'database', 'logging'
    %
    % Config data lives in config/defaults/. This function caches the result,
    % overlays absolute lookup-table paths, and provides backward-compatible
    % section access for existing callers.

    persistent cached_config

    if isempty(cached_config)
        cached_config = build_config();
    end

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
    config.paths = build_path_config();

    % Validation: start from defaults, then overlay absolute lookup-table paths
    config.validation = validation_config_default();
    config.validation = overlay_validation_paths(config.validation, config.paths);

    % Processing: from pipeline defaults
    pipeline                = pipeline_config_default();
    config.processing       = pipeline.processing;
    config.processing.output_dir = config.paths.processed_dir;

    % Database: from db defaults (field names remapped for legacy callers)
    db = db_config_default();
    config.database.server             = db.Server;
    config.database.port               = db.Port;
    config.database.database           = db.DatabaseName;
    config.database.driver             = db.Type;
    config.database.timeout            = db.Timeout;
    config.database.trusted_connection = false;

    % Logging: from pipeline defaults
    config.logging = pipeline.logging;
end

function validation = overlay_validation_paths(validation, paths)
    % Replace relative table paths with absolute paths from the paths section.
    t = paths.lookup_tables;
    validation.behave_table_path                  = t.behave;
    validation.speccode_table_path                = t.speccode;
    validation.taxcode_table_path                 = t.taxcode;
    validation.behavioral.behave_table_path       = t.behave;
    validation.species.speccode_table_path        = t.speccode;
    validation.species.taxcode_table_path         = t.taxcode;
end

function paths = build_path_config()
    this_file = mfilename('fullpath');
    [config_dir, ~, ~] = fileparts(this_file);
    paths.project_root = fullfile(config_dir, '..');
    paths.project_root = char(java.io.File(paths.project_root).getCanonicalPath());

    paths.src_dir       = fullfile(paths.project_root, 'src');
    paths.data_dir      = fullfile(paths.project_root, 'data');
    paths.config_dir    = fullfile(paths.project_root, 'config');
    paths.tests_dir     = fullfile(paths.project_root, 'tests');
    paths.output_dir    = fullfile(paths.project_root, 'output');
    paths.tables_dir    = fullfile(paths.data_dir, 'tables');
    paths.raw_dir       = fullfile(paths.data_dir, 'raw');
    paths.processed_dir = fullfile(paths.data_dir, 'processed');

    t = struct();
    t.behave   = fullfile(paths.tables_dir, 'Behave.csv');
    t.beaufort = fullfile(paths.tables_dir, 'Beaufort.csv');
    t.speccode = fullfile(paths.tables_dir, 'SPECCODE.csv');
    t.taxcode  = fullfile(paths.tables_dir, 'TAXCODE.csv');
    t.cloud    = fullfile(paths.tables_dir, 'Cloud.csv');
    t.glare    = fullfile(paths.tables_dir, 'GLARE.csv');
    t.wx       = fullfile(paths.tables_dir, 'WX.csv');
    t.platform = fullfile(paths.tables_dir, 'PLATFORM.csv');
    t.contrib  = fullfile(paths.tables_dir, 'Contrib.csv');
    t.idrel    = fullfile(paths.tables_dir, 'IDREL.csv');
    t.confidnc = fullfile(paths.tables_dir, 'Confidnc.csv');
    t.strip    = fullfile(paths.tables_dir, 'STRIP.csv');
    t.photos   = fullfile(paths.tables_dir, 'PHOTOS.csv');
    t.anhead   = fullfile(paths.tables_dir, 'ANHEAD.csv');
    t.block    = fullfile(paths.tables_dir, 'BLOCK.csv');
    t.ddsource = fullfile(paths.tables_dir, 'DDSOURCE.csv');
    t.idsource = fullfile(paths.tables_dir, 'IDSOURCE.csv');
    t.legstage = fullfile(paths.tables_dir, 'LEGSTAGE.csv');
    t.legtype  = fullfile(paths.tables_dir, 'LEGTYPE.csv');
    t.stratum  = fullfile(paths.tables_dir, 'STRATUM.csv');
    paths.lookup_tables = t;
end
