classdef SurveyExtractor < handle
    % SURVEYEXTRACTOR Extract individual surveys from legacy CSV
    % Handles large files using chunked reading
    %
    % Usage:
    %   extractor = migration.SurveyExtractor('legacy_data.csv');
    %   extractor.extractAll('output_dir');
    
    properties (Access = private)
        legacy_file
        logger
        chunk_size = 10000  % Rows per chunk
    end
    
    methods
        function obj = SurveyExtractor(legacy_file, chunk_size)
            % SURVEYEXTRACTOR Constructor
            
            obj.legacy_file = legacy_file;
            obj.logger = logging.Logger('migration.SurveyExtractor');
            
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
            survey_map = containers.Map('KeyType', 'char', 'ValueType', 'double');
            
            current_start = 2;  % Skip header
            
            while current_start <= line_count
                chunk_counter = chunk_counter + 1;
                
                % Calculate end row for this chunk
                current_end = min(current_start + obj.chunk_size - 1, line_count);
                
                % Update import options for this chunk
                import_opts.DataLines = [current_start, current_end];
                
                obj.logger.info(sprintf('Processing chunk %d (rows %d to %d)', ...
                    chunk_counter, current_start, current_end));
                
                % Read chunk
                try
                    data_chunk = readtable(obj.legacy_file, import_opts);
                    
                    if ~istable(data_chunk)
                        obj.logger.error('Chunk read returned non-table type');
                        current_start = current_end + 1;
                        continue;
                    end
                    
                catch ME
                    obj.logger.error(sprintf('Failed to read chunk: %s', ME.message));
                    current_start = current_end + 1;
                    continue;
                end
                
                % Get number of rows
                num_rows = height(data_chunk);
                rows_processed = rows_processed + num_rows;
                
                if num_rows == 0
                    obj.logger.warning('Empty chunk, moving to next');
                    current_start = current_end + 1;
                    continue;
                end
                
                % Get unique FILEIDs in this chunk
                unique_fileids = unique(data_chunk.FILEID);
                
                % Remove empty/missing FILEIDs
                unique_fileids = unique_fileids(~ismissing(unique_fileids));
                unique_fileids = unique_fileids(strlength(unique_fileids) > 0);
                
                obj.logger.info(sprintf('  Found %d unique surveys in this chunk', ...
                    length(unique_fileids)));
                
                % Process each FILEID
                for idx = 1:length(unique_fileids)
                    current_fileid = unique_fileids{idx};
                    
                    % Sanitize filename
                    safe_fileid = narwc.utils.sanitize_filename(char(current_fileid));
                    output_filepath = fullfile(output_dir, [safe_fileid '.csv']);
                    
                    % Get rows for this survey
                    row_mask = strcmp(data_chunk.FILEID, current_fileid);
                    survey_data = data_chunk(row_mask, :);
                    
                    try
                        % Write to file
                        if exist(output_filepath, 'file')
                            % Append without header
                            % FIXME: this keeps 
                            obj.logger.debug(sprintf('  Appending to: %s', output_filepath));
                            writetable(survey_data, output_filepath, ...
                                'WriteMode', 'append', 'WriteVariableNames', false);
                        else
                            % Write with header (first time)
                            writetable(survey_data, output_filepath);
                            obj.logger.info(sprintf('  Created: %s', safe_fileid));
                        end
                        
                        % Track statistics
                        survey_row_count = height(survey_data);
                        if isKey(survey_map, safe_fileid)
                            survey_map(safe_fileid) = survey_map(safe_fileid) + survey_row_count;
                        else
                            survey_map(safe_fileid) = survey_row_count;
                        end
                        
                    catch ME
                        obj.logger.error(sprintf('  Failed to write %s: %s', ...
                            safe_fileid, ME.message));
                    end
                end
                
                % Progress update
                elapsed = toc(start_time);
                completion_pct = (rows_processed / line_count) * 100;
                obj.logger.info(sprintf('  Progress: %d/%d rows (%.1f\%) - %.1f minutes elapsed', ...
                    rows_processed, line_count, completion_pct, elapsed/60));
                
                % Move to next chunk
                current_start = current_end + 1;
                
                % Clear data to free memory
                clear data_chunk survey_data;
            end
            
            % Write summary
            obj.writeSummary(output_dir, survey_map, rows_processed, start_time);
            
            % Display summary
            total_time = toc(start_time);
            num_surveys = length(survey_map);
            
            obj.logger.info('======================================');
            obj.logger.info('Split operation completed successfully');
            obj.logger.info(sprintf('Total surveys: %d', num_surveys));
            obj.logger.info(sprintf('Total rows processed: %d', rows_processed));
            obj.logger.info(sprintf('Time elapsed: %.1f minutes', total_time/60));
            if num_surveys > 0
                obj.logger.info(sprintf('Average rows per survey: %d', ...
                    round(rows_processed/num_surveys)));
            end
            obj.logger.info(sprintf('Output directory: %s', output_dir));
            obj.logger.info('======================================');
        end
        
        function line_count = countLines(obj)
            % COUNTLINES Count total lines in file
            
            fid = fopen(obj.legacy_file, 'r');
            line_count = 0;
            while ~feof(fid)
                fgetl(fid);
                line_count = line_count + 1;
            end
            fclose(fid);
        end
        
        function writeSummary(obj, output_dir, survey_map, rows_processed, start_time)
            % WRITESUMMARY Write summary file
            
            summary_filepath = fullfile(output_dir, '_split_summary.txt');
            fid = fopen(summary_filepath, 'w');
            
            total_time = toc(start_time);
            num_surveys = length(survey_map);
            
            fprintf(fid, 'CSV Split Summary\n');
            fprintf(fid, '=================\n\n');
            fprintf(fid, 'Date: %s\n', char(datetime('now')));
            fprintf(fid, 'Input file: %s\n', obj.legacy_file);
            fprintf(fid, 'Output directory: %s\n\n', output_dir);
            fprintf(fid, 'Total surveys: %d\n', num_surveys);
            fprintf(fid, 'Total rows: %d\n', rows_processed);
            if num_surveys > 0
                fprintf(fid, 'Average rows per survey: %d\n', ...
                    round(rows_processed/num_surveys));
            end
            fprintf(fid, 'Time elapsed: %.1f minutes\n', total_time/60);
            fprintf(fid, '\nSurvey file row counts:\n');
            fprintf(fid, '-----------------------\n');
            
            % List all surveys sorted by name
            survey_names = keys(survey_map);
            survey_counts = cell2mat(values(survey_map));
            [~, sort_idx] = sort(survey_names);
            
            for i = 1:length(survey_names)
                idx = sort_idx(i);
                fprintf(fid, '%s: %d rows\n', survey_names{idx}, survey_counts(idx));
            end
            
            fclose(fid);
            
            obj.logger.info(sprintf('Summary written to: %s', summary_filepath));
        end
        
        function import_opts = createImportOptions(obj)
            % CREATEIMPORTOPTIONS Create import options for legacy CSV
            
            import_opts = delimitedTextImportOptions('NumVariables', 55);
            
            import_opts.Delimiter = ',';
            import_opts.DataLines = [2, Inf];
            
            % Variable names
            import_opts.VariableNames = ["ALT", "ANHEAD", "BEAUFORT", "BEHAV1", ...
                "BEHAV10", "BEHAV11", "BEHAV12", "BEHAV13", "BEHAV14", "BEHAV15", ...
                "BEHAV2", "BEHAV3", "BEHAV4", "BEHAV5", "BEHAV6", "BEHAV7", ...
                "BEHAV8", "BEHAV9", "BLOCK", "CLOUD", "CONFIDNC", "DAY", ...
                "DDSOURCE", "EVENTNO", "FILEID", "GLAREL", "GLARER", "HEADING", ...
                "IDREL", "IDSOURCE", "LAT_DD", "LEGNO", "LEGSTAGE", "LEGTYPE", ...
                "LONG_DD", "MONTH", "NUMBER", "NUMCALF", "PHOTOS", "PLATFORM", ...
                "S_LAT", "S_LONG", "S_TIME", "SIGHTNO", "SPECCODE", "STRATUM", ...
                "STRIP", "SURFTEMP", "TAXCODE", "TIME", "VISIBLTY", "WX", ...
                "YEAR", "ANGLEL", "ANGLER"];
            
            % Variable types
            import_opts.VariableTypes = ["double", "double", "double", "double", ...
                "double", "double", "double", "double", "double", "double", ...
                "double", "double", "double", "double", "double", "double", ...
                "double", "double", "string", "double", "double", "double", ...
                "string", "double", "string", "double", "double", "double", ...
                "double", "string", "double", "double", "double", "double", ...
                "double", "double", "double", "double", "double", "double", ...
                "double", "double", "string", "double", "string", "string", ...
                "string", "double", "double", "string", "double", "string", ...
                "double", "double", "double"];
            
            % String variable options
            import_opts = setvaropts(import_opts, ["BLOCK", "DDSOURCE", "FILEID", "IDSOURCE", ...
                "SPECCODE", "STRATUM", "STRIP", "S_TIME", "TIME", "WX"], ...
                "WhitespaceRule", "trim");
            
            import_opts = setvaropts(import_opts, ["BLOCK", "DDSOURCE", "FILEID", "IDSOURCE", ...
                "SPECCODE", "STRATUM", "STRIP", "S_TIME", "TIME", "WX"], ...
                "EmptyFieldRule", "missing");
            
            % Treat NULL and . as missing
            import_opts = setvaropts(import_opts, "TreatAsMissing", ["NULL", "."]);
            
            % Handle extra columns
            import_opts.ExtraColumnsRule = "ignore";
            import_opts.EmptyLineRule = "skip";
        end
    end
end