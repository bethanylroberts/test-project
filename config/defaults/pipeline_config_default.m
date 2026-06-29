function pipeline = pipeline_config_default()
% PIPELINE_CONFIG_DEFAULT Default pipeline execution settings.

    pipeline.chunk_size                          = 10000;
    pipeline.known_fixes.enabled                 = true;
    pipeline.logging.error_log_dir               = 'logs/';
    pipeline.logging.use_datetime_filenames      = true;
    pipeline.logging.level                       = 'INFO';
    pipeline.format_definitions_path             = 'config/format_definitions.json';
    pipeline.lookup_tables_dir                   = 'data/tables/';
end
