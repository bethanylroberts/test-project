classdef (Abstract) BaseParser < handle
    % BASEPARSER Abstract base class for all survey format parsers
    
    properties (Access = protected)
        file_path
        logger
    end
    
    properties (Abstract, Constant)
        FORMAT_NAME
        DESCRIPTION
    end
    
    methods
        function obj = BaseParser(file_path)
            obj.file_path = file_path;
            obj.logger = logging.Logger(sprintf('narwc.io.parsers.%s', class(obj)));
            
            if ~exist(file_path, 'file')
                error('File not found: %s', file_path);
            end
        end
        
        function [data, metadata] = read(obj)
            obj.logger.info(sprintf('Parsing file: %s', obj.file_path));
            
            try
                [data, metadata] = obj.parse();
                data = obj.standardize(data);
                
                metadata.file_path = obj.file_path;
                metadata.format = obj.FORMAT_NAME;
                metadata.parse_time = datetime('now');
                
                obj.logger.info(sprintf('Successfully parsed %d records', height(data)));
                
            catch ME
                obj.logger.error(sprintf('Parse failed: %s', ME.message));
                rethrow(ME);
            end
        end
        
        function standardized = standardize(obj, data)
            standardized = data;
            required_fields = narwc.io.parsers.BaseParser.getStandardFieldsStatic();
            
            for i = 1:length(required_fields)
                field = required_fields{i};
                if ~ismember(field, standardized.Properties.VariableNames)
                    if narwc.io.parsers.BaseParser.isNumericField(field)
                        standardized.(field) = nan(height(standardized), 1);
                    else
                        standardized.(field) = repmat({''}, height(standardized), 1);
                    end
                    obj.logger.debug(sprintf('Added missing field: %s', field));
                end
            end
            
            standardized = standardized(:, required_fields);
        end
    end
    
    methods (Abstract)
        [data, metadata] = parse(obj)
    end
    
    methods (Static, Abstract)
        confidence = detectFormat(file_path)
    end
    
    methods (Static)
        function fields = getStandardFieldsStatic()
            fields = cell(55, 1);
            fields{1} = 'ALT';
            fields{2} = 'ANGLEL';
            fields{3} = 'ANGLER';
            fields{4} = 'ANHEAD';
            fields{5} = 'BEAUFORT';
            fields{6} = 'BEHAV1';
            fields{7} = 'BEHAV2';
            fields{8} = 'BEHAV3';
            fields{9} = 'BEHAV4';
            fields{10} = 'BEHAV5';
            fields{11} = 'BEHAV6';
            fields{12} = 'BEHAV7';
            fields{13} = 'BEHAV8';
            fields{14} = 'BEHAV9';
            fields{15} = 'BEHAV10';
            fields{16} = 'BEHAV11';
            fields{17} = 'BEHAV12';
            fields{18} = 'BEHAV13';
            fields{19} = 'BEHAV14';
            fields{20} = 'BEHAV15';
            fields{21} = 'BLOCK';
            fields{22} = 'CLOUD';
            fields{23} = 'CONFIDNC';
            fields{24} = 'DAY';
            fields{25} = 'DDSOURCE';
            fields{26} = 'EVENTNO';
            fields{27} = 'FILEID';
            fields{28} = 'GLAREL';
            fields{29} = 'GLARER';
            fields{30} = 'HEADING';
            fields{31} = 'IDREL';
            fields{32} = 'IDSOURCE';
            fields{33} = 'LAT_DD';
            fields{34} = 'LEGNO';
            fields{35} = 'LEGSTAGE';
            fields{36} = 'LEGTYPE';
            fields{37} = 'LONG_DD';
            fields{38} = 'MONTH';
            fields{39} = 'NUMBER';
            fields{40} = 'NUMCALF';
            fields{41} = 'PHOTOS';
            fields{42} = 'PLATFORM';
            fields{43} = 'S_LAT';
            fields{44} = 'S_LONG';
            fields{45} = 'S_TIME';
            fields{46} = 'SIGHTNO';
            fields{47} = 'SPECCODE';
            fields{48} = 'STRATUM';
            fields{49} = 'STRIP';
            fields{50} = 'SURFTEMP';
            fields{51} = 'TAXCODE';
            fields{52} = 'TIME';
            fields{53} = 'VISIBLTY';
            fields{54} = 'WX';
            fields{55} = 'YEAR';
        end
        
        function is_numeric = isNumericField(field_name)
            numeric_list = {'ALT', 'ANGLEL', 'ANGLER', 'ANHEAD', 'BEAUFORT', ...
                'BEHAV1', 'BEHAV2', 'BEHAV3', 'BEHAV4', 'BEHAV5', ...
                'BEHAV6', 'BEHAV7', 'BEHAV8', 'BEHAV9', 'BEHAV10', ...
                'BEHAV11', 'BEHAV12', 'BEHAV13', 'BEHAV14', 'BEHAV15', ...
                'CLOUD', 'CONFIDNC', 'DAY', 'EVENTNO', 'GLAREL', 'GLARER', ...
                'HEADING', 'IDREL', 'LAT_DD', 'LEGNO', 'LEGSTAGE', ...
                'LEGTYPE', 'LONG_DD', 'MONTH', 'NUMBER', 'NUMCALF', ...
                'PHOTOS', 'PLATFORM', 'S_LAT', 'S_LONG', 'SIGHTNO', ...
                'SURFTEMP', 'TAXCODE', 'VISIBLTY', 'YEAR'};
            
            is_numeric = ismember(field_name, numeric_list);
        end
    end
end