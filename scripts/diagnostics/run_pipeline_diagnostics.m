function results = run_pipeline_diagnostics(options)
    % RUN_PIPELINE_DIAGNOSTICS Read-only end-to-end check of the 5 new
    % contributor parsers, the DDSOURCE/IDSOURCE/PLATFORM injection
    % mechanism, and the sighting/non-sighting required_fields.m axis.
    %
    % GUARANTEE: this script never writes to the database. No code path
    % here calls BatchUploader.uploadFromFolder/uploadSurvey or any other
    % write method -- the "would this be an insert or an overwrite" check
    % is a direct read-only SELECT COUNT(*) query (the same one
    % BatchUploader.surveyExists uses internally), not a real upload
    % wrapped in a rolled-back transaction. Nothing you run here can change
    % what's in Master.
    %
    % For each of CCSAerialFormat/CCSVesselFormat/CCSOpportunisticFormat/
    % NEAQVesselFormat/NEAQAerialFormat, this:
    %   1. Resolves a real input file under data/surveys/raw/<contributor>/
    %      if one exists, else falls back to the matching
    %      tests/fixtures/sample_data/*_sample.csv fixture.
    %   2. Converts it via convert_contributor_batch into a scratch
    %      directory (never the real data/surveys/pending/).
    %   3. Validates the result with SurveyValidator (local, no DB).
    %   4. If a live DB connection is available, checks (read-only) whether
    %      each resulting FILEID already exists in Master, and reports
    %      whether upload_contributor_batch(..., 'Overwrite', true|false)
    %      would insert or overwrite it.
    %
    % Usage:
    %   results = run_pipeline_diagnostics();
    %
    % Next steps NOT performed by this script (deliberately manual/opt-in):
    %   - To actually upload for real:
    %       upload_contributor_batch('BatchId', <id>, 'Overwrite', true|false)
    %   - To clean up anything inserted while testing:
    %       scripts/sql/curation/delete_survey.sql

    arguments
        options.OutputDir char = ''
    end

    if isempty(options.OutputDir)
        scratch_dir = fullfile(tempname, 'pipeline_diagnostics_pending');
    else
        scratch_dir = options.OutputDir;
    end

    project_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));  % scripts/diagnostics/.. -> repo root
    fixtures_dir = fullfile(project_root, 'tests', 'fixtures', 'sample_data');
    raw_dir = fullfile(project_root, 'data', 'surveys', 'raw');

    parsers = {
        'CCS',                   'CCSAerialFormat',        'Aerial',        '^CCS\d+\.csv$',  fullfile(fixtures_dir, 'ccs_aerial_sample.csv');
        'CCS',                   'CCSVesselFormat',        'Vessel',        '^SW\d+\.csv$',   fullfile(fixtures_dir, 'ccs_vessel_2023_sample.csv');
        'CCS',                   'CCSOpportunisticFormat', 'Opportunistic', '',                fullfile(fixtures_dir, 'ccs_opportunistic_2023_sample.csv');
        'NEAQ & CWI (vessels)',  'NEAQVesselFormat',       '',              '',                fullfile(fixtures_dir, 'neaq_vessel_sample.csv');
        'NEAQ Aerial',           'NEAQAerialFormat',       '',              '_URI\.csv$',      fullfile(fixtures_dir, 'neaq_aerial_sample.csv');
    };

    fprintf('=== NARWC Pipeline Diagnostics (read-only -- no database writes) ===\n\n');

    %% Preflight: DB connectivity (read-only probe)
    fprintf('--- Preflight: database connectivity ---\n');
    conn = [];
    db_available = false;
    try
        conn = narwc.db.Connection.create();
        conn.fetch('SELECT 1');
        db_available = true;
        fprintf('  [OK] Connected. DB-dependent checks (existence lookup) will run.\n\n');
    catch ME
        fprintf('  [SKIP] No live database connection (%s).\n', ME.message);
        fprintf('         Continuing with local-only checks (conversion + validation).\n\n');
        if ~isempty(conn)
            try
                conn.close();
            catch
                % already unusable -- nothing more to do
            end
            conn = [];
        end
    end

    %% Per-parser conversion + validation + (optional) existence check
    rows = struct('contributor', {}, 'parser_name', {}, 'input_file', {}, ...
        'used_fixture', {}, 'convert_ok', {}, 'row_count', {}, 'fileids', {}, ...
        'validation_errors', {}, 'validation_warnings', {}, 'db_status', {}, 'notes', {});

    for i = 1:size(parsers, 1)
        contributor    = parsers{i, 1};
        parser_name    = parsers{i, 2};
        platform_kw    = parsers{i, 3};
        filename_regex = parsers{i, 4};
        fixture_path   = parsers{i, 5};

        fprintf('--- %s ---\n', parser_name);

        [input_file, used_fixture] = resolve_input_file(raw_dir, contributor, ...
            platform_kw, filename_regex, fixture_path);

        row = struct('contributor', contributor, 'parser_name', parser_name, ...
            'input_file', input_file, 'used_fixture', used_fixture, ...
            'convert_ok', false, 'row_count', 0, 'fileids', {{}}, ...
            'validation_errors', 0, 'validation_warnings', 0, ...
            'db_status', 'n/a', 'notes', '');

        if used_fixture
            fprintf('  Using fixture (no real raw file found): %s\n', input_file);
        else
            fprintf('  Using real raw file: %s\n', input_file);
        end

        out_dir = fullfile(scratch_dir, parser_name);
        if ~exist(out_dir, 'dir')
            mkdir(out_dir);
        end

        try
            parser = narwc.io.parsers.ParserFactory.createByName(parser_name);
            % Resolve the same DDSOURCE/IDSOURCE/PLATFORM defaults the real
            % pipeline would (scripts/ingestion/convert_contributor_batch.m
            % does this per-file too) so this diagnostic actually exercises
            % the injection mechanism, not just the raw parser.
            overrides = narwc.ingestion.lookup_contributor_defaults(contributor, input_file);
            summary = narwc.ingestion.convert_contributor_batch(parser, {input_file}, out_dir, overrides);
            row.convert_ok = true;
            row.row_count = summary.total_rows;
            fprintf('  [OK] Converted: %d survey(s), %d row(s)\n', summary.total_surveys, summary.total_rows);
        catch ME
            row.notes = sprintf('convert failed: %s', ME.message);
            fprintf('  [FAIL] Conversion error: %s\n', ME.message);
            rows(end + 1) = row; %#ok<AGROW>
            fprintf('\n');
            continue;
        end

        survey_files = dir(fullfile(out_dir, '*.csv'));
        fileids = {survey_files.name};
        fileids = erase(fileids, '.csv');
        row.fileids = fileids;

        for j = 1:numel(survey_files)
            survey_path = fullfile(survey_files(j).folder, survey_files(j).name);
            data = readtable(survey_path);

            try
                validator = narwc.validation.SurveyValidator();
                [~, val_results] = validator.validate(data);
                row.validation_errors = row.validation_errors + val_results.summary.errors;
                row.validation_warnings = row.validation_warnings + ...
                    val_results.summary.warnings_new + val_results.summary.warnings_acknowledged;
            catch ME
                fprintf('  [WARN] Validation could not run for %s: %s\n', fileids{j}, ME.message);
            end

            ddsource = field_preview(data, 'DDSOURCE');
            platform = field_preview(data, 'PLATFORM');
            fprintf('  %-20s DDSOURCE=%-6s PLATFORM=%-6s\n', fileids{j}, ddsource, platform);
        end

        fprintf('  Validation: %d error(s), %d warning(s) across %d survey(s)\n', ...
            row.validation_errors, row.validation_warnings, numel(survey_files));

        if db_available
            statuses = strings(1, numel(fileids));
            for j = 1:numel(fileids)
                statuses(j) = check_existence(conn, fileids{j});
                fprintf('  %-20s -> %s\n', fileids{j}, statuses(j));
            end
            if any(statuses == "OVERWRITE")
                row.db_status = 'some already in Master (would OVERWRITE)';
            elseif ~isempty(statuses)
                row.db_status = 'all new (would INSERT)';
            end
        end

        rows(end + 1) = row; %#ok<AGROW>
        fprintf('\n');
    end

    if db_available
        conn.close();
    end

    %% Summary
    fprintf('=== Summary ===\n');
    fprintf('%-14s %-24s %6s %6s %8s %8s  %s\n', ...
        'Contributor', 'Parser', 'Rows', 'Errs', 'Warns', 'Source', 'DB status');
    for i = 1:numel(rows)
        r = rows(i);
        source_label = 'fixture';
        if ~r.used_fixture
            source_label = 'real';
        end
        fprintf('%-14s %-24s %6d %6d %8d %8s  %s\n', ...
            r.contributor, r.parser_name, r.row_count, r.validation_errors, ...
            r.validation_warnings, source_label, r.db_status);
    end

    fprintf('\nScratch conversion output left at: %s\n', scratch_dir);
    fprintf(['No database writes were performed. To actually upload, run\n' ...
        '  upload_contributor_batch(''BatchId'', <id>, ''Overwrite'', true|false)\n' ...
        'and to clean up test uploads afterward, see scripts/sql/curation/delete_survey.sql.\n']);

    results = rows;
end

function [input_file, used_fixture] = resolve_input_file(raw_dir, contributor, platform_kw, filename_regex, fixture_path)
    % RESOLVE_INPUT_FILE Prefer a real raw file for this contributor
    % (optionally narrowed to a platform-type subfolder and/or filename
    % pattern), falling back to the fixture if none is found.
    contributor_dir = fullfile(raw_dir, contributor);
    input_file = fixture_path;
    used_fixture = true;

    if ~exist(contributor_dir, 'dir')
        return;
    end

    listing = dir(fullfile(contributor_dir, '**', '*.csv'));
    if isempty(listing)
        return;
    end

    candidates = fullfile({listing.folder}, {listing.name});

    if ~isempty(platform_kw)
        candidates = candidates(contains(candidates, platform_kw, 'IgnoreCase', true));
    end

    % Exclude known non-survey sidecar files (data/README.md's CCS quirks).
    candidates = candidates(~contains(candidates, 'map', 'IgnoreCase', true));
    candidates = candidates(~contains(candidates, '985K', 'IgnoreCase', true));

    if isempty(candidates)
        return;
    end

    if ~isempty(filename_regex)
        [~, names, exts] = cellfun(@fileparts, candidates, 'UniformOutput', false);
        basenames = strcat(names, exts);
        matches = ~cellfun(@isempty, regexp(basenames, filename_regex, 'once'));
        if any(matches)
            candidates = candidates(matches);
        end
    end

    input_file = candidates{1};
    used_fixture = false;
end

function status = check_existence(conn, fileid)
    % CHECK_EXISTENCE Read-only mirror of BatchUploader.surveyExists --
    % never writes, just reports what an upload would do.
    try
        query = sprintf("SELECT COUNT(*) as cnt FROM Master WHERE FILEID = '%s'", fileid);
        result = conn.fetch(query);
        if result.cnt(1) > 0
            status = "OVERWRITE";
        else
            status = "INSERT (new)";
        end
    catch ME
        status = "UNKNOWN (" + string(ME.message) + ")";
    end
end

function val = field_preview(data, field_name)
    if ~ismember(field_name, data.Properties.VariableNames)
        val = '<missing>';
        return;
    end
    column = data.(field_name);
    if isempty(column)
        val = '<empty>';
        return;
    end
    if iscell(column)
        val = column{1};
    elseif isstring(column)
        val = char(column(1));
    else
        val = num2str(column(1));
    end
    if isempty(val) || (ischar(val) && all(isspace(val)))
        val = '<blank>';
    end
end
