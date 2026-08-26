% CONVERT_CONTRIBUTOR_BATCH converts one contributor's raw survey files
%
% Front-end "convert" stage shared by every source, including the one-time
% legacy migration -- the legacy monolith is just another contributor
% ('legacy') that happens to need chunked reading because of its size.
%
% Reads raw file(s) from a contributor's raw-dropoff subfolder
% (data/surveys/raw/<contributor>/ by default), runs them through that
% contributor's parser -- selected explicitly by name, no auto-detection,
% see narwc.io.parsers.ParserFactory -- and writes one standard-format CSV
% per survey into data/surveys/pending/, ready for upload_contributor_batch.
%
% contributor == 'legacy' dispatches to the chunked narwc.ingestion.SurveyExtractor
% (needed because the legacy monolith is far larger than a season's worth of
% contributor files); every other contributor dispatches to the single-pass
% narwc.ingestion.convert_contributor_batch core function.
%
% Every run gets a batch_id (returned as summary.batch_id) and is recorded
% as a 'convert' row in the batch ledger (data/surveys/batch_log.csv, see
% narwc.ingestion.append_batch_log) -- the human-readable record of what's
% been converted, and what upload_contributor_batch/validate_batch look up
% to scope themselves to one batch. If this exact input was already
% converted before, a warning is printed (not a hard stop -- re-conversion
% is sometimes intentional, e.g. after fixing a parser bug).

function summary = convert_contributor_batch(contributor, parser_name, options)
    % CONVERT_CONTRIBUTOR_BATCH Convert one contributor's batch into pending/
    %
    % Usage:
    %   convert_contributor_batch('CCS', 'CCSAerialFormat', 'InputDir', 'data/surveys/raw/CCS/2023 Aerial')
    %   convert_contributor_batch('legacy', 'StandardFormat')
    %   convert_contributor_batch('legacy', 'StandardFormat', 'ChunkSize', 5000, 'Overwrite', true)
    %   convert_contributor_batch('legacy', 'StandardFormat', 'InputFile', 'data/surveys/RUSS_24_VALID.CSV')
    %
    % DDSOURCE/IDSOURCE/PLATFORM: curator-assigned fields never present in
    % contributor raw files (see the NARWC manual and data/README.md).
    % Resolved per input file by default from
    % data/tables/contributor_defaults.csv (contributor + this file's path
    % matched against that table's path_pattern column -- see
    % narwc.ingestion.lookup_contributor_defaults); pass 'FieldOverrides' to
    % override or supplement the table for this call, or
    % 'UseContributorDefaults', false to ignore the table entirely.

    arguments
        contributor char
        parser_name char
        options.InputDir char = ''
        options.InputFile char = ''
        options.OutputDir char = fullfile('data', 'surveys', 'pending')
        options.ChunkSize double = 10000
        options.Overwrite logical = false
        options.FieldOverrides struct = struct()
        options.UseContributorDefaults logical = true
    end

    if isempty(options.InputDir)
        input_dir = fullfile('data', 'surveys', 'raw', contributor);
    else
        input_dir = options.InputDir;
    end

    batch_id = sprintf('%s_%s', narwc.logging.run_timestamp(), contributor);

    fprintf('=== Converting %s Batch ===\n\n', contributor);
    fprintf('Batch ID: %s\n', batch_id);
    fprintf('Parser: %s\n', parser_name);
    fprintf('Input:  %s\n', input_dir);
    fprintf('Output: %s\n\n', options.OutputDir);

    if strcmpi(contributor, 'legacy')
        % Legacy monolith: a single (large) CSV, read in chunks. Use
        % 'InputFile' to name it explicitly (e.g. the cleaned RUSS_24_VALID.CSV
        % produced by validate_csv_database_lines.m) rather than relying on
        % auto-discovery, which errors if raw/legacy/ ever holds more than
        % one .csv (it should normally hold only the untouched original).
        if ~isempty(options.InputFile)
            csv_file = options.InputFile;
        else
            listing = dir(fullfile(input_dir, '*.CSV'));
            listing = [listing; dir(fullfile(input_dir, '*.csv'))];
            if isempty(listing)
                error('convert_contributor_batch:NoInputFiles', ...
                    'No .csv files found in %s', input_dir);
            elseif numel(listing) > 1
                error('convert_contributor_batch:AmbiguousLegacyFile', ...
                    ['Multiple .csv files found in %s -- the legacy source must be a ' ...
                     'single file. Pass ''InputFile'' naming the intended source CSV.'], input_dir);
            end
            csv_file = fullfile(listing(1).folder, listing(1).name);
        end
        batch_input = csv_file;
    else
        listing = dir(fullfile(input_dir, '*.csv'));
        if isempty(listing)
            error('convert_contributor_batch:NoInputFiles', ...
                'No .csv files found in %s', input_dir);
        end
        input_files = fullfile({listing.folder}, {listing.name});
        batch_input = input_dir;
    end

    prior = narwc.ingestion.check_prior_conversion(batch_input);
    if height(prior) > 0
        last = prior(end, :);
        fprintf(['WARNING: this input was already converted in batch ''%s'' ' ...
            '(%s, %s surveys, %s rows). Proceeding anyway -- re-conversion may\n' ...
            'duplicate rows in already-existing pending/ files unless Overwrite is set.\n\n'], ...
            ledger_field_str(last, 'batch_id'), ledger_field_str(last, 'timestamp'), ...
            ledger_field_str(last, 'total_surveys'), ledger_field_str(last, 'total_rows'));
    end

    if strcmpi(contributor, 'legacy')
        extractor = narwc.ingestion.SurveyExtractor(csv_file, options.ChunkSize);
        summary = extractor.extractAll(options.OutputDir, 'Overwrite', options.Overwrite);
    else
        parser = narwc.io.parsers.ParserFactory.createByName(parser_name);

        file_overrides = containers.Map('KeyType', 'char', 'ValueType', 'any');
        for i = 1:numel(input_files)
            file_path = input_files{i};
            if options.UseContributorDefaults
                resolved = narwc.ingestion.lookup_contributor_defaults(contributor, file_path);
            else
                resolved = struct();
            end
            explicit_fields = fieldnames(options.FieldOverrides);
            for j = 1:numel(explicit_fields)
                resolved.(explicit_fields{j}) = options.FieldOverrides.(explicit_fields{j});
            end
            file_overrides(file_path) = resolved;
        end

        summary = narwc.ingestion.convert_contributor_batch(parser, input_files, options.OutputDir, file_overrides);
    end
    summary.batch_id = batch_id;

    narwc.ingestion.append_batch_log(struct( ...
        'batch_id', batch_id, 'stage', 'convert', 'source', contributor, ...
        'input', batch_input, 'output', summary.file, ...
        'total_surveys', summary.total_surveys, 'total_rows', summary.total_rows));

    if strcmpi(contributor, 'legacy')
        config_profile = 'migration';
    else
        config_profile = 'routine';
    end
    fprintf('\nConversion complete. %d surveys, %d rows.\n', ...
        summary.total_surveys, summary.total_rows);
    fprintf('Ready for: upload_contributor_batch(''Config'', load_config(''%s''), ''BatchId'', ''%s'')\n\n', ...
        config_profile, batch_id);
end

function s = ledger_field_str(row, colname)
    % LEDGER_FIELD_STR Extract one field of a batch-ledger table row as a
    % string, regardless of whether readtable inferred that column as text
    % (cell) or numeric (double).
    val = row.(colname);
    if iscell(val)
        val = val{1};
    else
        val = val(1);
    end
    s = string(val);
end
