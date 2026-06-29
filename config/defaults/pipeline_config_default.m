function pipeline = pipeline_config_default()
% PIPELINE_CONFIG_DEFAULT Default pipeline execution and processing settings.

    % ----- Batch upload -----
    pipeline.chunk_size          = 10000;
    pipeline.known_fixes.enabled = true;

    % ----- Processing steps -----
    pipeline.processing.default_steps = {
        'remove_duplicates'
        'standardize_coordinates'
        'standardize_species_codes'
        'flag_outliers'
    };
    pipeline.processing.duplicate_fields       = {'LAT_DD', 'LON_DD', 'YEAR', 'MONTH', 'DAY', 'TIME', 'SPECCODE'};
    pipeline.processing.coordinate_precision   = 6;
    pipeline.processing.outlier_std_threshold  = 3;

    % ----- Logging -----
    pipeline.logging.error_log_dir            = 'logs/';
    pipeline.logging.use_datetime_filenames   = true;
    pipeline.logging.level                    = 'INFO';
    pipeline.logging.console_output           = true;
    pipeline.logging.file_output              = false;
    pipeline.logging.log_file                 = '';
    pipeline.logging.timestamp_format         = 'dd-MMM-yyyy HH:mm:ss';

    % ----- Paths -----
    pipeline.format_definitions_path = fullfile('config', 'format_definitions.json');
    pipeline.lookup_tables_dir       = fullfile('data', 'tables');
end
