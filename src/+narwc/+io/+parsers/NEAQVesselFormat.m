classdef NEAQVesselFormat < narwc.io.parsers.BaseParser
    % NEAQVESSELFORMAT Parser for New England Aquarium & Canadian Whale
    % Institute joint vessel-program survey exports.
    %
    % Header confirmed against a real file (UTF-8 BOM present):
    % data/surveys/raw/NEAQ & CWI (vessels)/2023/Fundy/2023-08-28-CWI-V.csv
    % (gitignored -- see data/README.md's "NEAQ & CWI (vessels)" section).
    % This supersedes the retired NEAQFormat.m stub, whose header-row-2/
    % preamble-line/Latitude-Longitude-casing assumptions were written
    % before any real NEAQ file existed and turned out not to match.
    %
    % EVENTNO,MONTH,DAY,YEAR,TIME,LATITUDE,LONGITUDE,HEADING,LEGTYPE,
    %   LEGSTAGE,WX,CLOUD,VISIBLTY,BEAUFORT,SIGHTNO,SPECCODE,IDREL,NUMBER,
    %   CONFIDNC,NUMCALF,ANHEAD,PHOTOS,BEHAV1..BEHAV15,NOTES
    %
    % Consistent across all sampled files per data/README.md. Note
    % LATITUDE/LONGITUDE (not LAT_DD/LONG_DD like most other contributors)
    % and EVENTNO first rather than last-ish.
    %
    % SIGHTNO is auto-logged by the GPS/survey software (e.g. Mysticetus,
    % used by this program per its cover-sheet transmittal letters) on any
    % marker-button press, not just animal sightings, and TAXCODE is never
    % present either (curator/GSO-assigned) -- see
    % StandardFormat.clearSpuriousSightno()/fillTaxcodeFromSpeccode() (both
    % called at the end of parse()) and CCSAerialFormat.m's docstring for
    % the full explanation and real-data evidence.

    properties (Constant)
        FORMAT_NAME = 'NEAQ & CWI Vessel Format'
        DESCRIPTION = 'New England Aquarium & Canadian Whale Institute joint vessel-program CSV export'

        % Native NEAQ & CWI vessel column name -> canonical DB field name.
        % Everything else already matches a canonical FieldDefinitions name.
        FIELD_MAPPING = {
            'LATITUDE',  'LAT_DD';
            'LONGITUDE', 'LONG_DD'
        };
    end

    methods (Static)
        function [data, metadata] = parse(file_path)
            % PARSE Parse a NEAQ & CWI vessel format file

            if ~exist(file_path, 'file')
                error('File not found: %s', file_path);
            end

            import_opts = narwc.io.parsers.NEAQVesselFormat.createImportOptions(file_path);
            raw_data = readtable(file_path, import_opts);

            rename_map = narwc.io.parsers.NEAQVesselFormat.FIELD_MAPPING;
            for i = 1:size(rename_map, 1)
                native_name = rename_map{i, 1};
                canonical_name = rename_map{i, 2};
                if ismember(native_name, raw_data.Properties.VariableNames)
                    raw_data = renamevars(raw_data, native_name, canonical_name);
                end
            end

            fileid = narwc.io.parsers.StandardFormat.fileidFromFilename(file_path);
            raw_data.FILEID = repmat(fileid, height(raw_data), 1);

            data = narwc.io.parsers.StandardFormat.remapToDatabase(raw_data);
            data = narwc.io.parsers.StandardFormat.clearSpuriousSightno(data);
            data = narwc.io.parsers.StandardFormat.fillTaxcodeFromSpeccode(data);

            metadata.row_count = height(data);
            metadata.column_count = width(data);
            metadata.format = narwc.io.parsers.NEAQVesselFormat.FORMAT_NAME;
        end

        function import_opts = createImportOptions(file_path)
            % CREATEIMPORTOPTIONS Real files carry a UTF-8 BOM before the
            % header row -- explicit 'Encoding','UTF-8' lets MATLAB's
            % import strip it so the first variable name comes back as
            % exactly 'EVENTNO', not a BOM-mangled variant.
            import_opts = detectImportOptions(file_path, ...
                'NumHeaderLines', 0, 'Delimiter', ',', 'Encoding', 'UTF-8');
        end

        function confidence = detectFormat(file_path)
            % DETECTFORMAT Score confidence based on LATITUDE/LONGITUDE
            % (not LAT_DD/LONG_DD) co-occurring with EVENTNO as the first
            % header field -- unique among every parser in this repo,
            % since every other contributor uses LAT_DD/LONG_DD natively.

            try
                if ~exist(file_path, 'file')
                    confidence = 0;
                    return;
                end

                fid = fopen(file_path, 'r', 'n', 'UTF-8');
                header_line = fgetl(fid);
                fclose(fid);

                if ~ischar(header_line)
                    confidence = 0;
                    return;
                end

                % Strip a UTF-8 BOM if fgetl didn't already. fgetl with
                % 'UTF-8' encoding decodes the 3 raw BOM bytes into a single
                % U+FEFF character, not the literal byte sequence -- a
                % byte-pattern regexp never matches it, so compare the
                % actual decoded character instead.
                if ~isempty(header_line) && header_line(1) == char(65279)
                    header_line = header_line(2:end);
                end
                header_fields = strtrim(strsplit(header_line, ','));

                distinctive_fields = {'LATITUDE', 'LONGITUDE'};
                matches = sum(ismember(distinctive_fields, header_fields));

                confidence = matches / numel(distinctive_fields);
                if confidence > 0 && strcmp(header_fields{1}, 'EVENTNO')
                    confidence = 1;
                end
            catch
                confidence = 0;
            end
        end
    end
end
