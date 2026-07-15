%VALIDATE_CSV_DATABASE_LINES Validate CSV lines and splits valid/invalid files
%
% This script reads a CSV file line by line, validates each line's format, and
% writes valid lines to one file and invalid lines to another. Useful for
% debugging malformed CSV files. However, this lets a lot of errors through. It
% only provides very basic checks to ensure the other validators can open the
% files.
% 
% 2026 russ.shomberg@marineacoustics.com

% FIXME: this is basically step0 and my steps are off anyway. It would make the
% most sense to get rid of the step labeling and just put everything relevant in
% the "run_full_migration.m" script or else into a README file.

% NOTE: this is a pretty good script. It does not have a ton of abstraction.
% Chances are it will only be used once or twice. Once migration is complete,
% there is no reason to keep it. Therefore, everything should be kept internal
% to the script.

% ???: should configuration options be exposed as function arguments or kept like this?

%% Configuration
input_csv = 'data/legacy/original_csv/RUSS_24.CSV';
valid_output = 'data/legacy/original_csv/RUSS_24_VALID.CSV';
invalid_output = 'data/legacy/original_csv/RUSS_24_INVALID.CSV';
error_log = 'data/legacy/RUSS_24_ERRORS.txt';

% Expected number of fields (columns)
expected_num_fields = 55;

% Whether to be strict about field types
strict_validation = false;  % If true, validates field content too

%% Initialize
logging.info('Starting CSV line validation');

% Create output directory if needed
output_dir = fileparts(valid_output);
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% Open files
fid_in = fopen(input_csv, 'r', 'n', 'UTF-8');
if fid_in == -1
    error('Cannot open input file: %s', input_csv);
end

fid_valid = fopen(valid_output, 'w', 'n', 'UTF-8');
if fid_valid == -1
    fclose(fid_in);
    error('Cannot create valid output file: %s', valid_output);
end

fid_invalid = fopen(invalid_output, 'w', 'n', 'UTF-8');
if fid_invalid == -1
    fclose(fid_in);
    fclose(fid_valid);
    error('Cannot create invalid output file: %s', invalid_output);
end

fid_errors = fopen(error_log, 'w', 'n', 'UTF-8');
if fid_errors == -1
    fclose(fid_in);
    fclose(fid_valid);
    fclose(fid_invalid);
    error('Cannot create error log file: %s', error_log);
end

% FIXME: correct fprintf to logging.info
% Write error log header
fprintf(fid_errors, 'CSV Line Validation Error Log\n');
fprintf(fid_errors, '=============================\n');
fprintf(fid_errors, 'Input file: %s\n', input_csv);
fprintf(fid_errors, 'Date: %s\n\n', char(datetime('now')));

% Statistics
line_num = 0;
valid_count = 0;
invalid_count = 0;
error_types = containers.Map('KeyType', 'char', 'ValueType', 'double');

tic;

try
    %% Process each line
    while ~feof(fid_in)
        line_num = line_num + 1;
        
        % Read raw line
        line = fgetl(fid_in);
        
        % Skip if end of file marker
        if ~ischar(line)
            break;
        end
        
        % Validate line
        [is_valid, error_msg] = validate_line(line, expected_num_fields, strict_validation);
        
        if is_valid
            % Write to valid file
            fprintf(fid_valid, '%s\n', line);
            valid_count = valid_count + 1;
        else
            % Write to invalid file
            fprintf(fid_invalid, '%s\n', line);
            invalid_count = invalid_count + 1;
            
            % Log error
            fprintf(fid_errors, 'Line %d: %s\n', line_num, error_msg);
            fprintf(fid_errors, '  Content: %s\n\n', line);
            
            % Track error type
            if isKey(error_types, error_msg)
                error_types(error_msg) = error_types(error_msg) + 1;
            else
                error_types(error_msg) = 1;
            end
        end
        
        % Progress update every 10000 lines
        if mod(line_num, 10000) == 0
            elapsed = toc;
            logging.info(['Processed ' num2str(line_num) ' lines (' ...
                num2str(valid_count) ' valid, ' ...
                num2str(invalid_count) ' invalid) - ' ...
                num2str(round(elapsed, 1)) ' seconds']);
        end
    end
    
    %% Close files
    fclose(fid_in);
    fclose(fid_valid);
    fclose(fid_invalid);
    
    % Write error summary
    fprintf(fid_errors, '\n=============================\n');
    fprintf(fid_errors, 'Summary\n');
    fprintf(fid_errors, '=============================\n');
    fprintf(fid_errors, 'Total lines: %d\n', line_num);
    fprintf(fid_errors, 'Valid lines: %d (%.2f%%)\n', valid_count, 100*valid_count/line_num);
    fprintf(fid_errors, 'Invalid lines: %d (%.2f%%)\n', invalid_count, 100*invalid_count/line_num);
    fprintf(fid_errors, '\nError Types:\n');
    
    error_names = keys(error_types);
    for i = 1:length(error_names)
        fprintf(fid_errors, '  %s: %d\n', error_names{i}, error_types(error_names{i}));
    end
    
    fclose(fid_errors);
    
    %% Summary
    elapsed_time = toc;
    
    logging.info('======================================');
    logging.info('CSV validation completed');
    logging.info(['Total lines: ' num2str(line_num)]);
    logging.info(['Valid lines: ' num2str(valid_count) ' (' ...
        num2str(round(100*valid_count/line_num, 2)) '%)']);
    logging.info(['Invalid lines: ' num2str(invalid_count) ' (' ...
        num2str(round(100*invalid_count/line_num, 2)) '%)']);
    logging.info(['Time elapsed: ' num2str(round(elapsed_time, 1)) ' seconds']);
    logging.info(['Valid output: ' valid_output]);
    logging.info(['Invalid output: ' invalid_output]);
    logging.info(['Error log: ' error_log]);
    logging.info('======================================');
    
    % Display error type summary
    if invalid_count > 0
        logging.info('Error types found:');
        error_names = keys(error_types);
        for i = 1:length(error_names)
            logging.info(['  ' error_names{i} ': ' num2str(error_types(error_names{i}))]);
        end
    end
    
