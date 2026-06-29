function validation = validation_config_default()
% VALIDATION_CONFIG_DEFAULT Default validation thresholds and rule parameters.
%
% Lookup table paths are relative to the project root (where MATLAB runs from).
% Batch configs (config/batches/) can override any field via load_config().

    % ----- Top-level lookup table paths (used by some rules directly) -----
    validation.behave_table_path   = fullfile('data', 'tables', 'Behave.csv');
    validation.speccode_table_path = fullfile('data', 'tables', 'SPECCODE.csv');
    validation.taxcode_table_path  = fullfile('data', 'tables', 'TAXCODE.csv');

    % ----- Required fields -----
    validation.required_fields = {'LAT_DD', 'LONG_DD', 'YEAR', 'MONTH', 'DAY'};

    % ----- Behavioral validation -----
    validation.behavioral.dead_behaviors              = [0, 1, 2, 3];
    validation.behavioral.active_swimming_behaviors   = [6, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
    validation.behavioral.incompatible_behavior_pairs = [6, 22; 22, 11];
    validation.behavioral.calf_associated_behaviors   = [40; 41; 42];
    validation.behavioral.taxcode_restrictions        = struct();
    validation.behavioral.species_restrictions        = struct();
    validation.behavioral.behave_table_path           = fullfile('data', 'tables', 'Behave.csv');

    % ----- Coordinate validation -----
    validation.coordinates.lat_min = -90;
    validation.coordinates.lat_max = 90;
    validation.coordinates.lon_min = -180;
    validation.coordinates.lon_max = 180;
    % Study area bounds (warning if outside)
    validation.coordinates.study_area_lat_min = 20;
    validation.coordinates.study_area_lat_max = 55;
    validation.coordinates.study_area_lon_min = -85;
    validation.coordinates.study_area_lon_max = -40;
    % Aliases used by some rules
    validation.coordinates.survey_lat_min = 20;
    validation.coordinates.survey_lat_max = 55;
    validation.coordinates.survey_lon_min = -85;
    validation.coordinates.survey_lon_max = -40;

    % ----- Date/time validation -----
    validation.datetime.year_min     = 1970;
    validation.datetime.year_max     = year(datetime('now')) + 1;
    validation.datetime.year_warning = 1980;

    % ----- Species validation -----
    validation.species.require_valid_speccode        = true;
    validation.species.require_valid_taxcode         = true;
    validation.species.speccode_table_path           = fullfile('data', 'tables', 'SPECCODE.csv');
    validation.species.taxcode_table_path            = fullfile('data', 'tables', 'TAXCODE.csv');
    % Global fallback thresholds — only fire when neither SPECCODE nor TAXCODE
    % provides a per-taxon threshold. Curators control per-species limits via
    % the lookup CSVs; these are intentionally high to avoid false positives.
    validation.species.thresholds.group_size_default = 100000;
    validation.species.thresholds.calf_count_default = 100;

    % ----- Environmental validation -----
    validation.environmental.cloud_values              = 0:8;
    validation.environmental.visibility_max            = 50;
    validation.environmental.visibility_allow_negative = false;
    validation.environmental.surftemp_min              = -2;
    validation.environmental.surftemp_max              = 35;
    validation.environmental.glare_values              = 0:3;
    validation.environmental.beaufort_values           = 0:12;

    % ----- Batch-level behavior flags -----
    validation.warnings_become_errors     = false;
    validation.allow_unknown_lookup_codes = false;
    validation.overrides.enabled          = true;
    validation.overrides.csv_path         = '';   % set in batch config
end
