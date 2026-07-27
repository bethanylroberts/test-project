classdef CCSVesselFormat < narwc.io.parsers.BaseParser
    % CCSVESSELFORMAT Parser for Center for Coastal Studies vessel (R/V
    % Shearwater) survey exports.
    %
    % Header confirmed against real files: data/surveys/raw/CCS/2023 Vessel/SW1375.csv
    % and data/surveys/raw/CCS/2024 Vessel/SW1413.csv (both gitignored -- see
    % data/README.md's "CCS" section).
    %
    % DATE,EVENTNO,TIME,LAT_DD,LONG_DD,LEGTYPE,LEGSTAGE,HEADING,DEPTH,
    %   SURFTEMP,VISIBLTY,BEAUFORT,CLOUD,WX,SIGHTNO,SPECCODE,NUMBER,NUMCALF,
    %   PHOTOS,IDREL,CONFIDNC,ANHEAD,BEHAV1..BEHAV15 (2023) / B1..B15 (2024),
    %   NOTES,Comment -- 2024 is quoted-CSV.
    %
    % Unlike CCSAerialFormat, there is no split MONTH/DAY/YEAR -- only a
    % single DATE text column ("21-Apr-23", "2-MAY-24"; format dd-MMM-yy,
    % case varies by file). parse() splits DATE into MONTH/DAY/YEAR before
    % remapToDatabase, since there's no canonical DATE field for it to land
    % on otherwise. DEPTH has no canonical home (same gap as SPEED in
    % CCSAerialFormat) and is dropped by remapToDatabase; SURFTEMP is
    % canonical and passes through unchanged.

    properties (Constant)
        FORMAT_NAME = 'CCS Vessel Format'
        DESCRIPTION = 'Center for Coastal Studies vessel (R/V Shearwater) survey CSV export'

        % Native CCS Vessel column name -> canonical DB field name.
        % Applying this unconditionally is safe for both years: 2023 files
        % have no B1..B15 columns (rename is a no-op) and already carry
        % BEHAV1..BEHAV15, which pass through remapToDatabase untouched;
        % 2024 files have B1..B15 and get renamed here.
        FIELD_MAPPING = {
            'B1',  'BEHAV1';
            'B2',  'BEHAV2';
            'B3',  'BEHAV3';
            'B4',  'BEHAV4';
            'B5',  'BEHAV5';
            'B6',  'BEHAV6';
            'B7',  'BEHAV7';
            'B8',  'BEHAV8';
            'B9',  'BEHAV9';
            'B10', 'BEHAV10';
            'B11', 'BEHAV11';
            'B12', 'BEHAV12';
            'B13', 'BEHAV13';
            'B14', 'BEHAV14';
            'B15', 'BEHAV15'
        };
    end

    methods (Static)
        function [data, metadata] = parse(file_path)
            % PARSE Parse a CCS Vessel format file

            if ~exist(file_path, 'file')
                error('File not found: %s', file_path);
            end

            import_opts = narwc.io.parsers.CCSVesselFormat.createImportOptions(file_path);
            raw_data = readtable(file_path, import_opts);

            rename_map = narwc.io.parsers.CCSVesselFormat.FIELD_MAPPING;
            for i = 1:size(rename_map, 1)
                native_name = rename_map{i, 1};
                canonical_name = rename_map{i, 2};
                if ismember(native_name, raw_data.Properties.VariableNames)
                    raw_data = renamevars(raw_data, native_name, canonical_name);
                end
            end

            if ismember('DATE', raw_data.Properties.VariableNames)
                dates = datetime(string(raw_data.DATE), 'InputFormat', 'dd-MMM-yy');
                raw_data.MONTH = month(dates);
                raw_data.DAY = day(dates);
                raw_data.YEAR = year(dates);
            end

            fileid = narwc.io.parsers.StandardFormat.fileidFromFilename(file_path);
            raw_data.FILEID = repmat(fileid, height(raw_data), 1);

            data = narwc.io.parsers.StandardFormat.remapToDatabase(raw_data);

            metadata.row_count = height(data);
            metadata.column_count = width(data);
            metadata.format = narwc.io.parsers.CCSVesselFormat.FORMAT_NAME;
        end

        function import_opts = createImportOptions(file_path)
            % CREATEIMPORTOPTIONS Detect columns from the file itself --
            % tolerates both 2023's unquoted layout and 2024's quoted-CSV
            % layout.
            import_opts = detectImportOptions(file_path, ...
                'NumHeaderLines', 1, 'Delimiter', ',');
        end

        function confidence = detectFormat(file_path)
            % DETECTFORMAT Score confidence based on DEPTH and SURFTEMP
            % co-occurring with a single DATE column (no MONTH column) --
            % that combination is unique to CCS Vessel among the CCS trio.

            try
                if ~exist(file_path, 'file')
                    confidence = 0;
                    return;
                end

                fid = fopen(file_path, 'r');
                header_line = fgetl(fid);
                fclose(fid);

                if ~ischar(header_line)
                    confidence = 0;
                    return;
                end

                header_fields = strtrim(strsplit(strrep(header_line, '"', ''), ','));
                distinctive_fields = {'DATE', 'DEPTH', 'SURFTEMP'};
                matches = sum(ismember(distinctive_fields, header_fields));

                if ismember('MONTH', header_fields)
                    % Split M/D/Y present -- this is CCSAerialFormat or
                    % CCSOpportunisticFormat, not CCSVesselFormat.
                    confidence = 0;
                    return;
                end

                confidence = matches / numel(distinctive_fields);
            catch
                confidence = 0;
            end
        end
    end
end
