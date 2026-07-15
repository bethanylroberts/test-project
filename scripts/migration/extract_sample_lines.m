% EXTRACT_SAMPLE_LINES - extract sample lines from large CSV with filtering
% 
% 2026 russ.shomberg@marineacoustics.com

% FIXME: I think I only use this file for auto-detection of file type. I would
% like to remove that functionality entirely. The user will always know what
% file type is being input. I would rather have the user run conversion scripts
% to convert any inputs into the standard input format.

% FIXME: delete - this is not used anywhere

function extract_sample_lines(input_file, output_file, num_lines, filter_field, filter_type, filter_value)
    % EXTRACT_SAMPLE_LINES Extract sample lines from large CSV with optional filtering
    %
    % Syntax:
    %   extract_sample_lines(input_file, output_file, num_lines)
    %   extract_sample_lines(input_file, output_file, num_lines, filter_field, filter_type)
    %   extract_sample_lines(input_file, output_file, num_lines, filter_field, filter_type, filter_value)
    %
    % Inputs:
    %   filter_field - Field number to filter on (e.g., 5 for BEHAV2, 25 for FILEID)
    %   filter_type  - 'not_null', 'not_empty', 'has_value', 'equals', 'contains'
    %   filter_value - Value to match (for 'equals' and 'contains' types)
    %
    % Examples:
    %   % Get 100 lines where BEHAV2 is not null
    %   extract_sample_lines('data/legacy/original_csv/RUSS_24_VALID.CSV', ...
    %                        'data/legacy/sample_behav2.csv', 100, 5, 'not_null')
    %
    %   % Get 100 lines where FILEID equals 'A179016'
    %   extract_sample_lines('data/legacy/original_csv/RUSS_24_VALID.CSV', ...
    %                        'data/legacy/sample_A179016.csv', 100, 25, 'equals', 'A179016')
    %
    %   % Get 100 lines where FILEID contains 'A179'
    %   extract_sample_lines('data/legacy/original_csv/RUSS_24_VALID.CSV', ...
    %                        'data/legacy/sample_A179.csv', 100, 25, 'contains', 'A179')
    %
    %   % Get first 100 lines (no filtering)
    %   extract_sample_lines('data/legacy/original_csv/RUSS_24_VALID.CSV', ...
    %                        'data/legacy/sample.csv', 100)
    
    if nargin < 3
        num_lines = 100;  % Default to 100 lines
    end
    
    use_filter = (nargin >= 4);
    if use_filter && nargin < 5
        filter_type = 'not_null';  % Default filter
    end
    
    needs_value = ismember(filter_type, {'equals', 'contains'});
    if needs_value && nargin < 6
        error('Filter type "%s" requires a filter_value parameter', filter_type);
    end
    
    % Set filter_value to empty if not provided
    if nargin < 6
        filter_value = '';
    end
    
    if use_filter
        if needs_value
            fprintf('Extracting %d lines where field %d %s "%s" from: %s\n', ...
                    num_lines, filter_field, filter_type, filter_value, input_file);
        else
            fprintf('Extracting %d lines where field %d is %s from: %s\n', ...
                    num_lines, filter_field, filter_type, input_file);
        end
    else
        fprintf('Extracting first %d lines from: %s\n', num_lines, input_file);
    end
    
    % Open input file
    fid_in = fopen(input_file, 'r');
    if fid_in == -1
        error('Cannot open input file: %s', input_file);
    end
    
    % Open output file
    fid_out = fopen(output_file, 'w');
    if fid_out == -1
        fclose(fid_in);
        error('Cannot create output file: %s', output_file);
    end
    
    header = "ALT,ANHEAD,BEAUFORT,BEHAV1,BEHAV2,BEHAV3,BEHAV4,BEHAV5,BEHAV6,BEHAV7,BEHAV8,BEHAV9,BEHAV10,BEHAV11,BEHAV12,BEHAV13,BEHAV14,BEHAV15,,CLOUD,CONFIDNC,DAY,DDSOURCE,EVENTNO,FILEID,GLAREL,GLARER,HEADING,IDREL,IDSOURCE,LAT_DD,LEGNO,LEGSTAGE,LEGTYPE,LONG_DD,MONTH,NUMBER,NUMCALF,PHOTOS,PLATFORM,,,,SIGHTNO,SPECCODE,,,,TAXCODE,TIME,VISIBLTY,WX,YEAR,,";
    fprintf(fid_out, '%s\n', header);
    
    % Read and write lines
    lines_written = 0;
    lines_read = 0;
    lines_filtered = 0;
    field_counts = [];
    
    fprintf('Reading lines...\n');
    while lines_written < num_lines && ~feof(fid_in)
        line = fgetl(fid_in);
        if ~ischar(line)
            break;
        end
        
        lines_read = lines_read + 1;
        
        % Parse fields
        fields = parse_csv_line(line);
        num_fields = length(fields);
        field_counts(end+1) = num_fields; %#ok<AGROW>
        
        % Apply filter if requested
        if use_filter
            if filter_field > num_fields
                warning('Filter field %d exceeds number of fields (%d) on line %d', ...
                        filter_field, num_fields, lines_read);
                lines_filtered = lines_filtered + 1;
                continue;
            end
            
            field_value_str = strtrim(fields{filter_field});
            
            % Check filter condition
            passes_filter = check_filter(field_value_str, filter_type, filter_value);
            
            if ~passes_filter
                lines_filtered = lines_filtered + 1;
                continue;
            end
        end
        
        % Write to output file
        fprintf(fid_out, '%s\n', line);
        lines_written = lines_written + 1;
        
        % Display first few matching lines
        if lines_written <= 5
            if use_filter
                fprintf('Match %d (line %d, field %d = "%s"): %s...\n', ...
                        lines_written, lines_read, filter_field, ...
                        fields{filter_field}, line(1:min(100, length(line))));
            else
                fprintf('Line %d (%d fields): %s...\n', ...
                        lines_written, num_fields, line(1:min(100, length(line))));
            end
        end
        
        % Progress update every 100k lines
        if mod(lines_read, 100000) == 0
            fprintf('  ... scanned %d lines, found %d matches\n', lines_read, lines_written);
        end
    end
    
    % Close files
    fclose(fid_in);
    fclose(fid_out);
    
    % Summary
    fprintf('\n=== EXTRACTION COMPLETE ===\n');
    fprintf('Total lines scanned: %d\n', lines_read);
    fprintf('Lines written: %d\n', lines_written);
    if use_filter
        fprintf('Lines filtered out: %d\n', lines_filtered);
        fprintf('Match rate: %.2f%%\n', 100 * lines_written / lines_read);
    end
    fprintf('Output file: %s\n', output_file);
    if ~isempty(field_counts)
        fprintf('Field count range: %d to %d\n', min(field_counts), max(field_counts));
        fprintf('Most common field count: %d\n', mode(field_counts));
    end
    
    % Show field count distribution if there's variation
    if ~isempty(field_counts)
        unique_counts = unique(field_counts);
        if length(unique_counts) > 1
            fprintf('\nField count distribution:\n');
            for i = 1:length(unique_counts)
                count = sum(field_counts == unique_counts(i));
                fprintf('  %d fields: %d lines\n', unique_counts(i), count);
            end
        end
    end
    
    fprintf('\nYou can now open %s in Excel or a text editor.\n', output_file);
