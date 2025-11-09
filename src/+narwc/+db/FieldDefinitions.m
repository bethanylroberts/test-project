classdef FieldDefinitions
    % FIELDDEFINITIONS Single source of truth for all database field types
    %
    % Usage:
    %   fields = narwc.db.FieldDefinitions.getAll();
    %   is_numeric = narwc.db.FieldDefinitions.isNumeric('LAT_DD');

    % header = "ALT,ANHEAD,BEAUFORT,BEHAV1,BEHAV2,BEHAV3,BEHAV4,BEHAV5,BEHAV6,BEHAV7,BEHAV8,BEHAV9,BEHAV10,BEHAV11,BEHAV12,BEHAV13,BEHAV14,BEHAV15,,CLOUD,CONFIDNC,DAY,DDSOURCE,EVENTNO,FILEID,GLAREL,GLARER,HEADING,IDREL,IDSOURCE,LAT_DD,LEGNO,LEGSTAGE,LEGTYPE,LONG_DD,MONTH,NUMBER,NUMCALF,PHOTOS,PLATFORM,,,,SIGHTNO,SPECCODE,,,,TAXCODE,TIME,VISIBLTY,WX,YEAR,,";
    
    
    methods (Static)
        function fields = getAll()
            % GETALL Get all field definitions
            % Returns: Cell array with columns: {Name, Type, Description}
            fields = {
                % Field Name    Type        Description
                'ALT',          'double',   'Altitude in meters';
                'EVENTNO',      'double',   'Event number';
                'LAT_DD',       'double',   'Latitude (decimal degrees)';
                'LONG_DD',      'double',   'Longitude (decimal degrees)';
                'MONTH',        'double',   'Month (1-12)';
                'TIME',         'double',   'Time of observation (HHMMSS)';
                'YEAR',         'double',   'Year';
                'DAY',          'double',   'Day of month (1-31)';
                'SURFTEMP',     'double',   'Surface temperature';
                'ANHEAD',       'double',   'Angle to head';
                'BEHAV1',       'double',   'Behavior code 1';
                'BEHAV2',       'double',   'Behavior code 2';
                'BEHAV3',       'double',   'Behavior code 3';
                'BEHAV4',       'double',   'Behavior code 4';
                'BEHAV5',       'double',   'Behavior code 5';
                'BEHAV6',       'double',   'Behavior code 6';
                'BEHAV7',       'double',   'Behavior code 7';
                'BEHAV8',       'double',   'Behavior code 8';
                'BEHAV9',       'double',   'Behavior code 9';
                'BEHAV10',      'double',   'Behavior code 10';
                'BEHAV11',      'double',   'Behavior code 11';
                'BEHAV12',      'double',   'Behavior code 12';
                'BEHAV13',      'double',   'Behavior code 13';
                'BEHAV14',      'double',   'Behavior code 14';
                'BEHAV15',      'double',   'Behavior code 15';
                'CONFIDNC',     'double',   'Confidence level';
                'IDREL',        'double',   'ID reliability';
                'NUMBER',       'double',   'Number of animals';
                'NUMCALF',      'double',   'Number of calves';
                'PHOTOS',       'double',   'Number of photos';
                'SIGHTNO',      'double',   'Sighting number';
                'SPECCODE',     'string',   'Species code';
                'STRIP',        'double',   'Strip number';
                'S_LAT',        'double',   'Starting latitude';
                'S_LONG',       'double',   'Starting longitude';
                'S_TIME',       'double',   'Starting time';
                'TAXCODE',      'double',   'Taxonomic code';
                'PLATFORM',     'double',   'Platform code';
                'BLOCK',        'string',   'Survey block identifier';
                'DDSOURCE',     'string',   'Data source code';
                'FILEID',       'string',   'File/Survey identifier';
                'IDSOURCE',     'string',   'ID source';
                'STRATUM',      'string',   'Survey stratum';
                'LEGNO',        'double',   'Leg number';
                'BEAUFORT',     'double',   'Beaufort sea state (0-9)';
                'CLOUD',        'double',   'Cloud cover (0-10)';
                'GLAREL',       'double',   'Glare level left';
                'GLARER',       'double',   'Glare level right';
                'HEADING',      'double',   'Ship/aircraft heading (degrees)';
                'LEGSTAGE',     'double',   'Leg stage';
                'LEGTYPE',      'double',   'Leg type';
                'VISIBLTY',     'double',   'Visibility';
                'WX',           'string',   'Weather code';
                'ANGLEL',       'double',   'Angle left of trackline';
                'ANGLER',       'double',   'Angle right of trackline';
            };
        end
        
        
        function names = getFieldNames()
            % GETFIELDNAMES Get ordered list of field names
            fields = narwc.db.FieldDefinitions.getAll();
            names = fields(:, 1);
        end
        
        function is_numeric = isNumeric(field_name)
            % ISNUMERIC Check if field is numeric
            fields = narwc.db.FieldDefinitions.getAll();
            idx = find(strcmp(fields(:,1), field_name), 1);
            if ~isempty(idx)
                is_numeric = strcmp(fields{idx, 2}, 'double');
            else
                is_numeric = false;
            end
        end
        
        function type = getType(field_name)
            % GETTYPE Get type of field
            fields = narwc.db.FieldDefinitions.getAll();
            idx = find(strcmp(fields(:,1), field_name), 1);
            if ~isempty(idx)
                type = fields{idx, 2};
            else
                type = '';
            end
        end
        
        function string_fields = getStringFields()
            % GETSTRINGFIELDS Get list of string field names
            fields = narwc.db.FieldDefinitions.getAll();
            string_mask = strcmp(fields(:,2), 'string');
            string_fields = fields(string_mask, 1);
        end
        
        function numeric_fields = getNumericFields()
            % GETNUMERICFIELDS Get list of numeric field names
            fields = narwc.db.FieldDefinitions.getAll();
            numeric_mask = strcmp(fields(:,2), 'double');
            numeric_fields = fields(numeric_mask, 1);
        end
        
        function var_types = getVariableTypes()
            % GETVARIABLETYPES Get variable types in field order
            fields = narwc.db.FieldDefinitions.getAll();
            var_types = fields(:, 2)';
        end

        function db_order = getDatabaseOrder()
            % GETDATABASEORDER Get field names in database order
            fields = narwc.db.FieldDefinitions.getAll();
            db_order = fields(:,1)';
        end
    end
end