function overrides = migration()
% MIGRATION Batch config for the legacy data migration.
%
% Permissive thresholds and FK behavior since legacy data has known quirks
% that are addressed by apply_known_fixes.m and migration_overrides.csv.
%
% Add fields here as the migration run surfaces new issues. Commented
% examples below show the available fields.

    overrides.validation.allow_unknown_lookup_codes                    = true;
    overrides.validation.environmental.visibility_allow_negative       = true;
    overrides.validation.overrides.csv_path                           = fullfile('config', 'overrides', 'migration_overrides.csv');
    overrides.pipeline.known_fixes.enabled                            = true;

    % NOTE: there are a lot of historical instances of calf associated behaviors
    % which do not record numcalf. Dr Kenney reports that calfs were often not
    % recorded, so these warnings must be ignored.
    overrides.validation.behavioral.calf_associated_behaviors   = [];

    % Legacy data frequently has NUMCALF > NUMBER/2 (small groups with one
    % calf). Suppress this warning for migration; curators should re-enable
    % for new survey ingestion.
    overrides.validation.species.allow_numcalf_exceeds_half     = true;

    % Additional fields — uncomment and adjust as needed:
    overrides.validation.datetime.year_min = 1700;
    overrides.validation.datetime.year_warning = 1700;
    overrides.validation.environmental.surftemp_max = 38;


    % overrides.validation.species.thresholds.group_size_default = 1000000;
    % overrides.pipeline.fk_violations_blocking = false;
end
