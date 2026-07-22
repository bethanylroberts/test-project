function tally = tally_validation_by_rule(csv_files, batch_config)
    % TALLY_VALIDATION_BY_RULE Re-run apply_known_fixes + SurveyValidator on
    % each survey CSV (read-only; no database writes) and tally errors and
    % warnings by rule_id. This gives a structured, rule_id-level breakdown
    % straight from ErrorCollector via SurveyValidator.validate() -- the same
    % objects BatchUploader.uploadSurvey uses internally, just without the
    % upload half -- instead of scraping free-text _errors.log files.
    %
    % Used by scripts/migration/step3_validate_migration.m to report which
    % rules are actually blocking (or already acknowledged) across the
    % surveys currently sitting in failed/ and pending/.
    %
    % A survey that re-validates clean today (tally.would_now_pass) means
    % config/overrides/lookup tables changed since it last ran -- it just
    % needs re-running, not further investigation.
    %
    % Inputs:
    %   csv_files    - cell array of full paths to survey CSV files
    %   batch_config - struct from load_config(), providing .validation and
    %                  .pipeline.known_fixes.enabled
    %
    % Outputs:
    %   tally - struct with fields:
    %     errors_by_rule                - containers.Map, rule_key -> struct(rule_id, count, fileids)
    %     warnings_outstanding_by_rule   - same shape, unacknowledged warnings
    %     warnings_acknowledged_by_rule  - same shape, already-acknowledged warnings
    %     would_now_pass                 - cell array of fileids with zero errors/warnings today
    %     detailed_errors                - cell array of formatted sample lines (capped at 20)
    %     surveys_analyzed, surveys_with_errors, surveys_with_warnings - counts

    tally = struct();
    tally.errors_by_rule                = containers.Map('KeyType', 'char', 'ValueType', 'any');
    tally.warnings_outstanding_by_rule  = containers.Map('KeyType', 'char', 'ValueType', 'any');
    tally.warnings_acknowledged_by_rule = containers.Map('KeyType', 'char', 'ValueType', 'any');
    tally.would_now_pass       = {};
    tally.detailed_errors      = {};
    tally.surveys_analyzed     = 0;
    tally.surveys_with_errors  = 0;
    tally.surveys_with_warnings = 0;

    apply_fixes = true;
    if isfield(batch_config, 'pipeline') && isfield(batch_config.pipeline, 'known_fixes') && ...
            isfield(batch_config.pipeline.known_fixes, 'enabled')
        apply_fixes = batch_config.pipeline.known_fixes.enabled;
    end

    validator_config = struct();
    if isfield(batch_config, 'validation')
        validator_config = batch_config.validation;
    end
    if isfield(validator_config, 'overrides') && isfield(validator_config.overrides, 'csv_path')
        validator_config.override_file = validator_config.overrides.csv_path;
    end

    for i = 1:length(csv_files)
        file_path = csv_files{i};
        try
            survey_data = readtable(file_path);
        catch
            continue;   % unreadable file -- not a validation-rule issue, skip
        end

        if ~ismember('FILEID', survey_data.Properties.VariableNames) || height(survey_data) == 0
            continue;
        end
        fileid_col = survey_data.FILEID;
        if iscell(fileid_col)
            fileid = fileid_col{1};
        else
            fileid = char(fileid_col(1));
        end

        if apply_fixes
            try
                survey_data = migration.apply_known_fixes(survey_data, fileid);
            catch
                % leave data unmodified if the fix step itself errors
            end
        end

        validator = narwc.validation.SurveyValidator(validator_config);
        [~, val_results] = validator.validate(survey_data);
        tally.surveys_analyzed = tally.surveys_analyzed + 1;

        if val_results.summary.errors > 0
            tally.surveys_with_errors = tally.surveys_with_errors + 1;
        end
        if val_results.summary.warnings_new > 0
            tally.surveys_with_warnings = tally.surveys_with_warnings + 1;
        end
        if val_results.summary.errors == 0 && val_results.summary.warnings_new == 0
            tally.would_now_pass{end+1} = fileid; %#ok<AGROW>
        end

        tally.errors_by_rule = accumulate_rule_entries( ...
            tally.errors_by_rule, val_results.errors, fileid);
        tally.warnings_outstanding_by_rule = accumulate_rule_entries( ...
            tally.warnings_outstanding_by_rule, val_results.warnings, fileid);
        tally.warnings_acknowledged_by_rule = accumulate_ack_entries( ...
            tally.warnings_acknowledged_by_rule, val_results.summary.acknowledgement_by_rule, fileid);

        if numel(tally.detailed_errors) < 20
            for d = 1:numel(val_results.error_details)
                if numel(tally.detailed_errors) >= 20
                    break;
                end
                tally.detailed_errors{end+1} = sprintf('%s: %s', fileid, val_results.error_details{d}); %#ok<AGROW>
            end
        end
    end
end

function m = accumulate_rule_entries(m, entries, fileid)
    % ACCUMULATE_RULE_ENTRIES Fold ErrorCollector-style entries (each with a
    % .rule_id field) into a containers.Map keyed by sanitized rule_id.
    for i = 1:numel(entries)
        rule_id = entries(i).rule_id;
        if isempty(rule_id)
            rule_id = 'unknown.no_rule_id';
        end
        key = strrep(rule_id, '.', '_');
        if isKey(m, key)
            e = m(key);
            e.count = e.count + 1;
            e.fileids{end+1} = fileid;
        else
            e = struct();
            e.rule_id = rule_id;
            e.count = 1;
            e.fileids = {fileid};
        end
        m(key) = e;
    end
end

function m = accumulate_ack_entries(m, by_rule, fileid)
    % ACCUMULATE_ACK_ENTRIES Fold SurveyValidator's acknowledgement_by_rule
    % (already rule_id-keyed, {rule_id, per_row, per_survey}) into the same
    % containers.Map shape as accumulate_rule_entries.
    if isempty(by_rule) || isempty(fieldnames(by_rule))
        return;
    end
    keys_list = fieldnames(by_rule);
    for i = 1:numel(keys_list)
        key = keys_list{i};
        entry = by_rule.(key);
        n = entry.per_row + entry.per_survey;
        if n == 0
            continue;
        end
        if isKey(m, key)
            e = m(key);
            e.count = e.count + n;
            e.fileids{end+1} = fileid;
        else
            e = struct();
            e.rule_id = entry.rule_id;
            e.count = n;
            e.fileids = {fileid};
        end
        m(key) = e;
    end
end
