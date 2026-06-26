# Pipeline Walkthrough

## Purpose

Operational step-through of the NARWC-DB validation pipeline for curators and developers.
Covers loading a survey CSV, running validation, inspecting warnings, writing overrides
(per-row and per-survey), and confirming the override took effect. This is the canonical
path for a personal pipeline shakedown before onboarding team members. See
`docs/warning_overrides.md` for conceptual background on the override system.

---

## Prerequisites

- MATLAB R2020b or later
- Database Toolbox installed (not required for validation-only steps; required for DB write)
- `data/tables/` populated with lookup CSVs (shipped in the repo)
- `data/overrides.csv` present (header-only is fine; `startup` creates it if absent)
- `startup.m` has been run in the current MATLAB session

---

## Quick Start

```matlab
startup();
parser = narwc.io.parsers.StandardFormat();
[data, ~] = parser.parse('tests/fixtures/sample_data/aT11110.csv');
validator = narwc.validation.SurveyValidator();
[is_valid, results] = validator.validate(data);
disp(results.summary)
```

Expect: `is_valid` is `true` or `false`; `results.summary` shows error/warning counts.

---

## Step-by-Step Walkthrough

### Step 1 — Setup

```matlab
startup();
```

**What to observe:** No error output. `get_config` and `logging.Logger` should be on
the path. If you see `Undefined function 'get_config'`, re-run `startup` from the
repo root.

---

### Step 2 — Load a Survey CSV

```matlab
file_path = 'tests/fixtures/sample_data/aT11110.csv';
parser = narwc.io.parsers.StandardFormat();
[data, metadata] = parser.parse(file_path);
fprintf('Loaded %d rows, %d columns\n', height(data), width(data));
disp(metadata)
```

**What to observe:** `data` is a MATLAB table with 55 named columns in database order.
`metadata.format` is `'Standard NARWC Format'`. `metadata.row_count` matches the
file's row count.

---

### Step 3 — Validate the Loaded Survey

```matlab
validator = narwc.validation.SurveyValidator();
[is_valid, results] = validator.validate(data);
disp(results.summary)
```

**What to observe:** `results.summary` prints error/warning counts. `is_valid` is
`false` if any unacknowledged warnings or errors exist (default config blocks on
warnings). `results.error_details` is a cell array of formatted strings for quick
reading.

Print all detail lines:

```matlab
for i = 1:length(results.error_details)
    disp(results.error_details{i})
end
```

---

### Step 4 — Inspect Individual Warnings

`results.warnings` is a **struct array**. Each element has: `field`, `row`,
`eventno`, `rule_id`, `message`, `severity`.

```matlab
% How many warnings?
n = length(results.warnings);
fprintf('%d warning(s)\n', n);

% Inspect the first warning
w = results.warnings(1);
fprintf('Field:   %s\n', w.field);
fprintf('EVENTNO: %d\n', w.eventno);
fprintf('Rule:    %s\n', w.rule_id);
fprintf('Message: %s\n', w.message);
```

**What to observe:** `w.eventno` is the integer EVENTNO you need to write a per-row
override. `w.rule_id` is the stable rule identifier (e.g.,
`behavioral_rules.behav_without_sighting`). Both values go directly into
`data/overrides.csv`.

To list all warnings in a readable format:

```matlab
for i = 1:length(results.warnings)
    w = results.warnings(i);
    fprintf('[%d] EVENTNO=%-6s field=%-12s rule=%s\n', ...
        i, num2str(w.eventno), w.field, w.rule_id);
end
```

---

### Step 5 — Write a Per-Row Override and Re-Validate

A per-row override suppresses a specific warning for a specific EVENTNO in a specific
survey. Fill in the values from Step 4.

Open `data/overrides.csv` in a text editor and append one line:

```
aT11110,<EVENTNO>,<field>,<rule_id>,rss,2026-06-26,walkthrough test override
```

Replace `<EVENTNO>`, `<field>`, and `<rule_id>` with the values from Step 4.

Then re-validate (a new validator instance is needed to reload the overrides file):

```matlab
validator2 = narwc.validation.SurveyValidator();
[is_valid2, results2] = validator2.validate(data);
fprintf('Warnings after per-row override: %d new, %d acknowledged\n', ...
    results2.summary.warnings_new, results2.summary.warnings_acknowledged_per_row);
```

**What to observe:** `results2.summary.warnings_acknowledged_per_row` increments by 1.
The overridden warning moves from `results2.warnings` to `results2.info`. If
`warnings_new` drops to 0 and `errors` is 0, `is_valid2` becomes `true`.

---

### Step 6 — Write a Per-Survey Override and Re-Validate

A per-survey override suppresses all warnings of a given `(field, rule_id)` combination
for a survey, regardless of EVENTNO. Leave the `eventno` column empty.

