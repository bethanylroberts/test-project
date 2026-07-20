classdef SurveyExtractor < handle
    % SURVEYEXTRACTOR Extract individual surveys from legacy CSV
    % Handles large files using chunked reading
    %
    % Usage:
    %   extractor = narwc.ingestion.SurveyExtractor('legacy_data.csv');
    %   extractor.extractAll('output_dir');
    %
    % 2026 russ.shomberg@marineacoustics.com
    
    properties (Access = private)
        legacy_file
        logger
        chunk_size = 10000  % Rows per chunk
    end
    
    methods
        function obj = SurveyExtractor(legacy_file, chunk_size)
            % SURVEYEXTRACTOR Constructor
            
            obj.legacy_file = legacy_file;
            obj.logger = logging.Logger('narwc.ingestion.SurveyExtractor');
            
            if nargin > 1
                obj.chunk_size = chunk_size;
            end
            
            if ~exist(legacy_file, 'file')
                error('Legacy file not found: %s', legacy_file);
            end
        end
        
        function extractAll(obj, output_dir, options)
            % EXTRACTALL Extract all surveys to separate files (chunked)
            %
            % Inputs:
            %   output_dir - Directory to save individual survey files
            %   options - Name-value pairs:
            %       'Overwrite' - Overwrite existing output directory (default: false)
            
            arguments
                obj
                output_dir char = 'data/legacy/extracted_surveys'
                options.Overwrite logical = false
            end
            
            % Check if output directory exists
            if exist(output_dir, 'dir')
                if ~options.Overwrite
                    error('Output directory already exists: %s\nUse ''Overwrite'', true to overwrite', output_dir);
                else
                    obj.logger.warning(sprintf('Overwriting existing directory: %s', output_dir));
                end
            else
                mkdir(output_dir);
                obj.logger.info(sprintf('Created output directory: %s', output_dir));
            end
            
            % Start timing
            start_time = tic;

            % Create import options
            import_opts = obj.createImportOptions();

            % Count total lines
            obj.logger.info('Counting total lines in file...');
            line_count = obj.countLines();
            obj.logger.info(sprintf('Total lines in file: %d', line_count));

            % Process in chunks
            chunk_counter = 0;
            rows_processed = 0;
            writer = narwc.ingestion.SurveyFileWriter(output_dir);

            % TODO: skipping header should be an option
            current_chunk_start = 2;  % Skip header
            
            while current_chunk_start <= line_count
                chunk_counter = chunk_counter + 1;
                current_chunk_end = min(current_chunk_start + obj.chunk_size - 1, line_count);
                
                % Update import options for this chunk
                import_opts.DataLines = [current_chunk_start, current_chunk_end];
                
                obj.logger.info(sprintf('Processing chunk %d (rows %d to %d)', ...  % FIXME: remove sprintf if not needed
                    chunk_counter, current_chunk_start, current_chunk_end));
                
                try
                    data_chunk = readtable(obj.legacy_file, import_opts);
                    
                    if ~istable(data_chunk)
                        obj.logger.error('Chunk read returned non-table type');
                        current_chunk_start = current_chunk_end + 1;
                        continue;
                    end
                    
                catch ME
                    % FIXME: need to deal with an unread chunk. Can't just skip
                    obj.logger.error(sprintf('Failed to read chunk: %s', ME.message));  % FIXME: remove sprintf if not needed
                    current_chunk_start = current_chunk_end + 1;
                    continue;
                end
                
                % Get number of rows
                num_rows = height(data_chunk);  % FIXME: should equal obj.chunk_size
                rows_processed = rows_processed + num_rows;
                
                if num_rows == 0
                    % NOTE: this should never happen?
                    obj.logger.warning('Empty chunk, moving to next');
                    current_chunk_start = current_chunk_end + 1;
                    continue;
                end
                
                % Group by FILEID and write/append per-survey CSVs
                writer.writeChunk(data_chunk);

                % Progress update
                elapsed = toc(start_time);
                completion_pct = (rows_processed / line_count) * 100;
                obj.logger.info(sprintf('  Progress: %d/%d rows (%.1f percent) - %.1f minutes elapsed', ...
                    rows_processed, line_count, completion_pct, elapsed/60));
                
                % Move to next chunk
                current_chunk_start = current_chunk_end + 1;
                
                % Clear data to free memory
                clear data_chunk survey_data;   % ???: is this necessary?
            end
            
            % Write summary
            summary = writer.finalize(obj.legacy_file);

            % Display summary
            obj.logger.info('======================================');
            obj.logger.info('Split operation completed successfully');
            obj.logger.info(sprintf('Total surveys: %d', summary.total_surveys));
            obj.logger.info(sprintf('Total rows processed: %d', summary.total_rows));
            obj.logger.info(sprintf('Time elapsed: %.1f minutes', summary.elapsed_minutes));
            if summary.total_surveys > 0
                obj.logger.info(sprintf('Average rows per survey: %d', ...
                    round(summary.total_rows / summary.total_surveys)));
            end
            obj.logger.info(sprintf('Output directory: %s', output_dir));
            obj.logger.info('======================================');
        end
        
        function line_count = countLines(obj)
            % COUNTLINES Count total lines in file
            % TODO: make this a generic function. Use it in the validate csv lines script as well
            fid = fopen(obj.legacy_file, 'r');
            line_count = 0;
            while ~feof(fid)
                fgetl(fid);
                line_count = line_count + 1;
            end
            fclose(fid);
        end
        
        function import_opts = createImportOptions(obj)
            % CREATEIMPORTOPTIONS Create import options for legacy CSV
            
            % Use the static method from LegacyFormat parser
            import_opts = narwc.io.parsers.StandardFormat.createImportOptions();
            % TODO: currently using the standard format for the legacy format,
            % but this should be separated in case of future changes to the standard format.
        end

    end
end