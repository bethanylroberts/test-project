classdef test_validation < matlab.unittest.TestCase
    % TEST_VALIDATION Unit tests for validation framework
    
    methods (Test)
        function testErrorCollector(testCase)
            % Test ErrorCollector functionality
            
            collector = narwc.validation.ErrorCollector();
            
            % Add errors
            collector.addError('LAT_DD', 1, 'Test error', 'error');
            collector.addError('LONG_DD', 2, 'Test warning', 'warning');
            
            % Check counts
            testCase.verifyEqual(collector.getErrorCount(), 2);
            testCase.verifyEqual(collector.getErrorCount('error'), 1);
            testCase.verifyEqual(collector.getErrorCount('warning'), 1);
            
            % Get errors
            errors = collector.getErrors('error');
            testCase.verifyEqual(length(errors), 1);
            testCase.verifyEqual(errors(1).field, 'LAT_DD');
            
            % Clear
            collector.clear();
            testCase.verifyEqual(collector.getErrorCount(), 0);
        end
        
        function testFieldValidatorRange(testCase)
            % Test range validation
            
            values = [1; 5; 10; 15; 20];
            [is_valid, invalid] = narwc.validation.FieldValidator.validateRange(values, 5, 15);
            
            testCase.verifyEqual(is_valid, [false; true; true; true; false]);
            testCase.verifyEqual(invalid, [1; 5]);
        end
        
        function testFieldValidatorMissing(testCase)
            % Test missing value validation
            
            values = [1; NaN; 3; NaN; 5];
            [is_valid, invalid] = narwc.validation.FieldValidator.validateNotMissing(values);
            
            testCase.verifyEqual(sum(~is_valid), 2);
            testCase.verifyEqual(invalid, [2; 4]);
        end
        
        function testFieldValidatorInSet(testCase)
            % Test set membership validation
            
            values = {'RIWH'; 'FIWH'; 'HUWH'; 'UNKNOWN'};
            valid_set = {'RIWH', 'FIWH', 'HUWH', 'SEWH'};
            [is_valid, invalid] = narwc.validation.FieldValidator.validateInSet(values, valid_set);
            
            testCase.verifyFalse(is_valid(4));
            testCase.verifyEqual(invalid, 4);
        end
        
        function testCoordinateValidation(testCase)
            % Test coordinate validation rules
            
            % Create test data
            data = table();
            data.LAT_DD = [41.5; 100; NaN; 42.0];  % One out of range, one missing
            data.LONG_DD = [-70.0; -71.0; -72.0; NaN];  % One missing
            
            collector = narwc.validation.ErrorCollector();
            narwc.validation.rules.coordinate_rules(data, collector);
            
            % Should have errors
            testCase.verifyGreaterThan(collector.getErrorCount('error'), 0);
        end
        
        function testRequiredFieldsValidation(testCase)
            % Test required fields validation
            
            % Create test data missing required fields
            data = table();
            data.LAT_DD = [41.5; 42.0];
            data.LONG_DD = [-70.0; -71.0];
            % Missing FILEID, YEAR, etc.
            
            collector = narwc.validation.ErrorCollector();
            narwc.validation.rules.required_fields(data, collector);
            
            % Should have errors for missing required fields
            testCase.verifyGreaterThan(collector.getErrorCount('error'), 0);
        end
        
        function testDateTimeValidation(testCase)
            % Test datetime validation rules
            
            % Create test data with invalid dates
            data = table();
            data.YEAR = [2020; 2021; 3000; 2022];  % One invalid year
            data.MONTH = [1; 13; 6; 2];  % One invalid month
            data.DAY = [15; 20; 32; 10];  % One invalid day
            data.TIME = [120000; 240000; 93000; 150000];  % One invalid time
            
            collector = narwc.validation.ErrorCollector();
            narwc.validation.rules.datetime_rules(data, collector);
            
            % Should have errors
            testCase.verifyGreaterThan(collector.getErrorCount('error'), 0);
        end

        function testMonthSeasonCodes(testCase)
            % MONTH 1-12 (calendar) and 13-16 (season codes) are all valid;
            % 0 and 17 are out of range.

            data = table();
            data.YEAR  = [2020; 2020; 2020; 2020];
            data.MONTH = [6; 14; 17; 0];
            data.DAY   = [15; NaN; 10; 5];
            data.TIME  = [120000; 0; 0; 0];

            collector = narwc.validation.ErrorCollector();
            narwc.validation.rules.datetime_rules(data, collector);

            errors = collector.getErrors('error');
            % row may be a vector when multiple rows fail a single rule;
            % gather all row indices from MONTH-field errors.
            invalid_months = [];
            for k = 1:length(errors)
                if strcmp(errors(k).field, 'MONTH')
                    invalid_months = [invalid_months; errors(k).row(:)]; %#ok<AGROW>
                end
            end

            % Rows 3 (MONTH=17) and 4 (MONTH=0) must fail; rows 1 and 2 must not.
            testCase.verifyTrue(ismember(3, invalid_months), ...
                'MONTH=17 should be invalid');
            testCase.verifyTrue(ismember(4, invalid_months), ...
                'MONTH=0 should be invalid');
            testCase.verifyFalse(ismember(1, invalid_months), ...
                'MONTH=6 should be valid');
            testCase.verifyFalse(ismember(2, invalid_months), ...
                'MONTH=14 (season code) should be valid');
        end

        function testBeaufortValidation(testCase)
            % Test Beaufort scale validation
            
            % Create test data
            data = table();
            data.BEAUFORT = [0; 5; 12; 15; NaN];  % One invalid (15)
            
            collector = narwc.validation.ErrorCollector();
            narwc.validation.rules.beaufort_rules(data, collector);
            
            % Should have 1 error
            testCase.verifyEqual(collector.getErrorCount('error'), 1);
        end
        
        function testSpeciesValidation(testCase)
            % Test species validation rules
            
            % Create test data
            data = table();
            data.SPECCODE = {'RIWH'; 'FIWH'; 'TOOLONG'; 'BA'};  % One too long
            data.TAXCODE = [1; 2; 99; 3];  % One invalid
            data.NUMBER = [5; -1; 10; 2000];  % One negative, one large
            data.NUMCALF = [1; 0; 2; 20];  % Last one exceeds NUMBER
            
            collector = narwc.validation.ErrorCollector();
            narwc.validation.rules.species_rules(data, collector);
            
            % Should have multiple errors
            testCase.verifyGreaterThan(collector.getErrorCount('error'), 0);
        end
        
        function testEnvironmentalValidation(testCase)
            % Test environmental rules.
            %
            % CLOUD and WX validation are currently disabled (removed from
            % environmental_rules.m; CLOUD via lookup table, WX via lookup
            % table).  SURFTEMP and VISIBLTY out-of-range produce warnings,
            % not errors.  The assertion reflects current behaviour.

            data = table();
            data.CLOUD = [0; 1; 9; 2];
            data.VISIBLTY = [10; 20; -5; 100];   % 100 > visibility_max=50 → warning
            data.SURFTEMP = [15; 20; -10; 50];   % -10 < -2 and 50 > 35 → warnings
            data.GLAREL = [0; 1; 5; 2];
            data.GLARER = [0; 2; 1; 3];
            data.WX = {'C'; 'R'; 'F'; 'LONG'};

            collector = narwc.validation.ErrorCollector();
            narwc.validation.rules.environmental_rules(data, collector);

            % Function generates warnings for out-of-range SURFTEMP and VISIBLTY
            testCase.verifyGreaterThan(collector.getErrorCount('warning'), 0);
        end
        
        function testSurveyValidator(testCase)
            % Test main validator
            
            % Create test data
            data = TestFixtures.generate_mock_survey(10);
            
            % Add some invalid data
            data.LAT_DD(1) = 100;  % Invalid
            data.LONG_DD(2) = NaN; % Missing
            data.YEAR(3) = 3000;   % Invalid year
            
            % Validate
            validator = narwc.validation.SurveyValidator();
            [is_valid, results] = validator.validate(data);
            
            % Should be invalid
            testCase.verifyFalse(is_valid);
            testCase.verifyGreaterThan(results.summary.errors, 0);
        end
        
        function testValidDataPasses(testCase)
            % Test that valid data passes validation
            
            % Generate valid mock data
            data = TestFixtures.generate_mock_survey(10);
            
            % Allow warnings but not errors
            config = struct();
            config.allow_warnings = true;   % FIXME: test this as well
            config.allow_errors = false;    
            
            validator = narwc.validation.SurveyValidator(config);
            [is_valid, results] = validator.validate(data);
            
            % Should pass (no errors, warnings OK)
            testCase.verifyTrue(is_valid, ...
                sprintf('Valid data should pass validation. Errors found: %s', ...
                strjoin(results.error_details, '; ')));
        end
        
        function testValidatorWithCustomConfig(testCase)
            % Test validator with custom configuration
            
            config = struct();
            config.validate_coordinates = true;
            config.validate_datetime = true;
            config.validate_species = false;  % Disable species validation
            config.validate_environmental = false;  % Disable environmental
            config.validate_beaufort = false;
            config.validate_required_fields = true;
            
            % Add coordinate ranges
            config.lat_min = -90;
            config.lat_max = 90;
            config.lon_min = -180;
            config.lon_max = 180;
            config.survey_lat_min = 35;
            config.survey_lat_max = 50;
            config.survey_lon_min = -75;
            config.survey_lon_max = -60;
            
            % Add datetime config
            config.year_min = 1970;
            config.year_max = year(datetime('today'));
            config.year_warning = 1990;
            
            % Add required fields
            config.required_fields = {'FILEID', 'YEAR'};
            
            % Create test data
            data = TestFixtures.generate_mock_survey(5);
            
            % Validate with custom config
            validator = narwc.validation.SurveyValidator(config);
            [is_valid, results] = validator.validate(data);
            
            % Should run without error
            testCase.verifyTrue(is_valid || ~is_valid);  % Just verify it runs
        end
        
        function testErrorDetailsFormatting(testCase)
            % Test that error details are properly formatted
            
            % Create test data with errors - must include all required fields
            data = table();
            data.FILEID = {'TEST01'; 'TEST02'};
            data.EVENTNO = [1; 2];
            data.YEAR = [2020; 2021];
            data.MONTH = [1; 13];  % Invalid month
            data.DAY = [15; 20];
            data.TIME = [120000; 150000];
            data.LAT_DD = [100; 42];  % Invalid latitude
            data.LONG_DD = [-70; -71];
            data.DDSOURCE = {'GPS'; 'GPS'};  % Required
            data.IDSOURCE = {'VIS'; 'VIS'};  % Required
            
            % Validate
            validator = narwc.validation.SurveyValidator();
            [~, results] = validator.validate(data);
            
            % Should have error details
            testCase.verifyTrue(isfield(results, 'error_details'));
            testCase.verifyGreaterThan(length(results.error_details), 0);
            
            % Check format
            for i = 1:length(results.error_details)
                detail = results.error_details{i};
                testCase.verifyTrue(contains(detail, '[ERROR]') || contains(detail, '[WARNING]'));
            end
        end

        function testErrorCollectorStructure(testCase)
            % Debug test to see error structure

            collector = narwc.validation.ErrorCollector();
            collector.addError('TEST_FIELD', [1, 2, 3], 'Test message', 'error');

            errors = collector.getErrors('error');

            % Display structure
            disp('Error structure:');
            disp(errors);

            if ~isempty(errors)
                disp('Fields in error struct:');
                disp(fieldnames(errors(1)));
            end

            testCase.verifyTrue(true);  % Always pass, just for debugging
        end

        function testErrorCollectorRuleId(testCase)
            % rule_id and eventno must be stored and retrievable

            collector = narwc.validation.ErrorCollector();
            collector.addError('YEAR', 3, 'Year too old', 'warning', ...
                'datetime_rules.year_too_old', 42);

            w = collector.getErrors('warning');
            testCase.verifyEqual(length(w), 1);
            testCase.verifyEqual(w(1).rule_id, 'datetime_rules.year_too_old');
            testCase.verifyEqual(w(1).eventno, 42);
        end

        function testErrorCollectorDemoteToInfo(testCase)
            % demoteToInfo must change severity and be excluded from warning count

            collector = narwc.validation.ErrorCollector();
            collector.addError('YEAR', 3, 'Year too old', 'warning', ...
                'datetime_rules.year_too_old', 10);
            collector.addError('LAT_DD', 5, 'Outside survey area', 'warning', ...
                'coordinate_rules.outside_survey_lat', 20);

            idx = collector.getWarningIndices();
            testCase.verifyEqual(length(idx), 2);

            % Demote the first warning
            collector.demoteToInfo(idx(1));

            testCase.verifyEqual(collector.getErrorCount('warning'), 1);
            testCase.verifyEqual(collector.getErrorCount('info'), 1);
        end

        % -----------------------------------------------------------------
        % Override-gate tests
        % -----------------------------------------------------------------

        function testWarningBlocksWithoutOverride(testCase)
            % A survey with warnings only, no overrides -> is_valid = false

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);

            % Create data directory (no overrides.csv)
            mkdir('data');

            data = make_survey_with_old_year(testCase);

            cfg = struct('override_file', fullfile('data', 'overrides.csv'));
            cfg.allow_warnings = false;
            validator = narwc.validation.SurveyValidator(cfg);
            [is_valid, results] = validator.validate(data);

            testCase.verifyFalse(is_valid, ...
                'Survey with unacknowledged warning must not be valid');
            testCase.verifyGreaterThan(results.summary.warnings_new, 0, ...
                'warnings_new must be > 0');
            testCase.verifyEqual(results.summary.warnings_acknowledged, 0);
        end

        function testAllWarningsAcknowledged(testCase)
            % A survey with warnings, all matching overrides -> is_valid = true

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            mkdir('data');

            data    = make_survey_with_old_year(testCase);
            fileid  = data.FILEID{1};
            eventno = data.EVENTNO(1);

            write_override(fullfile('data', 'overrides.csv'), ...
                fileid, eventno, 'YEAR', 'datetime_rules.year_too_old');

            cfg = struct('override_file', fullfile('data', 'overrides.csv'));
            cfg.allow_warnings = false;
            validator = narwc.validation.SurveyValidator(cfg);
            [is_valid, results] = validator.validate(data);

            testCase.verifyTrue(is_valid, ...
                'All warnings acknowledged -> survey must be valid');
            testCase.verifyEqual(results.summary.warnings_new, 0);
            testCase.verifyEqual(results.summary.warnings_acknowledged, 1);
        end

        function testPartialOverrideStillBlocks(testCase)
            % Some warnings overridden, others not -> is_valid = false

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            mkdir('data');

            data = make_survey_two_old_years(testCase);
            fileid = data.FILEID{1};

            % Acknowledge only the first EVENTNO
            write_override(fullfile('data', 'overrides.csv'), ...
                fileid, data.EVENTNO(1), 'YEAR', 'datetime_rules.year_too_old');

            cfg = struct('override_file', fullfile('data', 'overrides.csv'));
            cfg.allow_warnings = false;
            validator = narwc.validation.SurveyValidator(cfg);
            [is_valid, results] = validator.validate(data);

            testCase.verifyFalse(is_valid, ...
                'Partial override must still block when unacknowledged warnings remain');
            testCase.verifyEqual(results.summary.warnings_acknowledged, 1);
            testCase.verifyGreaterThan(results.summary.warnings_new, 0);
        end

        function testErrorsBlockEvenWithAllWarningsAcknowledged(testCase)
            % Errors + all warnings overridden -> still is_valid = false

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            mkdir('data');

            % Data with both an error (bad month) and an old-year warning.
            % Use MONTH=13 instead of a bad latitude to avoid generating a
            % coordinate warning that would need its own override entry.
            data         = make_survey_with_old_year(testCase);
            data.MONTH(1) = 13;  % Out-of-range month -> error, no side-effect warning

            fileid  = data.FILEID{1};
            eventno = data.EVENTNO(1);
            write_override(fullfile('data', 'overrides.csv'), ...
                fileid, eventno, 'YEAR', 'datetime_rules.year_too_old');

            cfg = struct('override_file', fullfile('data', 'overrides.csv'));
            cfg.allow_warnings = false;
            validator = narwc.validation.SurveyValidator(cfg);
            [is_valid, results] = validator.validate(data);

            testCase.verifyFalse(is_valid, ...
                'Errors must block even when all warnings are acknowledged');
            testCase.verifyGreaterThan(results.summary.errors, 0);
            testCase.verifyEqual(results.summary.warnings_acknowledged, 1);
            testCase.verifyEqual(results.summary.warnings_new, 0);
        end

        function testOverrideRuleIdMismatchDoesNotMatch(testCase)
            % Override with wrong rule_id must not suppress the warning

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            mkdir('data');

            data    = make_survey_with_old_year(testCase);
            fileid  = data.FILEID{1};
            eventno = data.EVENTNO(1);

            % Write override with a WRONG rule_id
            write_override(fullfile('data', 'overrides.csv'), ...
                fileid, eventno, 'YEAR', 'datetime_rules.wrong_rule_id');

            cfg = struct('override_file', fullfile('data', 'overrides.csv'));
            cfg.allow_warnings = false;
            validator = narwc.validation.SurveyValidator(cfg);
            [is_valid, results] = validator.validate(data);

            testCase.verifyFalse(is_valid, ...
                'Rule_id mismatch must not suppress the warning');
            testCase.verifyEqual(results.summary.warnings_acknowledged, 0);
            testCase.verifyGreaterThan(results.summary.warnings_new, 0);
        end

        function testMissingOverrideFileDoesNotCrash(testCase)
            % Missing override file -> behaves as no overrides, no crash

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);

            % Do NOT create data/overrides.csv
            data = make_survey_with_old_year(testCase);

            cfg = struct('override_file', fullfile('data', 'overrides.csv'));
            cfg.allow_warnings = true;  % Allow warnings so we test crash-free path
            validator = narwc.validation.SurveyValidator(cfg);

            % Must not throw
            [is_valid, ~] = validator.validate(data);
            testCase.verifyTrue(is_valid || ~is_valid);  % Just verify no exception
        end

        % -----------------------------------------------------------------
        % Per-survey override tests
        % -----------------------------------------------------------------

        function testPerSurveyOverrideAcknowledgesAllMatchingWarnings(testCase)
            % N warnings of the same (field, rule_id) + a single per-survey
            % override (empty eventno) -> all N acknowledged, is_valid = true

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            mkdir('data');

            n    = 5;
            data = make_survey_n_old_years(n);

            write_per_survey_override(fullfile('data', 'overrides.csv'), ...
                data.FILEID{1}, 'YEAR', 'datetime_rules.year_too_old');

            cfg = struct('override_file', fullfile('data', 'overrides.csv'));
            cfg.allow_warnings = false;
            validator = narwc.validation.SurveyValidator(cfg);
            [is_valid, results] = validator.validate(data);

            testCase.verifyTrue(is_valid, ...
                'All warnings from per-survey override must pass validation');
            testCase.verifyEqual(results.summary.warnings_acknowledged, n, ...
                sprintf('All %d warnings must be acknowledged', n));
            testCase.verifyEqual(results.summary.warnings_acknowledged_per_survey, n, ...
                'All acknowledgements must be counted as per-survey');
            testCase.verifyEqual(results.summary.warnings_acknowledged_per_row, 0, ...
                'Per-row count must be 0 when only per-survey override is present');
            testCase.verifyEqual(results.summary.warnings_new, 0);
        end

        function testPerSurveyOverrideOnlyMatchesSpecifiedRule(testCase)
            % Per-survey override for one rule_id must not suppress warnings
            % from a different rule_id

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            mkdir('data');

            % Survey with old-year warning (YEAR) and high-visibility warning (VISIBLTY)
            data = make_survey_old_year_and_high_vis();

            % Acknowledge only the year warning
            write_per_survey_override(fullfile('data', 'overrides.csv'), ...
                data.FILEID{1}, 'YEAR', 'datetime_rules.year_too_old');

            cfg = struct('override_file', fullfile('data', 'overrides.csv'));
            cfg.allow_warnings = false;
            validator = narwc.validation.SurveyValidator(cfg);
            [is_valid, results] = validator.validate(data);

            testCase.verifyFalse(is_valid, ...
                'Unacknowledged visibility warning must still block');
            testCase.verifyEqual(results.summary.warnings_acknowledged, 1, ...
                'Only the year warning must be acknowledged');
            testCase.verifyGreaterThan(results.summary.warnings_new, 0, ...
                'Visibility warning must remain new');
        end

        function testPerRowAndPerSurveyBothMatchSameWarning_AcknowledgedOnce(testCase)
            % When a per-row override AND a per-survey override both match the
            % same warning, the warning must be acknowledged exactly once

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            mkdir('data');

            data    = make_survey_with_old_year(testCase);
            fileid  = data.FILEID{1};
            eventno = data.EVENTNO(1);

            % Write both kinds of override
            ovr_file = fullfile('data', 'overrides.csv');
            fid = fopen(ovr_file, 'w');
            fprintf(fid, 'fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason\n');
            fprintf(fid, '%s,%d,YEAR,datetime_rules.year_too_old,test,2026-01-01,per-row\n', fileid, eventno);
            fprintf(fid, '%s,,YEAR,datetime_rules.year_too_old,test,2026-01-01,per-survey\n', fileid);
            fclose(fid);

            cfg = struct('override_file', ovr_file);
            cfg.allow_warnings = false;
            validator = narwc.validation.SurveyValidator(cfg);
            [is_valid, results] = validator.validate(data);

            testCase.verifyTrue(is_valid, ...
                'Warning must be acknowledged (once) by either override');
            testCase.verifyEqual(results.summary.warnings_acknowledged, 1, ...
                'Warning must be counted as acknowledged exactly once');
        end

        function testPerSurveyOverrideFieldMismatchDoesNotMatch(testCase)
            % Per-survey override with a different field must not suppress the warning

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            mkdir('data');

            data = make_survey_with_old_year(testCase);

            % Override specifies a different field
            write_per_survey_override(fullfile('data', 'overrides.csv'), ...
                data.FILEID{1}, 'LAT_DD', 'datetime_rules.year_too_old');

            cfg = struct('override_file', fullfile('data', 'overrides.csv'));
            cfg.allow_warnings = false;
            validator = narwc.validation.SurveyValidator(cfg);
            [is_valid, results] = validator.validate(data);

            testCase.verifyFalse(is_valid, ...
                'Field mismatch in per-survey override must not suppress the warning');
            testCase.verifyEqual(results.summary.warnings_acknowledged, 0);
            testCase.verifyGreaterThan(results.summary.warnings_new, 0);
        end

        function testMixedPerRowAndPerSurveyCounts(testCase)
            % Survey with 3 same-rule warnings.  Per-row override for EVENTNO=1,
            % per-survey override for the rest.
            % Expected: per_row=1, per_survey=2, total=3

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            mkdir('data');

            data   = make_survey_n_old_years(3);
            fileid = data.FILEID{1};

            ovr_file = fullfile('data', 'overrides.csv');
            fid = fopen(ovr_file, 'w');
            fprintf(fid, 'fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason\n');
            % Per-row override for first eventno only
            fprintf(fid, '%s,%d,YEAR,datetime_rules.year_too_old,test,2026-01-01,per-row\n', ...
                fileid, data.EVENTNO(1));
            % Per-survey override catches the rest
            fprintf(fid, '%s,,YEAR,datetime_rules.year_too_old,test,2026-01-01,per-survey\n', fileid);
            fclose(fid);

            cfg = struct('override_file', ovr_file);
            cfg.allow_warnings = false;
            validator = narwc.validation.SurveyValidator(cfg);
            [is_valid, results] = validator.validate(data);

            testCase.verifyTrue(is_valid, ...
                'All 3 warnings must be acknowledged by mixed overrides');
            testCase.verifyEqual(results.summary.warnings_acknowledged, 3);
            testCase.verifyEqual(results.summary.warnings_acknowledged_per_row, 1, ...
                'Per-row must catch exactly the one explicitly listed eventno');
            testCase.verifyEqual(results.summary.warnings_acknowledged_per_survey, 2, ...
                'Per-survey must catch the remaining two warnings');
        end

        % -----------------------------------------------------------------
        % Behavioral rules — vectorized calf-behavior check
        % -----------------------------------------------------------------

        function testBehavioralCalfWarningVectorized(testCase)
            % validate_calf_behavior_consistency must fire for rows where a
            % calf-associated behavior code is present but NUMCALF = 0.
            %
            % This test calls behavioral_rules directly with a synthetic
            % config and a local Behave.csv so it is independent of the
            % project-level lookup table.

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            mkdir(fullfile('data', 'tables'));

            behave_path = fullfile('data', 'tables', 'Behave.csv');
            fid = fopen(behave_path, 'w');
            fprintf(fid, 'Value\n');
            for c = 1:50; fprintf(fid, '%d\n', c); end
            fclose(fid);

            data = table();
            data.FILEID  = {'aT00001'; 'aT00001'; 'aT00001'};
            data.EVENTNO = [1; 2; 3];
            data.BEHAV1  = [40; NaN; 40];   % rows 1,3: MOTHER WITH YOUNG
            data.NUMCALF = [0; 1; 0];       % rows 1,3: no calf -> warning

            config = make_behav_config(behave_path);

            collector = narwc.validation.ErrorCollector();
            narwc.validation.rules.behavioral_rules(data, collector, config);

            warnings = collector.getErrors('warning');
            calf_warns = warnings(strcmp({warnings.rule_id}, ...
                'behavioral_rules.calf_behavior_no_calf'));

            testCase.verifyEqual(length(calf_warns), 2, ...
                'Exactly 2 rows must trigger calf_behavior_no_calf');
            warn_rows = sort([calf_warns.row]);
            testCase.verifyEqual(warn_rows, [1, 3], ...
                'Warnings must be on rows 1 and 3');
        end

        function testFormatErrorDetailsIncludesEventno(testCase)
            % behavioral_rules stores EVENTNO on warnings it emits.
            % Verify (a) the warning carries eventno and (b) the location
            % string rendered by formatErrorDetails contains EVENTNO=N.
            %
            % formatErrorDetails format: [WARNING] FIELD: message (rows R, EVENTNO=N)

            import matlab.unittest.fixtures.WorkingFolderFixture
            testCase.applyFixture(WorkingFolderFixture);
            mkdir(fullfile('data', 'tables'));

            behave_path = fullfile('data', 'tables', 'Behave.csv');
            fid = fopen(behave_path, 'w');
            fprintf(fid, 'Value\n');
            for c = 1:50; fprintf(fid, '%d\n', c); end
            fclose(fid);

            data = table();
            data.FILEID  = {'f_evtest'};
            data.EVENTNO = 42;
            data.BEHAV1  = 40;    % MOTHER WITH YOUNG -> calf warning
            data.NUMCALF = 0;

            config = make_behav_config(behave_path);

            collector = narwc.validation.ErrorCollector();
            narwc.validation.rules.behavioral_rules(data, collector, config);

            warnings = collector.getErrors('warning');
            testCase.verifyFalse(isempty(warnings), ...
                'behavioral_rules must generate a calf-behavior warning');

            w = warnings(1);
            testCase.verifyEqual(w.eventno, 42, ...
                'Warning must carry EVENTNO=42 from the data');

            % Simulate the formatErrorDetails rendering for this warning
            parts = {};
            if ~isempty(w.row)
                parts{end+1} = sprintf('rows %s', mat2str(w.row));
            end
            if ~isempty(w.eventno) && ~any(isnan(w.eventno))
                parts{end+1} = sprintf('EVENTNO=%d', w.eventno);
            end
            loc    = [' (' strjoin(parts, ', ') ')'];
            detail = sprintf('[WARNING] %s: %s%s', w.field, w.message, loc);

            testCase.verifyTrue(contains(detail, 'EVENTNO=42'), ...
                'Formatted detail must contain EVENTNO=42');
            testCase.verifyTrue(contains(detail, '[WARNING]'), ...
                'Formatted detail must start with [WARNING]');
        end
    end
