function smoke_validate()
% SMOKE_VALIDATE Run validation pass over all CSV fixtures
%
% Prints a per-fixture summary table to stdout (errors, warnings,
% acknowledged counts, validity).  Does not upload.
%
% Usage:
%   startup()
%   smoke_validate()

startup();

logger = logging.Logger('narwc.scripts.smoke_validate');

fixture_dir = fullfile('tests', 'fixtures', 'sample_data');
csv_files   = dir(fullfile(fixture_dir, '*.csv'));

if isempty(csv_files)
    logger.warning('No CSV files found in %s', fixture_dir);
    return;
end

logger.info(sprintf('Smoke-validating %d CSV fixture(s) in %s', ...
    length(csv_files), fixture_dir));

% ── Header ─────────────────────────────────────────────────────────────────
COL_W  = [24, 6, 7, 6, 9, 9, 8];
SEP_LEN = sum(COL_W) + 7 * 2 + 8;
sep = repmat('-', 1, SEP_LEN);

fprintf('\n%s\n', sep);
fprintf('%-*s  %*s  %*s  %*s  %*s  %*s  %*s  time\n', ...
    COL_W(1), 'FIXTURE', ...
    COL_W(2), 'ROWS', ...
    COL_W(3), 'ERRORS', ...
    COL_W(4), 'WARN', ...
    COL_W(5), 'ACK_ROW', ...
    COL_W(6), 'ACK_SURV', ...
    COL_W(7), 'VALID');
fprintf('%s\n', sep);

% ── Per-fixture pass ────────────────────────────────────────────────────────
tot_rows  = 0;
tot_err   = 0;
tot_warn  = 0;
tot_ack_r = 0;
tot_ack_s = 0;
n_valid   = 0;
n_files   = length(csv_files);

for k = 1:n_files
    fname = csv_files(k).name;
    fpath = fullfile(fixture_dir, fname);
    [~, stem, ~] = fileparts(fname);

    try
        t0   = tic();
        data = readtable(fpath, 'Delimiter', ',', 'VariableNamingRule', 'preserve');

        validator       = narwc.validation.SurveyValidator();
        [is_valid, res] = validator.validate(data);
        elapsed         = toc(t0);

        n_rows = height(data);
        n_err  = res.summary.errors;
        n_warn = res.summary.warnings_new;
        n_ar   = res.summary.warnings_acknowledged_per_row;
        n_as   = res.summary.warnings_acknowledged_per_survey;

        valid_str = 'yes';
        if ~is_valid
            valid_str = 'NO';
        end

        fprintf('%-*s  %*d  %*d  %*d  %*d  %*d  %*s  %.2fs\n', ...
            COL_W(1), stem, ...
            COL_W(2), n_rows, ...
            COL_W(3), n_err, ...
            COL_W(4), n_warn, ...
            COL_W(5), n_ar, ...
            COL_W(6), n_as, ...
            COL_W(7), valid_str, ...
            elapsed);

        tot_rows  = tot_rows  + n_rows;
        tot_err   = tot_err   + n_err;
        tot_warn  = tot_warn  + n_warn;
        tot_ack_r = tot_ack_r + n_ar;
        tot_ack_s = tot_ack_s + n_as;
        if is_valid
            n_valid = n_valid + 1;
        end

    catch ME
        logger.warning('Failed to validate %s: %s', fname, ME.message);
        fprintf('%-*s  *** FAILED: %s\n', COL_W(1), stem, ME.message);
    end
end

% ── Totals ──────────────────────────────────────────────────────────────────
fprintf('%s\n', sep);
fprintf('%-*s  %*d  %*d  %*d  %*d  %*d  %d/%d valid\n', ...
    COL_W(1), 'TOTALS', ...
    COL_W(2), tot_rows, ...
    COL_W(3), tot_err, ...
    COL_W(4), tot_warn, ...
    COL_W(5), tot_ack_r, ...
    COL_W(6), tot_ack_s, ...
    n_valid, n_files);
fprintf('%s\n\n', sep);

logger.info(sprintf( ...
    'Smoke validation complete: %d files, %d errors, %d warnings, %d/%d valid', ...
    n_files, tot_err, tot_warn, n_valid, n_files));
end
