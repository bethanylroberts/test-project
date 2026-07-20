function overrides = routine()
% ROUTINE Batch config for routine contributor-batch ingestion.
%
% Unlike migration.m, routine data is NOT legacy data with known SAS-era
% quirks, so this keeps the strict defaults from
% config/defaults/validation_config_default.m rather than relaxing them.
% Only points the override CSV at a routine-specific file and disables the
% legacy-only Category C corrections.

    overrides.pipeline.known_fixes.enabled = false;   % Category C fixes are legacy-artifact-specific (see docs/known_fixes.md)
    overrides.validation.overrides.csv_path = fullfile('config', 'overrides', 'routine_overrides.csv');
end