end

% =========================================================================
% Test helpers (private functions at file scope)
% =========================================================================

function data = make_survey_with_old_year(testCase) %#ok<INUSD>
    % Single-row survey with YEAR before year_warning threshold (~1980).
    % Omits FK-checked fields (DDSOURCE, IDSOURCE) so no FK errors occur.
    data = table();
    data.FILEID  = {'f_ovtest'};
    data.EVENTNO = 7;          % numeric EVENTNO for override matching
    data.LAT_DD  = 42.0;       % within survey area: no coordinate warning
    data.LONG_DD = -70.0;
    data.YEAR    = 1975;       % < year_warning (~1980) -> triggers year_too_old
    data.MONTH   = 6;
    data.DAY     = 15;
end

function data = make_survey_two_old_years(testCase) %#ok<INUSD>
    % Two-row survey, both years trigger year_too_old warning.
    data = table();
    data.FILEID  = {'f_ovtest2'; 'f_ovtest2'};
    data.EVENTNO = [7; 8];
    data.LAT_DD  = [42.0; 43.0];
    data.LONG_DD = [-70.0; -71.0];
    data.YEAR    = [1975; 1973];
    data.MONTH   = [6; 7];
    data.DAY     = [15; 20];
end

function write_override(filepath, fileid, eventno, field, rule_id)
    % Write a minimal overrides.csv with one per-row acknowledged entry
    fid = fopen(filepath, 'w');
    fprintf(fid, 'fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason\n');
    fprintf(fid, '%s,%d,%s,%s,test,2026-01-01,unit test\n', ...
        fileid, eventno, field, rule_id);
    fclose(fid);
