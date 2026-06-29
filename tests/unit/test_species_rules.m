function tests = test_species_rules
% test_species_rules - Unit tests for the NUMBER/NUMCALF threshold cascade in species_rules.
%
% Tests the SPECCODE → TAXCODE → global-default cascade for group-size and
% calf-count threshold checks. All tests use mock lookup tables; no live DB required.

tests = functiontests(localfunctions);
end


%% =========================================================================
%  GROUP SIZE (NUMBER) THRESHOLD CASCADE
%% =========================================================================

function test_speccode_override_wins(testCase)
% SPECCODE.typical_max_group overrides the TAXCODE default.
% SPECCODE threshold = 10; TAXCODE threshold = 100.
% NUMBER = 20 should trigger a warning from the SPECCODE override.
config = make_config(10, NaN, 100, NaN);
data   = make_data('RIWH', 1, 20, NaN);
collector = narwc.validation.ErrorCollector();
narwc.validation.rules.species_rules(data, collector, config);
w = get_warnings_by_rule(collector, 'species_rules.number_unusual');
testCase.assertGreaterThan(length(w), 0, ...
    'Expected a number_unusual warning when NUMBER exceeds SPECCODE threshold');
testCase.assertNotEmpty(regexp(w(1).message, 'SPECCODE override', 'once'), ...
    'Warning message should cite "SPECCODE override" as the source');
end


function test_speccode_override_suppresses_at_threshold(testCase)
% NUMBER = 10 (at the SPECCODE threshold) should NOT trigger a warning.
config = make_config(10, NaN, 100, NaN);
data   = make_data('RIWH', 1, 10, NaN);
collector = narwc.validation.ErrorCollector();
narwc.validation.rules.species_rules(data, collector, config);
w = get_warnings_by_rule(collector, 'species_rules.number_unusual');
testCase.assertEmpty(w, 'No warning expected when NUMBER equals the threshold');
end


function test_taxcode_fallback_used_when_speccode_null(testCase)
% SPECCODE.typical_max_group is NULL; TAXCODE.typical_max_group = 100.
% NUMBER = 200 should trigger a warning citing TAXCODE as source.
config = make_config(NaN, NaN, 100, NaN);
data   = make_data('RIWH', 1, 200, NaN);
collector = narwc.validation.ErrorCollector();
narwc.validation.rules.species_rules(data, collector, config);
w = get_warnings_by_rule(collector, 'species_rules.number_unusual');
testCase.assertGreaterThan(length(w), 0, ...
    'Expected a number_unusual warning when NUMBER exceeds TAXCODE threshold');
testCase.assertNotEmpty(regexp(w(1).message, 'TAXCODE', 'once'), ...
    'Warning message should cite TAXCODE as the source');
end


function test_global_fallback_used_when_both_null(testCase)
% Both SPECCODE and TAXCODE thresholds are NULL; global default = 1000.
% NUMBER = 1500 should trigger a warning citing the global default.
config = make_config(NaN, NaN, NaN, NaN);
config.thresholds.group_size_default = 1000;
data   = make_data('RIWH', 1, 1500, NaN);
collector = narwc.validation.ErrorCollector();
narwc.validation.rules.species_rules(data, collector, config);
w = get_warnings_by_rule(collector, 'species_rules.number_unusual');
testCase.assertGreaterThan(length(w), 0, ...
    'Expected a number_unusual warning when NUMBER exceeds global default');
testCase.assertNotEmpty(regexp(w(1).message, 'global default', 'once'), ...
    'Warning message should cite "global default" as the source');
end


function test_no_warning_below_global_threshold(testCase)
% NUMBER = 500 below global default of 1000; no number_unusual warning.
config = make_config(NaN, NaN, NaN, NaN);
config.thresholds.group_size_default = 1000;
data   = make_data('RIWH', 1, 500, NaN);
collector = narwc.validation.ErrorCollector();
narwc.validation.rules.species_rules(data, collector, config);
w = get_warnings_by_rule(collector, 'species_rules.number_unusual');
testCase.assertEmpty(w, 'No number_unusual warning expected when NUMBER < global default');
end


%% =========================================================================
%  CALF COUNT (NUMCALF) THRESHOLD CASCADE
%% =========================================================================

function test_calf_speccode_override_wins(testCase)
% SPECCODE.typical_max_calf = 2; TAXCODE.typical_max_calf = 20.
% NUMCALF = 5 should trigger a warning citing SPECCODE override.
config = make_config(NaN, 2, NaN, 20);
data   = make_data('RIWH', 1, 5, 5);
collector = narwc.validation.ErrorCollector();
narwc.validation.rules.species_rules(data, collector, config);
w = get_warnings_by_rule(collector, 'species_rules.numcalf_unusual');
testCase.assertGreaterThan(length(w), 0, ...
    'Expected a numcalf_unusual warning when NUMCALF exceeds SPECCODE threshold');
