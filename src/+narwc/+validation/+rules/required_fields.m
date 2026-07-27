function required_fields(data, collector, config)
    % REQUIRED_FIELDS Validate required NOT NULL fields
    %
    % Inputs:
    %   data - Table with survey data
    %   collector - ErrorCollector instance
    %   config - Configuration struct
    %
    % Two axes from the NARWC users guide (ref/narwc_users_guide__v8_.pdf):
    %   - `universal` fields are required on every row.
    %   - `sighting_only` fields are required only on sighting rows (SPECCODE
    %     populated) and must be BLANK on non-sighting rows (manual, p.93:
    %     "must be blank for all non-sighting records").
    %
    % A third axis -- fields required only for aerial/shipboard/opportunistic
    % survey types specifically (e.g. ALT required for aerial only) -- is not
    % implemented here; it needs a confirmed survey-type signal the manual
    % doesn't spell out for modern FILEIDs (see PROJECT_STATUS.md).

    if isfield(config, 'required_fields') && isstruct(config.required_fields)
        universal = get_field_list(config.required_fields, 'universal');
        sighting_only = get_field_list(config.required_fields, 'sighting_only');
    else
        universal = {'LAT_DD', 'LONG_DD', 'YEAR', 'EVENTNO', 'PLATFORM', 'DDSOURCE'};
        sighting_only = {'CONFIDNC', 'NUMBER', 'PHOTOS', 'SIGHTNO', 'SPECCODE', 'IDREL'};
    end

    check_required(data, collector, universal, true(height(data), 1), true);

    has_speccode_column = ismember('SPECCODE', data.Properties.VariableNames);
    if has_speccode_column
        is_sighting = ~is_blank(data.SPECCODE);
    else
        is_sighting = false(height(data), 1);
    end

    % column_missing is only enforced for sighting_only fields when SPECCODE
    % itself is present -- if a table doesn't even have a SPECCODE column,
    % it isn't modeling sightings at all (e.g. a minimal effort-only table),
    % so requiring SIGHTNO/CONFIDNC/etc. columns to exist would be
    % meaningless noise rather than a real gap. Production survey tables
    % always carry all 55 canonical columns (via remapToDatabase), so this
    % only matters for hand-built minimal tables.
    check_required(data, collector, sighting_only, is_sighting, has_speccode_column);
    check_forbidden_on_non_sighting(data, collector, sighting_only, is_sighting);
end

function fields = get_field_list(required_fields_config, key)
    if isfield(required_fields_config, key) && iscell(required_fields_config.(key))
        fields = required_fields_config.(key);
    else
        fields = {};
    end
end

function mask = is_blank(values)
    if isnumeric(values)
        mask = isnan(values);
    elseif iscellstr(values) || isstring(values) %#ok<ISCLSTR>
        mask = cellfun(@isempty, cellstr(values)) | ismissing(values);
    else
        mask = ismissing(values);
    end
end

function check_required(data, collector, fields, row_mask, enforce_column_missing)
    for i = 1:length(fields)
        field = fields{i};

        if ~ismember(field, data.Properties.VariableNames)
            if enforce_column_missing
                collector.addError(field, [], ...
                    sprintf('Required field %s is missing', field), 'error', ...
                    'required_fields.column_missing');
            end
            continue;
        end

        blank_mask = is_blank(data.(field)) & row_mask;
        invalid_idx = find(blank_mask);

        if ~isempty(invalid_idx)
            collector.addError(field, invalid_idx, ...
                sprintf('Required field %s cannot be NULL or empty', field), 'error', ...
                'required_fields.value_missing');
        end
    end
end

function check_forbidden_on_non_sighting(data, collector, fields, is_sighting)
    % A newly-enforced check against a lot of existing legacy data that's
    % never been validated against it -- 'warning' severity, not 'error',
    % until past-data violations are triaged (config-adjustable like any
    % other rule).
    non_sighting_mask = ~is_sighting;

    for i = 1:length(fields)
        field = fields{i};

        if ~ismember(field, data.Properties.VariableNames)
            continue;
        end

        populated_on_non_sighting = ~is_blank(data.(field)) & non_sighting_mask;
        invalid_idx = find(populated_on_non_sighting);

        if ~isempty(invalid_idx)
            collector.addError(field, invalid_idx, ...
                sprintf('%s must be blank on non-sighting records (no SPECCODE)', field), ...
                'warning', 'required_fields.forbidden_on_non_sighting');
        end
    end
end
