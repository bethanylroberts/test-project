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


function test_speccode_has_threshold_columns(testCase)
% SPECCODE should have 8 columns including the two new threshold columns.
tablesDir = fullfile(projectRoot(), 'data', 'tables');
fpath = fullfile(tablesDir, 'SPECCODE.csv');
data = readtable(fpath, 'VariableNamingRule', 'preserve');
testCase.verifyEqual(width(data), 8, ...
    sprintf('SPECCODE.csv expected 8 columns, got %d', width(data)));
testCase.verifyTrue(ismember('typical_max_group', data.Properties.VariableNames), ...
    'SPECCODE.csv missing column typical_max_group');
testCase.verifyTrue(ismember('typical_max_calf', data.Properties.VariableNames), ...
    'SPECCODE.csv missing column typical_max_calf');
end


function test_taxcode_has_threshold_columns(testCase)
% TAXCODE should have 4 columns including the two new threshold columns.
tablesDir = fullfile(projectRoot(), 'data', 'tables');
fpath = fullfile(tablesDir, 'TAXCODE.csv');
data = readtable(fpath, 'VariableNamingRule', 'preserve');
testCase.verifyEqual(width(data), 4, ...
    sprintf('TAXCODE.csv expected 4 columns, got %d', width(data)));
testCase.verifyTrue(ismember('typical_max_group', data.Properties.VariableNames), ...
    'TAXCODE.csv missing column typical_max_group');
testCase.verifyTrue(ismember('typical_max_calf', data.Properties.VariableNames), ...
    'TAXCODE.csv missing column typical_max_calf');
end


function test_taxcode_thresholds_populated(testCase)
% TAXCODE rows with biological categories should have non-NULL group thresholds.
tablesDir = fullfile(projectRoot(), 'data', 'tables');
fpath = fullfile(tablesDir, 'TAXCODE.csv');
data = readtable(fpath, 'VariableNamingRule', 'preserve');
% TAXCODE 1-5 and 9 should have group thresholds (biological categories)
bio_codes = [1, 2, 3, 4, 5, 9];
for k = 1:length(bio_codes)
    row = data(data.Value == bio_codes(k), :);
    testCase.assertFalse(isempty(row), ...
        sprintf('TAXCODE %d missing from TAXCODE.csv', bio_codes(k)));
    testCase.assertFalse(isnan(row.typical_max_group), ...
        sprintf('TAXCODE %d expected a non-NULL typical_max_group', bio_codes(k)));
end
end


function root = projectRoot()
% Return the repository root, assuming this file lives at tests/unit/.
thisDir = fileparts(mfilename('fullpath'));
root = fullfile(thisDir, '..', '..');
end
