function overrides = lookup_contributor_defaults(contributor, path, table_path)
    % LOOKUP_CONTRIBUTOR_DEFAULTS Look up DDSOURCE/IDSOURCE/PLATFORM
    % defaults for one contributor's raw file (or subfolder) from
    % data/tables/contributor_defaults.csv.
    %
    % These three fields are curator-assigned per the NARWC manual (never
    % supplied by contributors' raw files) but are mostly constant per
    % contributor/subfolder -- see data/README.md and PROJECT_STATUS.md
    % §8.7 for how the seeded values were sourced from real cover sheets.
    %
    % table_path rows are matched top-to-bottom, first match wins: a row
    % matches when 'contributor' matches exactly (case-insensitive) and
    % 'path_pattern' (a wildcard glob, e.g. '*Vessel/*' -- no leading '/'
    % required, since e.g. CCS's real subfolders are named "2023 Vessel"/
    % "2024 Aerial" etc., a single space-separated path segment, not
    % '.../Vessel/...') matches `path` (backslash-to-forward-slash
    % normalized). This lets a more specific row (e.g. one excluding a
    % single ambiguous file) be listed before a broader one it would
    % otherwise also match -- see the 'CCS'/'*Vessel/TB0322*' row for an
    % example. `path` is usually a full file path (per-file resolution, so
    % file-level exceptions work), but a directory also works for patterns
    % that don't need that granularity.
    %
    % Returns a struct with only the non-blank fields present among
    % DDSOURCE/IDSOURCE/PLATFORM (PLATFORM as double, DDSOURCE/IDSOURCE as
    % char) -- an empty struct if no row matches, meaning "inject nothing,"
    % which is intentional wherever the curator hasn't confirmed a value
    % yet (apply_field_overrides leaves those fields blank, and
    % required_fields validation then correctly flags them as missing).

    arguments
        contributor char
        path char
        table_path char = fullfile('data', 'tables', 'contributor_defaults.csv')
    end

    overrides = struct();

    if ~exist(table_path, 'file')
        return;
    end

    opts = detectImportOptions(table_path, 'Delimiter', ',');
    opts = setvartype(opts, {'contributor', 'path_pattern', 'DDSOURCE', 'IDSOURCE', 'PLATFORM', 'notes'}, 'string');
    tbl = readtable(table_path, opts);

    normalized_path = strrep(path, '\', '/');

    for i = 1:height(tbl)
        if ~strcmpi(strtrim(tbl.contributor(i)), strtrim(string(contributor)))
            continue;
        end

        pattern = strtrim(tbl.path_pattern(i));
        regex_pattern = ['^' regexptranslate('wildcard', char(pattern)) '$'];
        if isempty(regexpi(normalized_path, regex_pattern, 'once'))
            continue;
        end

        if strlength(tbl.DDSOURCE(i)) > 0
            overrides.DDSOURCE = char(tbl.DDSOURCE(i));
        end
        if strlength(tbl.IDSOURCE(i)) > 0
            overrides.IDSOURCE = char(tbl.IDSOURCE(i));
        end
        if strlength(tbl.PLATFORM(i)) > 0
            overrides.PLATFORM = str2double(tbl.PLATFORM(i));
        end
        return;
    end
end
