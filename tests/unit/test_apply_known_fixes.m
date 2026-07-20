classdef test_apply_known_fixes < matlab.unittest.TestCase
    % TEST_APPLY_KNOWN_FIXES Unit tests for migration.apply_known_fixes.
    %
    % Covers all 8 Category C fixes with positive and negative cases.
    % No database access required — all tests use synthetic tables.
    %
    % Run via:
    %   runtests('tests/unit/test_apply_known_fixes.m')

    methods (Test)

        % ── Fix 1: PHOTOS = 0 → 1 (sighting rows only) ───────────────────

        function testPhotos0To1_sightingRow(testCase)
            % PHOTOS=0 on a sighting row (non-empty SPECCODE) → changed to 1
            data = make_table('PHOTOS', 0, 'SPECCODE', {'RIWH'});
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyEqual(out.PHOTOS(1), 1, ...
                'PHOTOS=0 on sighting row should become 1');
            testCase.verifyEqual(report.photos_0_to_1, 1);
        end

        function testPhotos0To1_effortRow(testCase)
            % PHOTOS=0 on an effort-only row (empty SPECCODE) → unchanged
            data = make_table('PHOTOS', 0, 'SPECCODE', {''});
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyEqual(out.PHOTOS(1), 0, ...
                'PHOTOS=0 on effort row should not change');
            testCase.verifyEqual(report.photos_0_to_1, 0);
        end

        function testPhotos0To1_alreadyValid(testCase)
            % PHOTOS=2 on a sighting row → unchanged
            data = make_table('PHOTOS', 2, 'SPECCODE', {'RIWH'});
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyEqual(out.PHOTOS(1), 2, ...
                'Valid PHOTOS value should not be changed');
            testCase.verifyEqual(report.photos_0_to_1, 0);
        end

        % ── Fix 2: STRIP > 16 → NaN (NEAq 2021 surveys only) ────────────

        function testStrip_neaq2021_aboveRange(testCase)
            % STRIP=20 with matching FILEID → becomes NaN
            data = make_table('STRIP', 20);
            [out, report] = migration.apply_known_fixes(data, 'a121001');
            testCase.verifyTrue(isnan(out.STRIP(1)), ...
                'STRIP > 16 in NEAq 2021 survey should become NaN');
            testCase.verifyEqual(report.strip_neaq_2021, 1);
        end

        function testStrip_neaq2021_inRange(testCase)
            % STRIP=8 with matching FILEID → unchanged (within valid range)
            data = make_table('STRIP', 8);
            [out, report] = migration.apply_known_fixes(data, 'a121001');
            testCase.verifyEqual(out.STRIP(1), 8, ...
                'STRIP <= 16 should not be changed even in NEAq 2021 survey');
            testCase.verifyEqual(report.strip_neaq_2021, 0);
        end

        function testStrip_wrongFileid(testCase)
            % STRIP=20 but FILEID does not match 'a121*' → unchanged
            data = make_table('STRIP', 20);
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyEqual(out.STRIP(1), 20, ...
                'STRIP > 16 fix should only apply to a121* surveys');
            testCase.verifyEqual(report.strip_neaq_2021, 0);
        end

        % ── Fix 3: BEAUFORT = 99 → NaN ───────────────────────────────────

        function testBeaufort99_sentinel(testCase)
            data = make_table('BEAUFORT', 99);
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyTrue(isnan(out.BEAUFORT(1)), ...
                'BEAUFORT=99 should become NaN');
            testCase.verifyEqual(report.beaufort_99, 1);
        end

        function testBeaufort99_validValue(testCase)
            data = make_table('BEAUFORT', 3);
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyEqual(out.BEAUFORT(1), 3, ...
                'Valid BEAUFORT value should not change');
            testCase.verifyEqual(report.beaufort_99, 0);
        end

        % ── Fix 4: CLOUD = 99 → NaN ──────────────────────────────────────

        function testCloud99_sentinel(testCase)
            data = make_table('CLOUD', 99);
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyTrue(isnan(out.CLOUD(1)), ...
                'CLOUD=99 should become NaN');
            testCase.verifyEqual(report.cloud_99, 1);
        end

        function testCloud99_validValue(testCase)
            data = make_table('CLOUD', 4);
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyEqual(out.CLOUD(1), 4, ...
                'Valid CLOUD value should not change');
            testCase.verifyEqual(report.cloud_99, 0);
        end

        % ── Fix 5: GLAREL / GLARER = 99 → NaN ───────────────────────────

        function testGlarel99_sentinel(testCase)
            data = make_table('GLAREL', 99);
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyTrue(isnan(out.GLAREL(1)), ...
                'GLAREL=99 should become NaN');
            testCase.verifyEqual(report.glarel_99, 1);
        end

        function testGlarel99_validValue(testCase)
            data = make_table('GLAREL', 2);
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyEqual(out.GLAREL(1), 2, ...
                'Valid GLAREL value should not change');
            testCase.verifyEqual(report.glarel_99, 0);
        end

        function testGlarer99_sentinel(testCase)
            data = make_table('GLARER', 99);
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyTrue(isnan(out.GLARER(1)), ...
                'GLARER=99 should become NaN');
            testCase.verifyEqual(report.glarer_99, 1);
        end

        function testGlarer99_validValue(testCase)
            data = make_table('GLARER', 1);
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyEqual(out.GLARER(1), 1, ...
                'Valid GLARER value should not change');
            testCase.verifyEqual(report.glarer_99, 0);
        end

        % ── Fix 6: NUMCALF = 99 → NaN ────────────────────────────────────

        function testNumcalf99_sentinel(testCase)
            data = make_table('NUMCALF', 99);
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyTrue(isnan(out.NUMCALF(1)), ...
                'NUMCALF=99 should become NaN');
            testCase.verifyEqual(report.numcalf_99, 1);
        end

        function testNumcalf99_validValue(testCase)
            data = make_table('NUMCALF', 2);
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyEqual(out.NUMCALF(1), 2, ...
                'Valid NUMCALF value should not change');
            testCase.verifyEqual(report.numcalf_99, 0);
        end

        % ── Fix 7: SPECCODE trailing whitespace trim ──────────────────────

        function testSpeccodeTrailingWhitespace(testCase)
            data = make_table('SPECCODE', {'RIWH '});
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyEqual(out.SPECCODE{1}, 'RIWH', ...
                'Trailing whitespace in SPECCODE should be trimmed');
            testCase.verifyEqual(report.speccode_trim, 1);
        end

        function testSpeccodeNoWhitespace(testCase)
            data = make_table('SPECCODE', {'RIWH'});
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyEqual(out.SPECCODE{1}, 'RIWH', ...
                'SPECCODE without whitespace should not change');
            testCase.verifyEqual(report.speccode_trim, 0);
        end

        % ── Fix 8: LEGTYPE = 99 → NaN ────────────────────────────────────

        function testLegtype99_sentinel(testCase)
            data = make_table('LEGTYPE', 99);
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyTrue(isnan(out.LEGTYPE(1)), ...
                'LEGTYPE=99 should become NaN');
            testCase.verifyEqual(report.legtype_99, 1);
        end

        function testLegtype99_validValue(testCase)
            data = make_table('LEGTYPE', 1);
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyEqual(out.LEGTYPE(1), 1, ...
                'Valid LEGTYPE value should not change');
            testCase.verifyEqual(report.legtype_99, 0);
        end

        % ── Cross-fix: report always has all fields ───────────────────────

        function testReportAlwaysHasAllFields(testCase)
            % Even on an empty table, all 9 report fields must be present with value 0
            data = table();
            [~, report] = migration.apply_known_fixes(data, 'f001001');
            expected_fields = {'photos_0_to_1', 'strip_neaq_2021', 'beaufort_99', ...
                'cloud_99', 'glarel_99', 'glarer_99', 'numcalf_99', ...
                'speccode_trim', 'legtype_99'};
            for i = 1:numel(expected_fields)
                testCase.verifyTrue(isfield(report, expected_fields{i}), ...
                    sprintf('report must have field: %s', expected_fields{i}));
                testCase.verifyEqual(report.(expected_fields{i}), 0, ...
                    sprintf('%s should be 0 when no rows match', expected_fields{i}));
            end
        end

        function testMissingColumnsAreNoOp(testCase)
            % Function must not error when fix-target columns are absent
            data = table((1:3)', 'VariableNames', {'EVENTNO'});
            testCase.verifyWarningFree( ...
                @() migration.apply_known_fixes(data, 'f001001'), ...
                'apply_known_fixes should not warn when columns are absent');
        end

        function testMultipleRowsMultipleFixes(testCase)
            % Verify correct counts when multiple rows and fixes fire together
            data = table( ...
                [99; 3; 99; 5], ...
                [99; 2; 0;  1], ...
                'VariableNames', {'BEAUFORT', 'CLOUD'});
            [out, report] = migration.apply_known_fixes(data, 'f001001');
            testCase.verifyEqual(report.beaufort_99, 2, ...
                'Two BEAUFORT=99 rows should be fixed');
            testCase.verifyEqual(report.cloud_99, 1, ...
                'One CLOUD=99 row should be fixed');
            testCase.verifyTrue(isnan(out.BEAUFORT(1)));
            testCase.verifyEqual(out.BEAUFORT(2), 3);
            testCase.verifyTrue(isnan(out.BEAUFORT(3)));
            testCase.verifyTrue(isnan(out.CLOUD(1)));
            testCase.verifyEqual(out.CLOUD(4), 1);
        end

    end

end


% =========================================================================
% Helpers
% =========================================================================

function data = make_table(varargin)
% Build a single-row survey table with the given column name/value pairs.
% Accepts alternating 'ColumnName', value pairs.
%
% Usage:
%   make_table('BEAUFORT', 99)
%   make_table('PHOTOS', 0, 'SPECCODE', {'RIWH'})
    if mod(numel(varargin), 2) ~= 0
        error('make_table requires name/value pairs');
    end
    data = table();
    for i = 1:2:numel(varargin)
        col_name = varargin{i};
        value    = varargin{i+1};
        if isnumeric(value)
            data.(col_name) = value;
        elseif iscell(value)
            data.(col_name) = value;
        else
            data.(col_name) = value;
        end
    end
end
