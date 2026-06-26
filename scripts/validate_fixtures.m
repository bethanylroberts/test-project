function validate_fixtures()
% validate_fixtures Run validation pass over all survey CSV fixtures
%
% Runs SurveyValidator on every survey-pattern CSV in tests/fixtures/sample_data/
% and prints a summary table.  Log output from the validator appears before the
% table (collect-then-print pattern keeps the two streams separated).
%
% Prerequisites:
%   Run startup() before calling this function.
%
% Usage:
%   startup()
%   validate_fixtures()


if isempty(which('get_config'))
    error('validate_fixtures:NotInitialized', ...
        'Run startup() before calling validate_fixtures()');
end

reload_config();

logger = logging.Logger('narwc.scripts.validate_fixtures');

fixture_dir = fullfile('tests', 'fixtures', 'sample_data');
all_csv     = dir(fullfile(fixture_dir, '*.csv'));

keep = false(1, length(all_csv));
for k = 1:length(all_csv)
    stem = all_csv(k).name(1:end-4);
    if ~isempty(regexp(stem, '^[a-zA-Z]T\d{5}', 'once'))
        keep(k) = true;
    else
        logger.info(sprintf('Skipping non-survey fixture: %s', all_csv(k).name));
    end
end
survey_csv = all_csv(keep);

if isempty(survey_csv)
    logger.warning(sprintf('No survey CSV files found in %s', fixture_dir));
    return;
end

n_files = length(survey_csv);
logger.info(sprintf('Smoke-validating %d survey CSV fixture(s) in %s', ...
    n_files, fixture_dir));

% Warm up config cache and JIT before the timed loop
try
    warmup_data          = table();
    warmup_data.LAT_DD   = 42.0;
    warmup_data.LONG_DD  = -70.0;
    warmup_data.YEAR     = 2020;
    warmup_data.MONTH    = 6;
    warmup_data.DAY      = 15;
    warmup_data.FILEID   = {'_warmup'};
    warmup_data.EVENTNO  = 1;
    narwc.validation.SurveyValidator().validate(warmup_data);
catch
end

% ── Collect results (log lines appear here, before the table) ────────────────
stems        = cell(n_files, 1);
rows_arr     = zeros(n_files, 1);
err_arr      = zeros(n_files, 1);
warn_arr     = zeros(n_files, 1);
ack_row_arr  = zeros(n_files, 1);
ack_surv_arr = zeros(n_files, 1);
valid_arr    = false(n_files, 1);
elapsed_arr  = zeros(n_files, 1);
failed       = false(n_files, 1);
fail_msgs    = cell(n_files, 1);

for k = 1:n_files
    fname         = survey_csv(k).name;
    fpath         = fullfile(fixture_dir, fname);
    [~, stems{k}] = fileparts(fname);

    t0 = tic();
    try
        data            = readtable(fpath, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
        validator       = narwc.validation.SurveyValidator();
        [is_valid, res] = validator.validate(data);
        elapsed_arr(k)  = toc(t0);

        rows_arr(k)     = height(data);
        err_arr(k)      = res.summary.errors;
        warn_arr(k)     = res.summary.warnings_new;
        ack_row_arr(k)  = res.summary.warnings_acknowledged_per_row;
        ack_surv_arr(k) = res.summary.warnings_acknowledged_per_survey;
        valid_arr(k)    = is_valid;
    catch ME
        elapsed_arr(k) = toc(t0);
        failed(k)      = true;
        fail_msgs{k}   = ME.message;
        logger.warning(sprintf('Failed to validate %s: %s', fname, ME.message));
    end
end

% ── Print table (no log output below this line) ──────────────────────────────
COL_W   = [24, 6, 7, 6, 9, 9, 8];
SEP_LEN = sum(COL_W) + 7 * 2 + 8;
sep     = repmat('-', 1, SEP_LEN);

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

for k = 1:n_files
    if failed(k)
        fprintf('%-*s  *** FAILED: %s\n', COL_W(1), stems{k}, fail_msgs{k});
    else
        valid_str = 'yes';
        if ~valid_arr(k), valid_str = 'NO'; end
        fprintf('%-*s  %*d  %*d  %*d  %*d  %*d  %*s  %.2fs\n', ...
            COL_W(1), stems{k}, ...
            COL_W(2), rows_arr(k), ...
            COL_W(3), err_arr(k), ...
            COL_W(4), warn_arr(k), ...
            COL_W(5), ack_row_arr(k), ...
            COL_W(6), ack_surv_arr(k), ...
            COL_W(7), valid_str, ...
            elapsed_arr(k));
    end
end

n_valid   = sum(valid_arr);
tot_rows  = sum(rows_arr);
tot_err   = sum(err_arr);
tot_warn  = sum(warn_arr);
tot_ack_r = sum(ack_row_arr);
tot_ack_s = sum(ack_surv_arr);

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
