classdef SurveyFileWriter < handle
    % SURVEYFILEWRITER Groups rows by FILEID and writes one CSV per survey.
    %
    % Extracted from SurveyExtractor so the FILEID-grouping/writing logic
    % can be shared between the legacy migration (chunked read of one huge
    % file) and routine contributor-batch ingestion (one parsed file at a
    % time). This class only writes into an existing output_dir; callers
    % own directory creation/overwrite policy.
    %
    % Usage:
    %   writer = narwc.ingestion.SurveyFileWriter(output_dir);
    %   writer.writeChunk(data_table);     % call once, or many times
    %   summary = writer.finalize('source description');

    properties (Access = private)
        output_dir
        logger
        survey_map   % containers.Map: sanitized FILEID -> row count
        total_rows   % all rows seen, including dropped-FILEID rows
        start_time
        run_ts
    end

    methods
        function obj = SurveyFileWriter(output_dir)
            obj.output_dir = output_dir;
            obj.logger = logging.Logger('narwc.ingestion.SurveyFileWriter');
            obj.survey_map = containers.Map('KeyType', 'char', 'ValueType', 'double');
            obj.total_rows = 0;
            obj.start_time = tic;
            obj.run_ts = narwc.logging.run_timestamp();
        end

        function writeChunk(obj, data_chunk)
            % WRITECHUNK Group data_chunk by FILEID; append/create per-survey CSVs.
            if ~istable(data_chunk)
                error('narwc:ingestion:SurveyFileWriter:InvalidInput', ...
                    'writeChunk requires a table input');
            end

            num_rows = height(data_chunk);
            obj.total_rows = obj.total_rows + num_rows;

            if num_rows == 0
                obj.logger.warning('Empty chunk passed to writeChunk');
                return;
            end

            unique_fileids = unique(data_chunk.FILEID);
            unique_fileids = unique_fileids(~ismissing(unique_fileids));
            unique_fileids = unique_fileids(strlength(unique_fileids) > 0);

            for idx = 1:length(unique_fileids)
                current_fileid = unique_fileids{idx};

                sanitized_fileid = narwc.utils.sanitize_filename(char(current_fileid));
                output_filepath = fullfile(obj.output_dir, [sanitized_fileid '.csv']);

                row_mask = strcmp(data_chunk.FILEID, current_fileid);
                survey_data = data_chunk(row_mask, :);

                try
                    if exist(output_filepath, 'file')
                        obj.logger.debug(sprintf('Appending to: %s', output_filepath));
                        writetable(survey_data, output_filepath, ...
                            'WriteMode', 'append', 'WriteVariableNames', false);
                    else
                        writetable(survey_data, output_filepath);
                        obj.logger.info(sprintf('Created: %s', sanitized_fileid));
                    end

                    survey_row_count = height(survey_data);
                    if isKey(obj.survey_map, sanitized_fileid)
                        obj.survey_map(sanitized_fileid) = obj.survey_map(sanitized_fileid) + survey_row_count;
                    else
                        obj.survey_map(sanitized_fileid) = survey_row_count;
                    end

                catch ME
                    obj.logger.error(sprintf('Failed to write %s: %s', ...
                        sanitized_fileid, ME.message));
                end
            end
        end

        function summary = finalize(obj, source_description)
            % FINALIZE Write the split-summary log inside output_dir.
            arguments
                obj
                source_description char = ''
            end

            summary_filepath = fullfile(obj.output_dir, ...
                sprintf('_split_summary_%s.log', obj.run_ts));
            fid = fopen(summary_filepath, 'w');

            total_time = toc(obj.start_time);
            num_surveys = length(obj.survey_map);

            fprintf(fid, 'CSV Split Summary\n');
            fprintf(fid, '=================\n\n');
            fprintf(fid, 'Date: %s\n', char(datetime('now')));
            if ~isempty(source_description)
                fprintf(fid, 'Input file: %s\n', source_description);
            end
            fprintf(fid, 'Output directory: %s\n\n', obj.output_dir);
            fprintf(fid, 'Total surveys: %d\n', num_surveys);
            fprintf(fid, 'Total rows: %d\n', obj.total_rows);
            if num_surveys > 0
                fprintf(fid, 'Average rows per survey: %d\n', ...
                    round(obj.total_rows / num_surveys));
            end
            fprintf(fid, 'Time elapsed: %.1f minutes\n', total_time / 60);
            fprintf(fid, '\nSurvey file row counts:\n');
            fprintf(fid, '-----------------------\n');

            survey_names = keys(obj.survey_map);
            survey_counts = cell2mat(values(obj.survey_map));
            [~, sort_idx] = sort(survey_names);

            for i = 1:length(survey_names)
                idx = sort_idx(i);
                fprintf(fid, '%s: %d rows\n', survey_names{idx}, survey_counts(idx));
            end

            fclose(fid);
            obj.logger.info(sprintf('Summary written to: %s', summary_filepath));

            summary = struct();
            summary.file = summary_filepath;
            summary.total_surveys = num_surveys;
            summary.total_rows = obj.total_rows;
            summary.elapsed_minutes = total_time / 60;
        end
    end
end
