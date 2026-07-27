classdef CCSOpportunisticFormat < narwc.io.parsers.BaseParser
    % CCSOPPORTUNISTICFORMAT Parser for Center for Coastal Studies
    % opportunistic-sighting exports.
    %
    % Header confirmed against real files:
    % data/surveys/raw/CCS/2023 Opportunistic/Mar-22.csv (one file per trip)
    % data/surveys/raw/CCS/2024 Opportunistic/2024 CCS Opportunistic Sightings-NARWC Submission.csv
    % (one aggregated annual file) -- both gitignored, see data/README.md's
    % "CCS" section.
    %
    % 2023: MONTH,DAY,YEAR,EVENTNO,TIME,LAT_DD,LONG_DD,VISIBLTY,BEAUFORT,
    %   CLOUD,WX,SIGHTNO,SPECCODE,NUMBER,NUMCALF,PHOTOS,IDREL,CONFIDNC,
    %   ANHEAD,B1..B15,PLATFORM,NOTES,Comment -- split MONTH/DAY/YEAR already
    %   present, one file per trip.
    % 2024: DATE,CRUISENO,EVENTNO,TIME,LAT_DD,LONG_DD,VISIBLTY,BEAUFORT,
    %   CLOUD,WX,SIGHTNO,SPECCODE,NUMBER,NUMCALF,PHOTOS,IDREL,CONFIDNC,
    %   ANHEAD,B1..B15,PLATFORM,NOTES,Comment -- single text DATE (needs the
    %   same dd-MMM-yy split as CCSVesselFormat), and CRUISENO per row
    %   identifies the vessel survey this sighting was recorded during (e.g.
    %   "SW1391").
    %
    % Unlike the other CCS/NEAQ parsers, one raw file is NOT always one
    % survey here: the 2024 file aggregates a whole season's worth of
    % one-off sightings, so its FILEID comes from the per-row CRUISENO
    % instead of the (meaningless, one-annual-file) filename stem. The 2023
    % per-trip files have no CRUISENO column, so they fall back to
    % StandardFormat.fileidFromFilename() like the other CCS/NEAQ parsers.
    %
    % Operational note (not parser logic): CCS/2023 Opportunistic/ also
    % contains CCSmap23.csv (a position-only EVENTNO/LATITUDE/LONGITUDE
    % extract) and CCS985K.csv (a speed-log sidecar to CCS985.csv) -- neither
    % is a real survey file. This parser doesn't special-case them; exclude
    % them at the file-selection step when converting this subfolder.

    properties (Constant)
        FORMAT_NAME = 'CCS Opportunistic Format'
        DESCRIPTION = 'Center for Coastal Studies opportunistic-sighting CSV export'

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
            % PARSE Parse a CCS Opportunistic format file

            if ~exist(file_path, 'file')
                error('File not found: %s', file_path);
            end

            import_opts = narwc.io.parsers.CCSOpportunisticFormat.createImportOptions(file_path);
            raw_data = readtable(file_path, import_opts);

            rename_map = narwc.io.parsers.CCSOpportunisticFormat.FIELD_MAPPING;
            for i = 1:size(rename_map, 1)
                native_name = rename_map{i, 1};
                canonical_name = rename_map{i, 2};
                if ismember(native_name, raw_data.Properties.VariableNames)
                    raw_data = renamevars(raw_data, native_name, canonical_name);
                end
            end

            if ~ismember('MONTH', raw_data.Properties.VariableNames) ...
                    && ismember('DATE', raw_data.Properties.VariableNames)
                if isdatetime(raw_data.DATE)
                    % detectImportOptions can auto-detect a column this
                    % date-like (dd-MMM-yy) as a native datetime already.
                    dates = raw_data.DATE;
                else
                    dates = datetime(string(raw_data.DATE), 'InputFormat', 'dd-MMM-yy');
                end
                % See CCSVesselFormat.m's parse() for the fuller
                % explanation: confirmed via direct inspection that for a
                % 2-digit-year source, year() returns the literal number
                % (23, not 2023) regardless of which branch above produced
                % `dates` -- add the century directly.
                raw_data.YEAR = year(dates) + 2000;
                raw_data.MONTH = month(dates);
                raw_data.DAY = day(dates);
            end

            if ismember('CRUISENO', raw_data.Properties.VariableNames)
                raw_data.FILEID = string(raw_data.CRUISENO);
            else
                fileid = narwc.io.parsers.StandardFormat.fileidFromFilename(file_path);
                raw_data.FILEID = repmat(fileid, height(raw_data), 1);
            end

            data = narwc.io.parsers.StandardFormat.remapToDatabase(raw_data);

            metadata.row_count = height(data);
            metadata.column_count = width(data);
            metadata.format = narwc.io.parsers.CCSOpportunisticFormat.FORMAT_NAME;
        end

        function import_opts = createImportOptions(file_path)
            % CREATEIMPORTOPTIONS Detect columns from the file itself --
            % tolerates both the 2023 per-trip layout (split MONTH/DAY/YEAR)
            % and the 2024 aggregated layout (single DATE + CRUISENO).
            import_opts = detectImportOptions(file_path, ...
                'NumHeaderLines', 0, 'Delimiter', ',');
        end

        function confidence = detectFormat(file_path)
            % DETECTFORMAT Score confidence based on PLATFORM co-occurring
            % with either split MONTH/DAY/YEAR (2023) or DATE+CRUISENO
            % (2024), and the absence of LEGTYPE/ALT/LEGNO (opportunistic
            % sightings drop the track-following fields per data/README.md)
            % -- this combination is unique to CCS Opportunistic among the
            % CCS trio.

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

                if ismember('LEGTYPE', header_fields) || ismember('LEGNO', header_fields)
                    confidence = 0;
                    return;
                end

                has_platform = ismember('PLATFORM', header_fields);
                has_2023_dates = all(ismember({'MONTH', 'DAY', 'YEAR'}, header_fields));
                has_2024_dates = all(ismember({'DATE', 'CRUISENO'}, header_fields));

                if has_platform && (has_2023_dates || has_2024_dates)
                    confidence = 1;
                elseif has_platform
                    confidence = 0.5;
                else
                    confidence = 0;
                end
            catch
                confidence = 0;
            end
        end
    end
end
