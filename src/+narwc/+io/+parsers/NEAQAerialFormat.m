classdef NEAQAerialFormat < narwc.io.parsers.BaseParser
    % NEAQAERIALFORMAT Parser for New England Aquarium aerial survey exports
    % ("Wind Energy Area 2024" project).
    %
    % Header confirmed against a real file:
    % data/surveys/raw/NEAQ Aerial/Wind Energy Area 2024/NEAQ-A-20240301_URI.csv
    % (gitignored -- see data/README.md's "NEAQ Aerial" section). Lowercase
    % column headers, unique among every contributor sampled so far.
    %
    % rectype,month,day,year,eventno,time,lat,long,heading,alt,legtype,
    %   legstage,legno,visiblty,glarel,glarer,beaufort,cloud,wx,sightno,
    %   anglel,angler,speccode,number,numcalf,anhead,photos,idrel,confidnc,
    %   b1..b15,block,refno,stratum,utc,radalt,gpsspeed,setalt,setvel,
    %   lensfl,ggf,int,gpsq,gpssats,roll,pitch,yaw,maghead,notes,edits,
    %   glarev,ph_qual,TrackDist
    %
    % A few files drop the trailing TrackDist column or add a distance_col
    % instead -- createImportOptions reads whatever's actually present
    % rather than requiring a fixed column count.
    %
    % Every flight ships two parallel CSV exports of the same data
    % (data/README.md): this full "_URI.csv" schema, and a reduced
    % "NLPSC###.csv" export dropping block/stratum/anglel/angler. Only the
    % richer "_URI.csv" schema is parsed -- pick that file at the
    % InputDir/glob level when converting this subfolder; detectFormat also
    % scores NLPSC###.csv-style files low as a safety net.
    %
    % MATLAB's readtable/detectImportOptions reads column names verbatim
    % (case-sensitive), so every lowercase native name needs an explicit
    % rename even where it's "the same" field as a canonical uppercase one.
    % Columns with no canonical home in narwc.db.FieldDefinitions (rectype,
    % refno, utc, radalt, gpsspeed, setalt, setvel, lensfl, ggf, int, gpsq,
    % gpssats, roll, pitch, yaw, maghead, notes, edits, glarev, ph_qual,
    % TrackDist -- nav/engineering + free-text fields) are correctly dropped
    % by remapToDatabase.
    %
    % sightno is auto-logged by the GPS/survey software on any marker-button
    % press, not just animal sightings -- see
    % StandardFormat.clearSpuriousSightno() (called at the end of parse())
    % for the full explanation, and CCSAerialFormat.m's docstring for the
    % real-data evidence that confirmed it.

    properties (Constant)
        FORMAT_NAME = 'NEAQ Aerial Format'
        DESCRIPTION = 'New England Aquarium aerial survey CSV export (Wind Energy Area 2024, "_URI" schema)'

        FIELD_MAPPING = {
            'month',    'MONTH';
            'day',      'DAY';
            'year',     'YEAR';
            'eventno',  'EVENTNO';
            'time',     'TIME';
            'lat',      'LAT_DD';
            'long',     'LONG_DD';
            'heading',  'HEADING';
            'alt',      'ALT';
            'legtype',  'LEGTYPE';
            'legstage', 'LEGSTAGE';
            'legno',    'LEGNO';
            'visiblty', 'VISIBLTY';
            'glarel',   'GLAREL';
            'glarer',   'GLARER';
            'beaufort', 'BEAUFORT';
            'cloud',    'CLOUD';
            'wx',       'WX';
            'sightno',  'SIGHTNO';
            'anglel',   'ANGLEL';
            'angler',   'ANGLER';
            'speccode', 'SPECCODE';
            'number',   'NUMBER';
            'numcalf',  'NUMCALF';
            'anhead',   'ANHEAD';
            'photos',   'PHOTOS';
            'idrel',    'IDREL';
            'confidnc', 'CONFIDNC';
            'b1',       'BEHAV1';
            'b2',       'BEHAV2';
            'b3',       'BEHAV3';
            'b4',       'BEHAV4';
            'b5',       'BEHAV5';
            'b6',       'BEHAV6';
            'b7',       'BEHAV7';
            'b8',       'BEHAV8';
            'b9',       'BEHAV9';
            'b10',      'BEHAV10';
            'b11',      'BEHAV11';
            'b12',      'BEHAV12';
            'b13',      'BEHAV13';
            'b14',      'BEHAV14';
            'b15',      'BEHAV15';
            'block',    'BLOCK';
            'stratum',  'STRATUM'
        };
    end

    methods (Static)
        function [data, metadata] = parse(file_path)
            % PARSE Parse a NEAQ Aerial "_URI" format file

            if ~exist(file_path, 'file')
                error('File not found: %s', file_path);
            end

            import_opts = narwc.io.parsers.NEAQAerialFormat.createImportOptions(file_path);
            raw_data = readtable(file_path, import_opts);

            rename_map = narwc.io.parsers.NEAQAerialFormat.FIELD_MAPPING;
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

            metadata.row_count = height(data);
            metadata.column_count = width(data);
            metadata.format = narwc.io.parsers.NEAQAerialFormat.FORMAT_NAME;
        end

        function import_opts = createImportOptions(file_path)
            % CREATEIMPORTOPTIONS Detect columns from the file itself --
            % tolerates the trailing-column variation between flights
            % (TrackDist present/absent/replaced by distance_col).
            import_opts = detectImportOptions(file_path, ...
                'NumHeaderLines', 0, 'Delimiter', ',');
        end

        function confidence = detectFormat(file_path)
            % DETECTFORMAT Score confidence based on lowercase distinctive
            % columns unique to the "_URI" schema (block/stratum/glarev/
            % ph_qual) -- the reduced NLPSC###.csv export lacks these, so
            % scores low, correctly steering callers toward the richer file.

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

                header_fields = strtrim(strsplit(header_line, ','));
                distinctive_fields = {'rectype', 'block', 'stratum', 'glarev', 'ph_qual'};
                matches = sum(ismember(distinctive_fields, header_fields));

                confidence = matches / numel(distinctive_fields);
            catch
                confidence = 0;
            end
        end
    end
end
