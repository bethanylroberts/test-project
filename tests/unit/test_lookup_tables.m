function tests = test_lookup_tables
% test_lookup_tables - Data hygiene tests for lookup table CSVs.
%
% Verifies that every CSV in data/tables/ can be loaded with plain readtable
% and has at least 2 columns and at least 1 data row. Fails fast if a CSV
% is malformed (wrong delimiter, missing header, empty file, etc.).
%
% Does not require a database connection.

tests = functiontests(localfunctions);
end


function test_all_csvs_load_with_readtable(testCase)
% Verify every lookup-table CSV loads cleanly and has minimal expected structure.

tablesDir = fullfile(projectRoot(), 'data', 'tables');

files = dir(fullfile(tablesDir, '*.csv'));
testCase.assertFalse(isempty(files), 'No CSV files found in data/tables/');

failures = {};
for i = 1:length(files)
    fname = files(i).name;
    if strcmp(fname, 'sysdiagrams.csv')
        continue  % binary table — does not roundtrip via CSV
    end

    fpath = fullfile(tablesDir, fname);
    try
        data = readtable(fpath, 'VariableNamingRule', 'preserve');
        if width(data) < 2
            failures{end+1} = sprintf('%s: only %d column(s)', fname, width(data)); %#ok<AGROW>
        elseif height(data) < 1
            failures{end+1} = sprintf('%s: no data rows', fname); %#ok<AGROW>
        end
    catch ME
        failures{end+1} = sprintf('%s: readtable error — %s', fname, ME.message); %#ok<AGROW>
    end
end

if ~isempty(failures)
    testCase.verifyEmpty(failures, ...
        sprintf('Lookup CSV failures:\n  %s', strjoin(failures, '\n  ')));
end
end


function root = projectRoot()
% Return the repository root, assuming this file lives at tests/unit/.
thisDir = fileparts(mfilename('fullpath'));
root = fullfile(thisDir, '..', '..');
end
