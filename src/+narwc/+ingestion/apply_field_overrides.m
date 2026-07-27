function data = apply_field_overrides(data, overrides)
    % APPLY_FIELD_OVERRIDES Overlay constant field values onto every row of
    % a canonical-schema survey table.
    %
    % `overrides` is a struct of canonical FieldDefinitions field name ->
    % constant value (e.g. struct('DDSOURCE', 'CCS', 'PLATFORM', 649)),
    % typically resolved via narwc.ingestion.lookup_contributor_defaults or
    % supplied explicitly (see scripts/ingestion/convert_contributor_batch.m's
    % 'FieldOverrides' option). Fields with an empty value are skipped (not
    % cleared) -- this is how contributor_defaults.csv rows record "leave
    % this field alone," e.g. CCS Opportunistic's per-row PLATFORM column,
    % or an intentionally-unconfirmed field pending curator sign-off.
    %
    % Operates on `data` post-remapToDatabase (i.e. already in canonical
    % column order) -- this is a pipeline-level concern, not a parsing
    % concern, so no parser class needs to know about injected fields.

    arguments
        data table
        overrides struct = struct()
    end

    field_names = fieldnames(overrides);
    canonical_fields = narwc.db.FieldDefinitions.getFieldNames();
    num_rows = height(data);

    for i = 1:numel(field_names)
        field_name = field_names{i};
        value = overrides.(field_name);

        if isempty(value) || (ischar(value) && isempty(strtrim(value)))
            continue;
        end

        if ~ismember(field_name, canonical_fields)
            error('apply_field_overrides:UnknownField', ...
                'Field override ''%s'' is not a canonical FieldDefinitions field', field_name);
        end

        if narwc.db.FieldDefinitions.isNumeric(field_name)
            data.(field_name) = repmat(double(value), num_rows, 1);
        else
            data.(field_name) = repmat(string(value), num_rows, 1);
        end
    end
end
