function validation = validation_config_default()
% VALIDATION_CONFIG_DEFAULT Default validation thresholds and behavior flags.
%
% Batch configs (e.g., config/batches/migration.m) can override individual
% fields. The full per-rule config (coordinates, datetime, species, etc.)
% lives in config/get_config.m and is loaded by the rule modules directly.

    validation.thresholds.year_min             = 1980;
    validation.thresholds.year_max             = year(datetime('now')) + 1;
    validation.thresholds.group_size_default   = 1000000;
    validation.thresholds.calf_count_default   = 100000;

    validation.warnings_become_errors          = false;
    validation.allow_unknown_lookup_codes      = false;

    validation.overrides.enabled               = true;
    validation.overrides.csv_path              = '';   % set in batch config
end