catch ME
    % Close any open files
    if exist('fid_in', 'var') && fid_in ~= -1
        fclose(fid_in);
    end
    if exist('fid_valid', 'var') && fid_valid ~= -1
        fclose(fid_valid);
    end
    if exist('fid_invalid', 'var') && fid_invalid ~= -1
        fclose(fid_invalid);
    end
    if exist('fid_errors', 'var') && fid_errors ~= -1
        fclose(fid_errors);
    end
    
    logging.error('Fatal error during validation');
    logging.error(['Error: ' ME.message]);
    rethrow(ME);
end

% end

%% Helper function to validate a single line
function [is_valid, error_msg] = validate_line(line, expected_num_fields, strict)
    % VALIDATE_LINE Check if a CSV line is valid
    %
    % Returns:
    %   is_valid - true if line is valid
    %   error_msg - description of error if invalid
    
    is_valid = true;
    error_msg = '';
    
    % Check if line is empty
    if isempty(strtrim(line))
        is_valid = false;
        error_msg = 'Empty line';
        return;
    end
    
    % Parse CSV line (handle quoted fields with commas)
    fields = parse_csv_line(line);
    
    % Check number of fields
    num_fields = length(fields);
    if num_fields ~= expected_num_fields
        is_valid = false;
        error_msg = sprintf('Wrong number of fields (expected %d, got %d)', ...
            expected_num_fields, num_fields);
        return;
    end
    
    % If strict validation, check field content
    % FIXME: either remove strict validation option or include more results. 
    % - Ensuring the FILEID is probably a top priority
    if strict
        % Check FILEID (field 27) - should not be empty
        if isempty(strtrim(fields{27}))
            is_valid = false;
            error_msg = 'Empty FILEID';
            return;
        end
        
        % Check LAT_DD (field 33) - should be numeric
        lat = str2double(fields{33});
        if ~isempty(fields{33}) && isnan(lat)
            is_valid = false;
            error_msg = 'Invalid latitude (non-numeric)';
            return;
        end
        
        % Check LONG_DD (field 37) - should be numeric
        lon = str2double(fields{37});
        if ~isempty(fields{37}) && isnan(lon)
            is_valid = false;
            error_msg = 'Invalid longitude (non-numeric)';
            return;
        end
    end
end

%% Helper function to parse CSV line
function fields = parse_csv_line(line)
    % PARSE_CSV_LINE Parse a CSV line handling quoted fields
    %
    % This function properly handles:
    % - Quoted fields that contain commas
    % - Escaped quotes (double quotes)
    % - Empty fields
    
    fields = {};
    current_field = '';
    in_quotes = false;
    i = 1;
    
    while i <= length(line)
        c = line(i);
        
        if c == '"'
            if in_quotes && i < length(line) && line(i+1) == '"'
                % Escaped quote (double quote) - add single quote
                current_field = [current_field '"'];
                i = i + 1;  % Skip next quote
            else
                % Toggle quote state
                in_quotes = ~in_quotes;
            end
        elseif c == ',' && ~in_quotes
            % End of field
            fields{end+1} = current_field;
            current_field = '';
        else
            % Regular character
            current_field = [current_field c];
        end
        
        i = i + 1;
    end
    
    % Add last field
    fields{end+1} = current_field;
end