end

function passes = check_filter(field_value, filter_type, filter_value)
    % Check if field value passes the filter
    % filter_value is optional for some filter types
    
    switch filter_type
        case 'not_null'
            % Exclude ".", empty, and whitespace-only
            passes = ~isempty(field_value) && ...
                     ~strcmp(field_value, '.') && ...
                     ~all(isspace(field_value));
            
        case 'not_empty'
            % Exclude only empty
            passes = ~isempty(field_value);
            
        case 'has_value'
            % Must have non-whitespace content
            passes = ~isempty(field_value) && ~all(isspace(field_value));
            
        case 'equals'
            % Exact match (case-insensitive)
            passes = strcmpi(field_value, filter_value);
            
        case 'contains'
            % Contains substring (case-insensitive)
            passes = contains(lower(field_value), lower(filter_value));
            
        otherwise
            error('Unknown filter type: %s', filter_type);
    end
end

function fields = parse_csv_line(line)
    % Parse a CSV line with quoted fields
    % Simple parser that handles quoted fields with commas
    
    fields = {};
    current_field = '';
    in_quotes = false;
    
    for i = 1:length(line)
        char = line(i);
        
        if char == '"'
            in_quotes = ~in_quotes;
        elseif char == ',' && ~in_quotes
            % End of field
            fields{end+1} = current_field; %#ok<AGROW>
            current_field = '';
        else
            current_field = [current_field, char]; %#ok<AGROW>
        end
    end
    
    % Add last field
    fields{end+1} = current_field;
end