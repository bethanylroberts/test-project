function safe_name = sanitize_filename(filename)
    % SANITIZE_FILENAME Make a string safe for use as a filename
    %
    % Usage:
    %   safe = narwc.utils.sanitize_filename('File/Name*123');
    %   % Returns: 'File_Name_123'
    
    % Replace invalid characters with underscore
    safe_name = regexprep(filename, '[<>:"/\\|?*]', '_');
    
    % Remove any leading/trailing spaces or dots
    safe_name = strtrim(safe_name);
    safe_name = regexprep(safe_name, '^\.+|\.+$', '');
    
    % If empty after sanitization, use default
    if isempty(safe_name)
        safe_name = 'unnamed_file';
    end
end