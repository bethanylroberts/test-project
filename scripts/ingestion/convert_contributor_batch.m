% CONVERT_CONTRIBUTOR_BATCH converts one contributor's raw survey files
%
% Front-end "convert" stage for routine ingestion, analogous to
% scripts/migration/step1_extract_surveys.m. Reads all .csv files from a
% contributor's raw-dropoff subfolder (data/raw/incoming/<contributor>/ by
% default), runs each through that contributor's parser -- selected
% explicitly by name, no auto-detection, see
% narwc.io.parsers.ParserFactory -- and writes one standard-format CSV per
% survey into data/raw/pending/, ready for upload_contributor_batch.

function summary = convert_contributor_batch(contributor, parser_name, options)
    % CONVERT_CONTRIBUTOR_BATCH Convert one contributor's batch into pending/
    %
    % Usage:
    %   convert_contributor_batch('neaq', 'NEAQFormat')
    %   convert_contributor_batch('neaq', 'NEAQFormat', 'InputDir', 'data/raw/incoming/neaq')

    arguments
        contributor char
        parser_name char
        options.InputDir char = ''
        options.OutputDir char = fullfile('data', 'raw', 'pending')
    end

    if isempty(options.InputDir)
        input_dir = fullfile('data', 'raw', 'incoming', contributor);
    else
        input_dir = options.InputDir;
    end

    fprintf('=== Converting %s Contributor Batch ===\n\n', contributor);
    fprintf('Parser: %s\n', parser_name);
    fprintf('Input:  %s\n', input_dir);
    fprintf('Output: %s\n\n', options.OutputDir);

    listing = dir(fullfile(input_dir, '*.csv'));
    if isempty(listing)
        error('convert_contributor_batch:NoInputFiles', ...
            'No .csv files found in %s', input_dir);
    end
    input_files = fullfile({listing.folder}, {listing.name});

    parser = narwc.io.parsers.ParserFactory.createByName(parser_name);
    summary = narwc.ingestion.convert_contributor_batch(parser, input_files, options.OutputDir);

    fprintf('\nConversion complete. %d surveys, %d rows.\n', ...
        summary.total_surveys, summary.total_rows);
    fprintf('Ready for: upload_contributor_batch(''Config'', load_config(''routine''))\n\n');
end
