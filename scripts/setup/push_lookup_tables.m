% PUSH_LOOKUP_TABLES - Push local lookup-table CSVs into the database.
%
% Reads each CSV in data/tables/, deletes the existing rows from the
% corresponding database table, and re-inserts from the CSV. This is the
% CSV-to-DB direction. The inverse (DB-to-CSV) is pull_lookup_tables.m.
%
% Usage: run this script from the project root after editing lookup CSVs
% or after a fresh schema deployment (scripts/sql/schema/).
%
% Requires a live database connection (config/db_config.m).
% Does NOT update the Master table.
% Skips sysdiagrams (binary system table that does not roundtrip via CSV).
%
% 2026 russ.shomberg@marineacoustics.com

log = logging.Logger('narwc.setup.push_lookup_tables');

tablesDir = fullfile('.', 'data', 'tables');
if ~isfolder(tablesDir)
    error('push_lookup_tables:missingDir', ...
        'data/tables/ not found. Run from the project root directory.');
end

files = dir(fullfile(tablesDir, '*.csv'));
if isempty(files)
    error('push_lookup_tables:noFiles', 'No CSV files found in %s', tablesDir);
end

log.info('Connecting to database...');
conn = narwc.db.Connection.create();

nPushed  = 0;
nFailed  = 0;
nSkipped = 0;
failed   = {};

try
    for i = 1:length(files)
        fname     = files(i).name;
        tableName = fname(1:end-4);  % strip .csv

        if strcmp(tableName, 'sysdiagrams')
            log.debug('Skipping %s (system table)', tableName);
            nSkipped = nSkipped + 1;
            continue
        end

        csvPath = fullfile(tablesDir, fname);
        log.info('[%d/%d] Pushing %s ...', i, length(files), tableName);

        try
            % Explicit delimiter avoids MATLAB auto-detection errors on files
            % whose descriptions contain spaces or embedded commas.
            data = readtable(csvPath, 'Delimiter', ',', 'VariableNamingRule', 'preserve');

            if height(data) == 0
                log.warn('  %s: CSV has no data rows — skipping', tableName);
                nSkipped = nSkipped + 1;
                continue
            end

            % Clear existing rows before re-inserting.
            conn.execute(sprintf('DELETE FROM [dbo].[%s]', tableName));

            conn.insert(tableName, data);
            log.info('  %s: %d rows inserted', tableName, height(data));
            nPushed = nPushed + 1;

        catch ME
            log.error('  %s: FAILED — %s', tableName, ME.message);
            failed{end+1} = tableName; %#ok<AGROW>
            nFailed = nFailed + 1;
        end
    end

catch ME
    conn.close();
    rethrow(ME);
end

conn.close();

fprintf('\n--- push_lookup_tables summary ---\n');
fprintf('  Pushed:  %d\n', nPushed);
fprintf('  Skipped: %d\n', nSkipped);
fprintf('  Failed:  %d\n', nFailed);
if ~isempty(failed)
    fprintf('  Failed tables: %s\n', strjoin(failed, ', '));
end
