function summary = convert_contributor_batch(parser, input_files, output_dir, file_overrides)
    % CONVERT_CONTRIBUTOR_BATCH Parse contributor files and split by FILEID.
    %
    % Front end for routine ingestion: runs each input file through the
    % given parser (any object with a parse(file_path) method returning a
    % canonically-ordered table -- see narwc.io.parsers.BaseParser), then
    % feeds each result through a shared SurveyFileWriter into output_dir.
    % No chunking is needed here -- season files are small compared to the
    % legacy monolith SurveyExtractor handles.
    %
    % file_overrides applies narwc.ingestion.apply_field_overrides to each
    % file's parsed table before writing (e.g. curator-assigned DDSOURCE/
    % IDSOURCE/PLATFORM -- see contributor_defaults.csv / the script-layer
    % 'FieldOverrides' option). Pass either a single struct (applied to
    % every file) or a containers.Map keyed by exact entries of
    % input_files, for cases needing per-file resolution (e.g. one
    % ambiguous file excluded from an otherwise-uniform subfolder default --
    % see lookup_contributor_defaults). Files absent from the map get no
    % overrides.
    %
    % Usage:
    %   parser = narwc.io.parsers.ParserFactory.createByName('CCSAerialFormat');
    %   summary = narwc.ingestion.convert_contributor_batch(parser, ...
    %       {'season1.csv', 'season2.csv'}, 'data/surveys/pending');

    arguments
        parser
        input_files cell
        output_dir char
        file_overrides = struct()
    end

    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    writer = narwc.ingestion.SurveyFileWriter(output_dir);

    for i = 1:numel(input_files)
        file_path = input_files{i};
        [data, ~] = parser.parse(file_path);

        if isa(file_overrides, 'containers.Map')
            if isKey(file_overrides, file_path)
                overrides = file_overrides(file_path);
            else
                overrides = struct();
            end
        else
            overrides = file_overrides;
        end

        data = narwc.ingestion.apply_field_overrides(data, overrides);
        writer.writeChunk(data);
    end

    summary = writer.finalize(strjoin(input_files, '; '));
end