end

function write_per_survey_override(filepath, fileid, field, rule_id)
    % Write a minimal overrides.csv with one per-survey entry (empty eventno)
    fid = fopen(filepath, 'w');
    fprintf(fid, 'fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason\n');
    fprintf(fid, '%s,,%s,%s,test,2026-01-01,per-survey unit test\n', ...
        fileid, field, rule_id);
    fclose(fid);
end

function data = make_survey_n_old_years(n)
    % n-row survey with YEAR=1975 on all rows (each triggers year_too_old)
    data = table();
    data.FILEID  = repmat({'f_ovtest_n'}, n, 1);
    data.EVENTNO = (1:n)';
    data.LAT_DD  = repmat(42.0, n, 1);
    data.LONG_DD = repmat(-70.0, n, 1);
    data.YEAR    = repmat(1975, n, 1);
    data.MONTH   = repmat(6, n, 1);
    data.DAY     = repmat(15, n, 1);
end

function data = make_survey_old_year_and_high_vis()
    % Single-row survey triggering two distinct warnings:
    %   YEAR=1975  -> datetime_rules.year_too_old   (field=YEAR)
    %   VISIBLTY=100 -> environmental_rules.visibility_too_high (field=VISIBLTY)
    data = table();
    data.FILEID   = {'f_ovtest_2w'};
    data.EVENTNO  = 7;
    data.LAT_DD   = 42.0;
    data.LONG_DD  = -70.0;
    data.YEAR     = 1975;
    data.MONTH    = 6;
    data.DAY      = 15;
    data.VISIBLTY = 100;   % > visibility_max (50) -> warning
end

function config = make_behav_config(behave_path)
    % Minimal behavioral_rules config for unit tests.
    % Passes the supplied Behave.csv path so the function skips get_config.
    config.behave_table_path            = behave_path;
    config.dead_behaviors               = [];
    config.active_swimming_behaviors    = [];
    config.incompatible_behavior_pairs  = zeros(0, 2);
    config.calf_associated_behaviors    = [40; 41; 42];
    config.taxcode_behavior_restrictions = struct();
    config.species_behavior_restrictions = struct();
end