testCase.assertNotEmpty(regexp(w(1).message, 'SPECCODE override', 'once'), ...
    'Warning message should cite "SPECCODE override" as the source');
end


function test_calf_taxcode_fallback(testCase)
% SPECCODE.typical_max_calf is NULL; TAXCODE.typical_max_calf = 20.
% NUMCALF = 30 should trigger a warning citing TAXCODE.
config = make_config(NaN, NaN, NaN, 20);
data   = make_data('RIWH', 1, 30, 30);
collector = narwc.validation.ErrorCollector();
narwc.validation.rules.species_rules(data, collector, config);
w = get_warnings_by_rule(collector, 'species_rules.numcalf_unusual');
testCase.assertGreaterThan(length(w), 0, ...
    'Expected a numcalf_unusual warning when NUMCALF exceeds TAXCODE threshold');
testCase.assertNotEmpty(regexp(w(1).message, 'TAXCODE', 'once'), ...
    'Warning message should cite TAXCODE as the source');
end


function test_calf_global_fallback(testCase)
% Both thresholds NULL; global calf default = 100.
% NUMCALF = 150 should trigger a warning citing global default.
config = make_config(NaN, NaN, NaN, NaN);
config.thresholds.calf_count_default = 100;
data   = make_data('RIWH', 1, 200, 150);
collector = narwc.validation.ErrorCollector();
narwc.validation.rules.species_rules(data, collector, config);
w = get_warnings_by_rule(collector, 'species_rules.numcalf_unusual');
testCase.assertGreaterThan(length(w), 0, ...
    'Expected a numcalf_unusual warning when NUMCALF exceeds global default');
testCase.assertNotEmpty(regexp(w(1).message, 'global default', 'once'), ...
    'Warning message should cite "global default" as the source');
end


%% =========================================================================
%  HELPERS
%% =========================================================================

function config = make_config(spec_grp, spec_calf, tax_grp, tax_calf)
% Build a minimal species_rules config with mock lookup tables.
% NaN arguments mean NULL (no threshold for that cell).

config = struct();

% Mock SPECCODE table: one row for RIWH
spec_table = table({'RIWH'}, spec_grp, spec_calf, ...
    'VariableNames', {'Value', 'typical_max_group', 'typical_max_calf'});
config.speccode_table = spec_table;
config.speccode_map   = containers.Map({'RIWH'}, {1});

% Mock TAXCODE table: one row for taxcode 1 (large cetacean)
tax_table = table(1, tax_grp, tax_calf, ...
    'VariableNames', {'Value', 'typical_max_group', 'typical_max_calf'});
config.taxcode_table = tax_table;
config.taxcode_map   = containers.Map([1], [1]);

% Global fallbacks
config.thresholds.group_size_default = 1000;
config.thresholds.calf_count_default  = 100;

% Disable checks that would fire on the minimal mock data
config.validate_speccode_lookup        = false;
config.validate_taxcode_lookup         = false;
config.validate_speccode_taxcode_match = false;
config.require_speccode_for_sightings  = false;
config.require_taxcode_for_sightings   = false;
config.valid_taxcodes                  = 0:9;
config.cetacean_taxcodes               = [1, 2, 3];
config.marine_mammal_taxcodes          = [1, 2, 3, 4];
config.right_whale_codes               = {'RIWH', 'NARW', 'SARW'};
config.right_whale_max_group           = 9999;  % suppress right-whale-specific check
config.right_whale_max_calves          = 9999;
config.lookup_table_dir                = '';    % prevent file loading
config.allow_numcalf_exceeds_half      = false;
end


function data = make_data(speccode, taxcode, number, numcalf)
% Build a minimal 1-row survey table for testing.
data = table();
data.SPECCODE = {speccode};
data.TAXCODE  = taxcode;
data.SIGHTNO  = 1;
data.EVENTNO  = 1;
if ~isnan(number)
    data.NUMBER = number;
else
    data.NUMBER = NaN;
end
if ~isnan(numcalf)
    data.NUMCALF = numcalf;
else
    data.NUMCALF = NaN;
end
end


function w = get_warnings_by_rule(collector, rule_id)
% Return all warnings/errors matching a given rule_id.
all_errors = collector.getErrors();
w = all_errors(strcmp({all_errors.rule_id}, rule_id));
end
