function anonymize_surveys(source_dir, source_list_path, manifest_path, seed)
% ANONYMIZE_SURVEYS Create anonymized survey fixtures from real survey CSVs.
%
% Takes real survey files and writes anonymized versions suitable for use
% as test fixtures. Coordinates are shifted by a random per-survey offset;
% dates are shifted by a random per-survey integer number of days. Species
% codes, behavior codes, platform codes, and all FK-validated fields are
% left unchanged. FILEID is replaced with a synthetic test FILEID.
%
% Usage:
%   anonymize_surveys(source_dir, source_list_path, manifest_path)
%   anonymize_surveys(source_dir, source_list_path, manifest_path, seed)
%
% Inputs:
%   source_dir        - Directory containing source survey CSV files
%   source_list_path  - Path to source_list.txt (see format below)
%   manifest_path     - Path where the manifest will be written.
%                       MUST be outside the repository working tree.
%   seed              - (optional) Integer random seed for reproducibility.
%                       Default: 42. Running twice with the same seed and
%                       source list produces byte-identical output.
%
% source_list.txt format:
%   Lines starting with '#' are ignored.
%   Each data line: source_fileid,test_fileid,description
%   Test FILEIDs should start with 'T' (e.g., T001) to be obviously synthetic.
%
% Output:
%   One CSV per survey at tests/fixtures/sample_data/<test_fileid>.csv.
%   A manifest at manifest_path recording offsets, seed, and row counts.
%
% Example:
%   anonymize_surveys('data/legacy/surveys/processed', ...
%                     'tests/fixtures/source_list.txt', ...
%                     '../narwc_fixtures_manifest.txt', 42)

    if nargin < 4 || isempty(seed)
        seed = 42;
    end

    logger = logging.Logger('anonymize_surveys');

    % --- Warn if manifest path is inside the repo ---
    repo_root = find_repo_root(mfilename('fullpath'));
    manifest_abs = resolve_path(manifest_path);
    if ~isempty(repo_root) && startsWith(manifest_abs, repo_root)
        fprintf('\n');
        fprintf('WARNING: manifest path is inside the repository working tree:\n');
        fprintf('  %s\n', manifest_abs);
        fprintf('The manifest records real FILEIDs and must NOT be committed.\n\n');
    end

    % --- Set deterministic random seed ---
    rng(seed, 'twister');

    % --- Resolve output directory ---
    script_dir = fileparts(mfilename('fullpath'));
    output_dir = fullfile(script_dir, 'sample_data');
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    % --- Lat/lon fields to shift ---
    lat_fields = {'LAT_DD', 'S_LAT'};
    lon_fields = {'LONG_DD', 'S_LONG'};

    % --- Parse source list ---
    entries = parse_source_list(source_list_path, logger);
    if isempty(entries)
        logger.warning('No valid entries found in source list; nothing to do.');
        return;
    end

    % --- Pre-generate all random offsets (deterministic regardless of file presence) ---
    n = numel(entries);
    offsets = generate_offsets(n);

    % --- Process each survey ---
    manifest_rows = {};
    n_processed = 0;
    n_events_total = 0;

    for i = 1:n
        e = entries{i};
        src = e.source_fileid;
        tgt = e.test_fileid;
        off = offsets(i);

        % Find source file
        src_file = fullfile(source_dir, [src '.csv']);
        if ~exist(src_file, 'file')
            src_file_bare = fullfile(source_dir, src);
            if exist(src_file_bare, 'file')
                src_file = src_file_bare;
            else
                logger.warning(sprintf('Source file not found for FILEID %s — skipping.', src));
                continue;
            end
        end

        % Read CSV (all columns as strings to preserve formatting)
        try
            data = read_csv_as_strings(src_file);
        catch ME
            logger.error(sprintf('Cannot read source file for FILEID %s: %s', src, ME.message));
            continue;
        end

        cols = data.Properties.VariableNames;

        % Replace FILEID
        if ismember('FILEID', cols)
            data.FILEID(:) = string(tgt);
        end

        % Shift latitude fields
        for k = 1:numel(lat_fields)
            f = lat_fields{k};
            if ismember(f, cols)
                data = shift_numeric_col(data, f, off.lat);
            end
        end

        % Shift longitude fields
        for k = 1:numel(lon_fields)
            f = lon_fields{k};
            if ismember(f, cols)
                data = shift_numeric_col(data, f, off.lon);
            end
        end

        % Shift dates (YEAR, MONTH, DAY recomputed; TIME left unchanged)
        have_date = ismember('YEAR', cols) && ismember('MONTH', cols) && ismember('DAY', cols);
        if have_date
            data = shift_date_cols(data, off.date_days);
        end

        % Write output
        out_file = fullfile(output_dir, [tgt '.csv']);
        writetable(data, out_file, 'Delimiter', ',');

        n_rows = height(data);
        n_processed = n_processed + 1;
        n_events_total = n_events_total + n_rows;

        manifest_rows{end+1} = struct( ...
            'source_fileid', src, ...
            'test_fileid',   tgt, ...
            'lat_offset',    off.lat, ...
            'lon_offset',    off.lon, ...
            'date_offset',   off.date_days, ...
            'n_events',      n_rows);

        logger.info(sprintf('  %s -> %s  (%d events,  lat%+.4f  lon%+.4f  date%+d d)', ...
            src, tgt, n_rows, off.lat, off.lon, off.date_days));
    end

    % --- Write manifest ---
    write_manifest(manifest_path, seed, manifest_rows, logger);

    % --- Final summary ---
    msg = sprintf('Done: %d/%d surveys processed, %d total events.  Output: %s', ...
        n_processed, n, n_events_total, output_dir);
    logger.info(msg);
    fprintf('%s\n', msg);
    fprintf('Manifest: %s\n', manifest_path);
