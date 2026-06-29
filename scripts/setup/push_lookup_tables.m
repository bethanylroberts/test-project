% PUSH_LOOKUP_TABLES - Push local lookup-table CSVs into the database.
%
% Reads each CSV in data/tables/, then for each row:
%   - If a matching row exists in the DB (by primary key), UPDATE it
%   - If not, INSERT it
%
% Does NOT delete rows present in the DB but absent from the CSV. To
% retire a code, the curator must run a manual DELETE in SSMS (which
% will fail safely if any Master row references the code). This makes
% deletions a deliberate curatorial action rather than a script side
% effect.
%
% Usage: run from the project root after editing lookup CSVs.
%   Requires a live database connection (config/db_config.m).
%   Does NOT update the Master table.
%   Skips sysdiagrams (binary system table that does not roundtrip).
%
% 2026 russ.shomberg@marineacoustics.com

logger = logging.Logger('narwc.setup.push_lookup_tables');

tablesDir = fullfile('.', 'data', 'tables');
if ~isfolder(tablesDir)
    error('push_lookup_tables:missingDir', ...
        'data/tables/ not found. Run from the project root directory.');
end

files = dir(fullfile(tablesDir, '*.csv'));
if isempty(files)
    error('push_lookup_tables:noFiles', 'No CSV files found in %s', tablesDir);
end

logger.info('Connecting to database...');
conn = narwc.db.Connection.create();

nUpdated  = 0;
nInserted = 0;
nFailed   = 0;
nSkipped  = 0;
failed    = {};

try
    for i = 1:length(files)
        fname     = files(i).name;
        tableName = fname(1:end-4);  % strip .csv

        if strcmp(tableName, 'sysdiagrams')
            logger.debug(sprintf('Skipping %s (system table)', tableName));
            nSkipped = nSkipped + 1;
            continue
        end

        csvPath = fullfile(tablesDir, fname);
        logger.info(sprintf('[%d/%d] Pushing %s ...', i, length(files), tableName));

        try
            data = readtable(csvPath, 'Delimiter', ',', 'VariableNamingRule', 'preserve');

            if height(data) == 0
                logger.warning(sprintf('  %s: CSV has no data rows — skipping', tableName));
                nSkipped = nSkipped + 1;
                continue
            end

            % Type coercion for varchar Value columns whose CSV reads as numeric
            string_value_tables = {'Contrib', 'LEGGOOD', 'OLDVIZ'};
            if ismember(tableName, string_value_tables) && ...
                    ismember('Value', data.Properties.VariableNames) && ...
                    isnumeric(data.Value)
                data.Value = arrayfun(@(x) {num2str(x)}, data.Value);
            end

            % SPECCODE.TAXCODE needs the same treatment
            if strcmp(tableName, 'SPECCODE') && ...
                    ismember('TAXCODE', data.Properties.VariableNames) && ...
                    isnumeric(data.TAXCODE)
                data.TAXCODE = arrayfun(@(x) {num2str(x)}, data.TAXCODE);
            end

            % Get existing primary key values from the DB
            existing = conn.fetch(sprintf('SELECT Value FROM [dbo].[%s]', tableName));
            existing_values = existing.Value;

            % Split CSV rows into "to update" and "to insert"
            csv_values = data.Value;
            
            % Build comparison — handle both numeric and string Value types
            if iscell(csv_values) || isstring(csv_values)
                csv_values_compare = string(csv_values);
                existing_values_compare = string(existing_values);
            else
                csv_values_compare = csv_values;
                existing_values_compare = existing_values;
            end
            
            is_existing = ismember(csv_values_compare, existing_values_compare);
            
            rows_to_update = data(is_existing, :);
            rows_to_insert = data(~is_existing, :);

            % UPDATE existing rows
            if ~isempty(rows_to_update)
                for ri = 1:height(rows_to_update)
                    row = rows_to_update(ri, :);
                    update_row_in_table(conn, tableName, row);
                end
            end

            % INSERT new rows
            if ~isempty(rows_to_insert)
                conn.insert(tableName, rows_to_insert);
            end

            logger.info(sprintf('  %s: %d updated, %d inserted', ...
                tableName, height(rows_to_update), height(rows_to_insert)));
            nUpdated  = nUpdated  + height(rows_to_update);
            nInserted = nInserted + height(rows_to_insert);

        catch ME
            logger.error(sprintf('  %s: FAILED — %s', tableName, ME.message));
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
fprintf('  Rows updated:  %d\n', nUpdated);
fprintf('  Rows inserted: %d\n', nInserted);
fprintf('  Tables skipped: %d\n', nSkipped);
fprintf('  Tables failed: %d\n', nFailed);
if ~isempty(failed)
    fprintf('  Failed tables: %s\n', strjoin(failed, ', '));
end


% ---- helper function ----
function update_row_in_table(conn, tableName, row)
% UPDATE_ROW_IN_TABLE Update one row in a lookup table by primary key (Value)

    columns = row.Properties.VariableNames;
    set_clauses = {};
    for c = 1:length(columns)
        col = columns{c};
        if strcmp(col, 'Value')
            continue
        end
        val = row.(col);
        if iscell(val)
            val = val{1};
        end
        
        if is_null_value(val)
            set_clauses{end+1} = sprintf('[%s] = NULL', col); %#ok<AGROW>
        elseif isnumeric(val)
            set_clauses{end+1} = sprintf('[%s] = %g', col, val); %#ok<AGROW>
        else
            val_str = strrep(char(val), '''', '''''');
            set_clauses{end+1} = sprintf('[%s] = ''%s''', col, val_str); %#ok<AGROW>
        end
    end

    if isempty(set_clauses)
        return
    end

    value_field = row.Value;
    if iscell(value_field)
        value_field = value_field{1};
    end
    if isnumeric(value_field)
        where_clause = sprintf('[Value] = %g', value_field);
    else
        val_str = strrep(char(value_field), '''', '''''');
        where_clause = sprintf('[Value] = ''%s''', val_str);
    end

    sql = sprintf('UPDATE [dbo].[%s] SET %s WHERE %s', ...
        tableName, strjoin(set_clauses, ', '), where_clause);
    
    conn.execute(sql);
end

function tf = is_null_value(val)
% IS_NULL_VALUE Check if value should be treated as SQL NULL
    if isempty(val)
        tf = true;
    elseif isnumeric(val)
        tf = all(isnan(val));
    elseif ischar(val)
        tf = isempty(strtrim(val));
    elseif isstring(val)
        tf = ismissing(val) || strlength(val) == 0;
    elseif iscategorical(val)
        tf = ismissing(val);
    else
        tf = false;
    end
end