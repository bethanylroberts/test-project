function summary = convert_contributor_batch(parser, input_files, output_dir)
    % CONVERT_CONTRIBUTOR_BATCH Parse contributor files and split by FILEID.
    %
    % Front end for routine ingestion: runs each input file through the
    % given parser (any object with a parse(file_path) method returning a
    % canonically-ordered table -- see narwc.io.parsers.BaseParser), then
    % feeds each result through a shared SurveyFileWriter into output_dir.
    % No chunking is needed here -- season files are small compared to the
    % legacy monolith SurveyExtractor handles.
    %
    % Usage:
    %   parser = narwc.io.parsers.ParserFactory.createByName('NEAQFormat');
    %   summary = narwc.ingestion.convert_contributor_batch(parser, ...
    %       {'season1.csv', 'season2.csv'}, 'data/raw/pending');

    arguments
        parser
        input_files cell
        output_dir char
    end

    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end

    writer = narwc.ingestion.SurveyFileWriter(output_dir);

    for i = 1:numel(input_files)
        file_path = input_files{i};
        [data, ~] = parser.parse(file_path);
        writer.writeChunk(data);
    end

    summary = writer.finalize(strjoin(input_files, '; '));
end