end


% =========================================================================
% Internal helpers
% =========================================================================

function offsets = generate_offsets(n)
% Pre-generate per-survey random offsets so that missing files do not
% shift the RNG state for subsequent entries.
offsets = struct('lat', cell(n,1), 'lon', cell(n,1), 'date_days', cell(n,1));
for i = 1:n
    lat_mag  = rand() * 0.9 + 0.1;          % uniform [0.1, 1.0]
    lat_sign = 2 * (rand() > 0.5) - 1;      % -1 or +1
    lon_mag  = rand() * 0.9 + 0.1;
    lon_sign = 2 * (rand() > 0.5) - 1;
    date_mag = randi([30, 365]);             % integer days in [30, 365]
    date_sign = 2 * (rand() > 0.5) - 1;

    offsets(i).lat       = lat_sign  * lat_mag;
    offsets(i).lon       = lon_sign  * lon_mag;
    offsets(i).date_days = date_sign * date_mag;
end
end


function entries = parse_source_list(path, logger)
entries = {};
fid = fopen(path, 'r');
if fid < 0
    error('anonymize_surveys:SourceListNotFound', ...
        'Cannot open source list: %s', path);
end
line_num = 0;
while ~feof(fid)
    raw = fgetl(fid);
    if ~ischar(raw); break; end
    line_num = line_num + 1;
    line = strtrim(raw);
    if isempty(line) || line(1) == '#'
        continue;
    end
    parts = strsplit(line, ',');
    if numel(parts) < 2
        logger.warning(sprintf('Malformed line %d in source list (too few fields): %s', ...
            line_num, line));
        continue;
    end
    e.source_fileid = strtrim(parts{1});
    e.test_fileid   = strtrim(parts{2});
    e.description   = '';
    if numel(parts) >= 3
        e.description = strtrim(strjoin(parts(3:end), ','));
    end
    if isempty(e.source_fileid) || isempty(e.test_fileid)
        logger.warning(sprintf('Empty FILEID on line %d, skipping.', line_num));
        continue;
    end
    entries{end+1} = e; %#ok<AGROW>
end
fclose(fid);
end


function data = read_csv_as_strings(file_path)
opts = detectImportOptions(file_path, 'Delimiter', ',');
opts.VariableNamingRule = 'preserve';
opts = setvartype(opts, opts.VariableNames, 'string');
data = readtable(file_path, opts);
end


function data = shift_numeric_col(data, col, offset)
% Add offset to numeric values in col; leave missing/NaN rows unchanged.
vals = str2double(data.(col));
valid = ~isnan(vals);
if any(valid)
    shifted = vals;
    shifted(valid) = vals(valid) + offset;
    new_strs = data.(col);
    new_strs(valid) = string(num2str(shifted(valid), '%.6f'));
    data.(col) = new_strs;
end
end


function data = shift_date_cols(data, offset_days)
% Shift YEAR/MONTH/DAY columns by offset_days integer days.
yy = str2double(data.YEAR);
mm = str2double(data.MONTH);
dd = str2double(data.DAY);

valid = ~isnan(yy) & ~isnan(mm) & ~isnan(dd) & ...
        yy > 0 & mm >= 1 & mm <= 12 & dd >= 1 & dd <= 31;

new_year  = data.YEAR;
new_month = data.MONTH;
new_day   = data.DAY;

for i = 1:height(data)
    if ~valid(i)
        continue;
    end
    try
        d     = datetime(yy(i), mm(i), dd(i));
        d_new = d + days(offset_days);
        new_year(i)  = string(year(d_new));
        new_month(i) = string(month(d_new));
        new_day(i)   = string(day(d_new));
    catch
        % Leave malformed dates unchanged
    end
end

data.YEAR  = new_year;
data.MONTH = new_month;
data.DAY   = new_day;
end


function write_manifest(path, seed, rows, logger)
fid = fopen(path, 'w');
if fid < 0
    logger.error(sprintf('Cannot write manifest to %s', path));
    return;
end
fprintf(fid, '# NARWC fixture anonymization manifest\n');
fprintf(fid, '# Generated: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
fprintf(fid, '# Seed: %d\n', seed);
fprintf(fid, '#\n');
fprintf(fid, '# Columns: source_fileid, test_fileid, lat_offset_deg, lon_offset_deg, date_offset_days, n_events\n');
fprintf(fid, '#\n');
for i = 1:numel(rows)
    r = rows{i};
    fprintf(fid, '%s,%s,%.6f,%.6f,%d,%d\n', ...
        r.source_fileid, r.test_fileid, ...
        r.lat_offset, r.lon_offset, r.date_offset, r.n_events);
end
fclose(fid);
end


function root = find_repo_root(start_path)
% Walk up the directory tree to find the .git directory.
root = '';
d = fileparts(start_path);
while ~isempty(d)
    if exist(fullfile(d, '.git'), 'dir') || exist(fullfile(d, '.git'), 'file')
        root = [d filesep];
        return;
    end
    parent = fileparts(d);
    if strcmp(parent, d)
        return;
    end
    d = parent;
end
end


function p = resolve_path(path)
try
    p = char(java.io.File(path).getCanonicalPath());
catch
    p = path;
end
end
