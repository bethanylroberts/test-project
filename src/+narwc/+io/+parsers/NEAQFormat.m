classdef NEAQFormat < narwc.io.parsers.BaseParser
    % NEAQFORMAT Parser for NEAQ's native survey export format
    %
    % Reference implementation for a per-contributor format parser. Unlike
    % StandardFormat (a headerless, fixed-position legacy CSV), NEAQ's file
    % has a header row -- so columns are read by name via
    % detectImportOptions() rather than a hardcoded position list.
    %
    % IMPORTANT: only the shape confirmed by config/format_definitions.json's
    % "neaq" entry is implemented here -- a title/preamble line before the
    % real header (header_row: 2), comma-delimited, and three confirmed
    % column renames (Latitude/Longitude/Species). No real NEAQ export file
    % exists anywhere in this repo to verify anything beyond that. See
    % tests/fixtures/sample_data/README.md. Extend FIELD_MAPPING as real
    % NEAQ files surface more known column names.

    properties (Constant)
        FORMAT_NAME = 'NEAQ Format'
        DESCRIPTION = 'NEAQ tab-delimited format with headers'

        % Native NEAQ column name -> canonical DB field name.
        % Source: config/format_definitions.json "neaq" entry.
        FIELD_MAPPING = {
            'Latitude',  'LAT_DD';
            'Longitude', 'LONG_DD';
            'Species',   'SPECCODE'
        };
    end

    methods (Static)
        function [data, metadata] = parse(file_path)
            % PARSE Parse a NEAQ-format file

            if ~exist(file_path, 'file')
                error('File not found: %s', file_path);
            end

            import_opts = narwc.io.parsers.NEAQFormat.createImportOptions(file_path);
            raw_data = readtable(file_path, import_opts);

            % Apply the confirmed field renames before handing off to the
            % shared canonical-schema coercion.
            rename_map = narwc.io.parsers.NEAQFormat.FIELD_MAPPING;
            for i = 1:size(rename_map, 1)
                native_name = rename_map{i, 1};
                canonical_name = rename_map{i, 2};
                if ismember(native_name, raw_data.Properties.VariableNames)
                    raw_data = renamevars(raw_data, native_name, canonical_name);
                end
            end

            % Remap to database field order (pads any missing canonical
            % fields, same shared helper StandardFormat uses).
            data = narwc.io.parsers.StandardFormat.remapToDatabase(raw_data);

            metadata.row_count = height(data);
            metadata.column_count = width(data);
            metadata.format = narwc.io.parsers.NEAQFormat.FORMAT_NAME;
        end

        function import_opts = createImportOptions(file_path)
            % CREATEIMPORTOPTIONS Detect columns/types from the file itself.
            %
            % NEAQ's real column layout beyond the 3 confirmed renames is
            % unknown, so this reads whatever columns are actually present
            % (via detectImportOptions) rather than hardcoding a full
            % positional field list the way StandardFormat does for the
            % legacy CSV.
            import_opts = detectImportOptions(file_path, ...
                'NumHeaderLines', 1, 'Delimiter', ',');
        end

        function confidence = detectFormat(file_path)
            % DETECTFORMAT Score confidence based on the 3 confirmed
            % distinctive NEAQ column names appearing on the header row
            % (line 2, after the title/preamble line on line 1).

            try
                if ~exist(file_path, 'file')
                    confidence = 0;
                    return;
                end

                fid = fopen(file_path, 'r');
                fgetl(fid);   % skip preamble line (header_row = 2)
                header_line = fgetl(fid);
                fclose(fid);

                if ~ischar(header_line)
                    confidence = 0;
                    return;
                end

                header_fields = strtrim(strsplit(header_line, ','));
                distinctive_fields = narwc.io.parsers.NEAQFormat.FIELD_MAPPING(:, 1)';
                matches = sum(ismember(distinctive_fields, header_fields));

                confidence = matches / numel(distinctive_fields);
            catch
                confidence = 0;
            end
        end
    end
end