Append to `data/overrides.csv`:

```
aT11110,,<field>,<rule_id>,rss,2026-06-26,per-survey walkthrough test
```

Re-validate:

```matlab
validator3 = narwc.validation.SurveyValidator();
[is_valid3, results3] = validator3.validate(data);
fprintf('Per-survey acknowledged: %d\n', results3.summary.warnings_acknowledged_per_survey);
```

**What to observe:** `results3.summary.warnings_acknowledged_per_survey` reflects how
many warnings were silenced by the per-survey rule. See `docs/warning_overrides.md`
for override precedence.

---

### Step 7 — Run Validation on the High-Volume Fixture

```matlab
file_vol = 'tests/fixtures/sample_data/aT99001_volume.csv';
parser_vol = narwc.io.parsers.StandardFormat();
[data_vol, meta_vol] = parser_vol.parse(file_vol);
fprintf('Volume fixture: %d rows\n', meta_vol.row_count);

validator_vol = narwc.validation.SurveyValidator();
[is_valid_vol, results_vol] = validator_vol.validate(data_vol);
disp(results_vol.summary)
```

**What to observe:** Validation completes without timeout. `results_vol.summary`
shows the aggregate counts across all rows. This fixture is used to catch
performance regressions; a reasonable run should complete in a few seconds.

---

### Step 8 — Run the Smoke Test Driver

`smoke_validate` runs validation over every survey fixture in
`tests/fixtures/sample_data/` and prints a summary table.

```matlab
startup();    % if not already done
smoke_validate()
```

**What to observe:** A table is printed with one row per fixture file showing ROWS,
ERRORS, WARN, ACK_ROW, ACK_SURV, VALID, and elapsed time. TOTALS row at the bottom.
Any fixture in the FAILED state indicates a parser or validator crash — investigate
that fixture before proceeding.

---

### Step 9 — Cleanup

Remove the walkthrough override entries added in Steps 5 and 6. Open
`data/overrides.csv` and delete the lines containing `walkthrough test override`
and `per-survey walkthrough test`. Alternatively, reset to header-only:

```matlab
% Reset overrides.csv to header only (removes ALL override entries)
header = ['# NARWC Warning Override Store\n' ...
    '# fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason\n' ...
    '#\n' ...
    'fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason\n'];
fid = fopen('data/overrides.csv', 'w');
fprintf(fid, header);
fclose(fid);
```

**What to observe:** A fresh `narwc.validation.SurveyValidator()` will load 0
overrides. The log line `Loaded N override(s)` will not appear.

---

## Common Operations

**How do I find the EVENTNO for a warning I want to acknowledge?**

```matlab
for i = 1:length(results.warnings)
    w = results.warnings(i);
    fprintf('EVENTNO=%-6s  field=%-12s  rule=%s\n', num2str(w.eventno), w.field, w.rule_id);
end
```

**How do I check whether my override took effect?**

```matlab
validator = narwc.validation.SurveyValidator();
[~, results] = validator.validate(data);
fprintf('Per-row acknowledged: %d\n', results.summary.warnings_acknowledged_per_row);
fprintf('Per-survey acknowledged: %d\n', results.summary.warnings_acknowledged_per_survey);
% Acknowledged warnings appear in results.info, not results.warnings
```

**How do I see what warnings appeared in the most recent run?**

```matlab
for i = 1:length(results.error_details)
    disp(results.error_details{i})
end
% Or inspect the raw struct array:
% disp(results.warnings)
```

**How do I remove an override I added by mistake?**

Open `data/overrides.csv` in a text editor and delete the relevant line.
Alternatively, view current overrides:

```matlab
t = readtable('data/overrides.csv', 'CommentStyle', '#', 'Delimiter', ',', ...
    'TextType', 'char', 'VariableNamingRule', 'preserve');
disp(t)
```

Then delete the row by line number in the file.

**How do I reset `data/overrides.csv` to header-only?**

```matlab
fid = fopen('data/overrides.csv', 'w');
fprintf(fid, '# NARWC Warning Override Store\n');
fprintf(fid, '# fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason\n');
fprintf(fid, '#\n');
fprintf(fid, 'fileid,eventno,field,rule_id,acknowledged_by,acknowledged_date,reason\n');
fclose(fid);
```

---

## Troubleshooting

*(Populate this section during your personal pipeline shakedown.)*

---

## Next Steps

- Read `docs/warning_overrides.md` for the full override semantics (per-row vs.
  per-survey, precedence, the `acknowledged_by` / `reason` fields).
- Review `handoffs/smoke_test_findings.md` for known fixture-specific issues and
  expected warning counts.
- For validation rule details, see `docs/validation_rules_guide.md`.
