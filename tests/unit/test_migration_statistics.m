classdef test_migration_statistics < matlab.unittest.TestCase
    % TEST_MIGRATION_STATISTICS Unit tests for the migration-statistics
    % helpers used by step3_validate_migration.m:
    %   narwc.ingestion.load_split_summary
    %   narwc.ingestion.tally_validation_by_rule
    %   narwc.ingestion.flatten_tally_map / merge_flat_counts
    %
    % tally_validation_by_rule re-runs SurveyValidator on real, deterministic
    % single-row survey tables (built from TestFixtures.generate_mock_survey
    % with the specific field under test overridden) rather than parsing log
    % files -- this is the same approach used in production.

    properties
        work_dir
    end

    methods (TestMethodSetup)
        function setupDir(testCase)
            testCase.work_dir = tempname;
            mkdir(testCase.work_dir);
        end
    end

    methods (TestMethodTeardown)
        function cleanupDir(testCase)
            if exist(testCase.work_dir, 'dir')
                rmdir(testCase.work_dir, 's');
            end
        end
    end

    methods (Test)

        %% load_split_summary

        function testLoadSplitSummaryParsesTotalsAndCounts(testCase)
            log_path = fullfile(testCase.work_dir, '_split_summary_20260101_000000.log');
            fid = fopen(log_path, 'w');
            fprintf(fid, 'CSV Split Summary\n=================\n\n');
            fprintf(fid, 'Total surveys: 2\n');
            fprintf(fid, 'Total rows: 30\n');
            fprintf(fid, 'Time elapsed: 1.5 minutes\n');
            fprintf(fid, '\nSurvey file row counts:\n-----------------------\n');
            fprintf(fid, 'A001: 10 rows\n');
            fprintf(fid, 'B002: 20 rows\n');
            fclose(fid);

            [source, summary_file] = narwc.ingestion.load_split_summary(testCase.work_dir);

            testCase.verifyEqual(source.total_surveys, 2);
            testCase.verifyEqual(source.total_rows, 30);
            testCase.verifyEqual(source.counts('A001'), 10);
            testCase.verifyEqual(source.counts('B002'), 20);
            testCase.verifyEqual(summary_file, log_path);
        end

        function testLoadSplitSummaryPicksMostRecentFile(testCase)
            old_path = fullfile(testCase.work_dir, '_split_summary_20260101_000000.log');
            new_path = fullfile(testCase.work_dir, '_split_summary_20260102_000000.log');

            write_minimal_summary(old_path, 1, 5);
            pause(0.05);  % ensure a distinct, later datenum on the second file
            write_minimal_summary(new_path, 9, 99);

            [source, summary_file] = narwc.ingestion.load_split_summary(testCase.work_dir);

            testCase.verifyEqual(summary_file, new_path);
            testCase.verifyEqual(source.total_surveys, 9);
            testCase.verifyEqual(source.total_rows, 99);
        end

        function testLoadSplitSummaryErrorsWhenMissing(testCase)
            testCase.verifyError( ...
                @() narwc.ingestion.load_split_summary(testCase.work_dir), ...
                'narwc:ingestion:load_split_summary:NoSplitSummary');
        end

        %% tally_validation_by_rule

        function testErrorLandsInErrorsByRule(testCase)
            data = build_survey('TEST001', 'SPECCODE', 'RIWHX');  % 5 chars -> speccode_too_long
            csv_path = write_survey_csv(testCase.work_dir, 'TEST001.csv', data);

            tally = narwc.ingestion.tally_validation_by_rule({csv_path}, minimal_batch_config());

            testCase.verifyTrue(isKey(tally.errors_by_rule, 'species_rules_speccode_too_long'));
            e = tally.errors_by_rule('species_rules_speccode_too_long');
            testCase.verifyEqual(e.count, 1);
            testCase.verifyEqual(e.fileids, {'TEST001'});
            testCase.verifyEqual(tally.surveys_with_errors, 1);
            testCase.verifyEmpty(tally.would_now_pass);
        end

        function testOutstandingWarningLandsInWarningsOutstanding(testCase)
            data = build_survey('TEST002', 'YEAR', 1975);  % < year_warning (1980) -> year_too_old
            csv_path = write_survey_csv(testCase.work_dir, 'TEST002.csv', data);

            tally = narwc.ingestion.tally_validation_by_rule({csv_path}, minimal_batch_config());

            testCase.verifyTrue(isKey(tally.warnings_outstanding_by_rule, 'datetime_rules_year_too_old'));
            testCase.verifyFalse(isKey(tally.warnings_acknowledged_by_rule, 'datetime_rules_year_too_old'));
            testCase.verifyEqual(tally.surveys_with_warnings, 1);
            testCase.verifyEqual(tally.surveys_with_errors, 0);
        end

        function testAcknowledgedWarningLandsInWarningsAcknowledgedNotOutstanding(testCase)
            data = build_survey('TEST003', 'YEAR', 1975);
            csv_path = write_survey_csv(testCase.work_dir, 'TEST003.csv', data);

            override_path = fullfile(testCase.work_dir, 'overrides.csv');
            fid = fopen(override_path, 'w');
            fprintf(fid, 'fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason\n');
            fprintf(fid, 'TEST003,1,YEAR,datetime_rules.year_too_old,test,2026-01-01,unit test\n');
            fclose(fid);

            batch_config = minimal_batch_config();
            batch_config.validation.overrides.csv_path = override_path;

            tally = narwc.ingestion.tally_validation_by_rule({csv_path}, batch_config);

            testCase.verifyTrue(isKey(tally.warnings_acknowledged_by_rule, 'datetime_rules_year_too_old'));
            testCase.verifyFalse(isKey(tally.warnings_outstanding_by_rule, 'datetime_rules_year_too_old'));
            testCase.verifyEqual(tally.surveys_with_warnings, 0, ...
                'An acknowledged warning is not a "new" warning');
        end

        function testCleanSurveyCountsAsWouldNowPass(testCase)
            data = build_survey('TEST004');  % no field overridden -> clean
            csv_path = write_survey_csv(testCase.work_dir, 'TEST004.csv', data);

            tally = narwc.ingestion.tally_validation_by_rule({csv_path}, minimal_batch_config());

            testCase.verifyEqual(tally.would_now_pass, {'TEST004'});
            testCase.verifyEqual(tally.surveys_with_errors, 0);
            testCase.verifyEqual(tally.surveys_with_warnings, 0);
        end

        function testSurveysAnalyzedCountsAllFiles(testCase)
            csv1 = write_survey_csv(testCase.work_dir, 'TEST005.csv', build_survey('TEST005'));
            csv2 = write_survey_csv(testCase.work_dir, 'TEST006.csv', ...
                build_survey('TEST006', 'SPECCODE', 'RIWHX'));

            tally = narwc.ingestion.tally_validation_by_rule({csv1, csv2}, minimal_batch_config());

            testCase.verifyEqual(tally.surveys_analyzed, 2);
        end

        %% flatten_tally_map / merge_flat_counts

        function testFlattenTallyMapCountsDistinctSurveys(testCase)
            m = containers.Map('KeyType', 'char', 'ValueType', 'any');
            e = struct('rule_id', 'x.y', 'count', 3, 'fileids', {{'A', 'A', 'B'}});
            m('x_y') = e;

            [flat, detail] = narwc.ingestion.flatten_tally_map(m);

            testCase.verifyEqual(flat.x_y, 3);
            testCase.verifyEqual(detail.x_y.survey_count, 2, ...
                'Duplicate fileids for the same rule must be deduplicated');
            testCase.verifyEqual(detail.x_y.rule_id, 'x.y');
        end

        function testMergeFlatCountsAddsOverlappingKeys(testCase)
            a = struct('rule_a', 2, 'rule_b', 1);
            b = struct('rule_b', 3, 'rule_c', 5);

            merged = narwc.ingestion.merge_flat_counts(a, b);

            testCase.verifyEqual(merged.rule_a, 2);
            testCase.verifyEqual(merged.rule_b, 4);
            testCase.verifyEqual(merged.rule_c, 5);
        end

    end
