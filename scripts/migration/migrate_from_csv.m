function stats = migrate_from_csv(legacy_file, options)
    % MIGRATE_FROM_CSV Upload surveys directly from CSV (chunked)
    %
    % Usage:
    %   migrate_from_csv('data/legacy/RUSS_24_VALID.CSV')
    %   migrate_from_csv('legacy.csv', 'Overwrite', true, 'Validate', false)
    
    arguments
        legacy_file char
        options.Overwrite logical = false
        options.Validate logical = true
        options.ChunkSize double = 10000
    end
    
    fprintf('=== Migrating Surveys from CSV to Database ===\n\n');
    
    % Create extractor (doesn't load data yet)
    extractor = migration.SurveyExtractor(legacy_file, options.ChunkSize);
    
    % Connect to database
    conn = narwc.db.Connection.create();
    
    try
        % Create converter
        converter = migration.BatchConverter(conn);
        
        % Process in chunks
        fprintf('Processing CSV in chunks of %d rows...\n', options.ChunkSize);
        
        % Get import options
        import_opts = extractor.createImportOptions();
        
        % Count lines
        line_count = extractor.countLines();
        fprintf('Total lines: %d\n', line_count);
        
        current_start = 2;
        chunk_num = 0;
        
        while current_start <= line_count
            chunk_num = chunk_num + 1;
            current_end = min(current_start + options.ChunkSize - 1, line_count);
            
            fprintf('\n[Chunk %d] Reading rows %d to %d...\n', ...
                chunk_num, current_start, current_end);
            
            % Read chunk
            import_opts.DataLines = [current_start, current_end];
            data_chunk = readtable(legacy_file, import_opts);
            
            % Get unique surveys in chunk
            fileids = unique(data_chunk.FILEID);
            fileids = fileids(~ismissing(fileids) & strlength(fileids) > 0);
            
            fprintf('Found %d unique surveys in chunk\n', length(fileids));
            
            % Upload each survey
            for i = 1:length(fileids)
                fileid = fileids{i};
                survey_data = data_chunk(strcmp(data_chunk.FILEID, fileid), :);
                
                try
                    converter.uploadSurvey(survey_data, ...
                        'Overwrite', options.Overwrite, ...
                        'Validate', options.Validate);
                catch ME
                    fprintf('  ✗ Failed: %s - %s\n', fileid, ME.message);
                end
            end
            
            current_start = current_end + 1;
            clear data_chunk;
        end
        
        % Get stats
        stats = converter.getStats();
        converter.displayStats();
        
    finally
        conn.close();
    end
end