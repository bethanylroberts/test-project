classdef CCSAerialFormat < narwc.io.parsers.BaseParser
    % CCSAERIALFORMAT Parser for Center for Coastal Studies aerial survey exports.
    %
    % Header confirmed against real files: data/surveys/raw/CCS/2023 Aerial/CCS1003.csv
    % and data/surveys/raw/CCS/2024 Aerial/CCS1017.csv (both gitignored, not
    % in this repo's history -- see data/README.md's "CCS" section).
    %
    % 2023: MONTH,DAY,YEAR,EVENTNO,TIME,LAT_DD,LONG_DD,LEGTYPE,LEGSTAGE,LEGNO,
    %   ALT,HEADING,SPEED,VISIBLTY,BEAUFORT,CLOUD,GLAREL,GLARER,WX,SIGHTNO,
    %   SPECCODE,NUMBER,NUMCALF,PHOTOS,IDREL,CONFIDNC,ANHEAD,B1..B15,NOTES,
    %   Comment,OBSSIGHT,CLOCK,DISTANCE,RELPOS
    % 2024: same, plus a leading blank/index column and a redundant text DATE
    %   column ahead of the still-present split MONTH/DAY/YEAR; quoted-CSV
    %   style. Both years already carry split MONTH/DAY/YEAR, so no date
    %   parsing is needed here (contrast with CCSVesselFormat/
    %   CCSOpportunisticFormat, which sometimes only have a single DATE
    %   column).
    %
    % Most columns are already canonical field names and pass through
    % remapToDatabase unchanged. SPEED, NOTES, Comment, OBSSIGHT, CLOCK,
    % DISTANCE, RELPOS, the 2024 leading index column, and the 2024 redundant
    % DATE column have no canonical home in narwc.db.FieldDefinitions and are
    % correctly dropped by remapToDatabase -- not a bug, don't invent fields
    % for them.
    %
    % Raw files don't carry FILEID; one raw file is one survey (data/README.md),
    % so FILEID is derived from the filename via
    % StandardFormat.fileidFromFilename().
    %
    % SIGHTNO is auto-logged by the GPS/survey software whenever the
    % operator presses a marker button -- not just for animal sightings
    % (curator-confirmed, 2026-07-27) -- so parse() calls
    % StandardFormat.clearSpuriousSightno() to blank SIGHTNO on any row
    % without a SPECCODE, which otherwise gets misclassified as a sighting
    % missing its species code. See that function's docstring for the full
    % explanation and the real-data evidence that confirmed it.
    %
    % TAXCODE is never present in the raw file either (curator/GSO-assigned,
    % same category as DDSOURCE/IDSOURCE/PLATFORM) -- parse() calls
    % StandardFormat.fillTaxcodeFromSpeccode() to derive it from SPECCODE
    % via data/tables/SPECCODE.csv wherever that table has an entry for the
    % code. See that function's docstring for the full explanation.

    properties (Constant)
        FORMAT_NAME = 'CCS Aerial Format'
        DESCRIPTION = 'Center for Coastal Studies aerial survey CSV export'

        % Native CCS Aerial column name -> canonical DB field name.
        % Only the behavior columns need renaming -- everything else CCS
        % Aerial supplies already matches a canonical FieldDefinitions name.
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
            % PARSE Parse a CCS Aerial format file

            if ~exist(file_path, 'file')
                error('File not found: %s', file_path);
            end

            import_opts = narwc.io.parsers.CCSAerialFormat.createImportOptions(file_path);
            raw_data = readtable(file_path, import_opts);

            rename_map = narwc.io.parsers.CCSAerialFormat.FIELD_MAPPING;
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
            metadata.format = narwc.io.parsers.CCSAerialFormat.FORMAT_NAME;
        end

        function import_opts = createImportOptions(file_path)
            % CREATEIMPORTOPTIONS Detect columns from the file itself --
            % tolerates both 2023's unquoted layout and 2024's quoted-CSV
            % layout (with its extra leading blank/index column) without
            % hardcoding a fixed column count.
            import_opts = detectImportOptions(file_path, ...
                'NumHeaderLines', 0, 'Delimiter', ',');
        end

        function confidence = detectFormat(file_path)
            % DETECTFORMAT Score confidence based on distinctive CCS Aerial
            % columns appearing on the header row: B1 (behavior columns
            % named B1..B15, not BEHAV1..BEHAV15), LEGNO, and SPEED --
            % this combination is unique to CCS Aerial among the CCS trio
            % (CCSVesselFormat has no LEGNO; CCSOpportunisticFormat has no
            % LEGNO/SPEED either).

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
                distinctive_fields = {'B1', 'LEGNO', 'SPEED'};
                matches = sum(ismember(distinctive_fields, header_fields));

                confidence = matches / numel(distinctive_fields);
            catch
                confidence = 0;
            end
        end
    end
end