end

%% Local helpers (file-private; not part of the class)

function write_minimal_summary(path, n_surveys, n_rows)
    fid = fopen(path, 'w');
    fprintf(fid, 'Total surveys: %d\nTotal rows: %d\n', n_surveys, n_rows);
    fclose(fid);
end

function data = build_survey(fileid, field, value)
    % BUILD_SURVEY One deterministic, otherwise-clean survey row, with an
    % optional single field overridden to deliberately trigger a rule.
    data = TestFixtures.generate_mock_survey(1);
    data.FILEID = {fileid};
    data.EVENTNO = 1;
    data.NUMBER = 2;
    data.NUMCALF = 0;
    for i = 1:15
        data.(sprintf('BEHAV%d', i)) = NaN;
    end

    if nargin >= 2
        data.(field) = value;
    end
end

function csv_path = write_survey_csv(dir_path, filename, data)
    csv_path = fullfile(dir_path, filename);
    writetable(data, csv_path);
end

function batch_config = minimal_batch_config()
    % MINIMAL_BATCH_CONFIG Only the species/datetime/required-field/coordinate/
    % environmental rule families are exercised by these tests -- those use
    % fixed numeric thresholds only. Disable the lookup-table-dependent
    % families (foreign keys, platform, beaufort, behavioral) so "clean
    % survey" assertions don't depend on the current contents of
    % data/tables/*.csv.
    batch_config = struct();
    batch_config.pipeline.known_fixes.enabled = false;
    batch_config.validation = struct();
    batch_config.validation.overrides.csv_path = '';
    batch_config.validation.validate_foreign_keys = false;
    batch_config.validation.validate_platform     = false;
    batch_config.validation.validate_beaufort     = false;
    batch_config.validation.validate_behavioral   = false;
end
