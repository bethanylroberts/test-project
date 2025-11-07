classdef LegacyFormat < narwc.io.parsers.BaseParser
    % LEGACYFORMAT Parser for legacy database format
    %
    % Comma-delimited, may have different column order
    
    properties (Constant)
        FORMAT_NAME = 'Legacy Format'
        DESCRIPTION = 'Comma-delimited legacy database export'
    end
    
    methods
        function [data, metadata] = parse(obj)
            % PARSE Parse legacy format file
            
            % Use the same import options as migration extractor
            import_opts = obj.createLegacyImportOptions();
            
            % Read file
            data = readtable(obj.file_path, import_opts);
            
            % Metadata
            metadata.row_count = height(data);
            metadata.column_count = width(data);
        end
        
        function import_opts = createLegacyImportOptions(obj)
            % Create import options for legacy format
            
            import_opts = delimitedTextImportOptions('NumVariables', 55);
            import_opts.Delimiter = ',';
            import_opts.DataLines = [2, Inf];
            
            % Variable names (legacy order)
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
            
            % String options
            import_opts = setvaropts(import_opts, ["BLOCK", "DDSOURCE", "FILEID", ...
                "IDSOURCE", "SPECCODE", "STRATUM", "STRIP", "S_TIME", "TIME", "WX"], ...
                "WhitespaceRule", "trim", "EmptyFieldRule", "missing");
            
            import_opts = setvaropts(import_opts, 'TreatAsMissing', ["NULL", "."]);
            import_opts.ExtraColumnsRule = 'ignore';
            import_opts.EmptyLineRule = 'skip';
        end
    end
    
    methods (Static)
        function confidence = detectFormat(file_path)
            % DETECTFORMAT Detect if file is in legacy format
            
            try
                % Check if file exists
                if ~exist(file_path, 'file')
                    confidence = 0;
                    return;
                end
                
                fid = fopen(file_path, 'r');
                header = fgetl(fid);
                fclose(fid);
                
                % Check for comma delimiter
                if ~contains(header, ',')
                    confidence = 0;
                    return;
                end
                
                % Check for key legacy field names
                legacy_indicators = {'FILEID', 'SPECCODE', 'DDSOURCE', 'EVENTNO'};
                matches = sum(contains(header, legacy_indicators));
                confidence = matches / length(legacy_indicators);
                
            catch
                confidence = 0;
            end
        end
    end
end