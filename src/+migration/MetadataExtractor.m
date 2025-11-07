classdef MetadataExtractor < handle
    % METADATAEXTRACTOR Extract metadata from surveys
    %
    % Usage:
    %   extractor = migration.MetadataExtractor();
    %   metadata = extractor.extract(survey_data);
    
    properties (Access = private)
        logger
    end
    
    methods
        function obj = MetadataExtractor()
            obj.logger = logging.Logger('migration.MetadataExtractor');
        end
        
        function metadata = extract(obj, survey_data)
            % EXTRACT Extract metadata from survey data
            %
            % Inputs:
            %   survey_data - Table with survey records
            %
            % Outputs:
            %   metadata - Struct with survey metadata
            
            metadata = struct();
            
            % Basic info
            if ismember('FILEID', survey_data.Properties.VariableNames)
                metadata.fileid = unique(survey_data.FILEID);
                if iscell(metadata.fileid)
                    metadata.fileid = metadata.fileid{1};
                end
            else
                metadata.fileid = 'UNKNOWN';
            end
            
            % Record count
            metadata.record_count = height(survey_data);
            
            % Date range
            if ismember('YEAR', survey_data.Properties.VariableNames)
                metadata.year = unique(survey_data.YEAR);
                if length(metadata.year) == 1
                    metadata.year = metadata.year(1);
                end
            end
            
            if ismember('MONTH', survey_data.Properties.VariableNames)
                metadata.months = unique(survey_data.MONTH(~isnan(survey_data.MONTH)));
            end
            
            if ismember('DAY', survey_data.Properties.VariableNames)
                metadata.days = unique(survey_data.DAY(~isnan(survey_data.DAY)));
            end
            
            % Geographic range
            if ismember('LAT_DD', survey_data.Properties.VariableNames)
                valid_lat = survey_data.LAT_DD(~isnan(survey_data.LAT_DD));
                if ~isempty(valid_lat)
                    metadata.lat_min = min(valid_lat);
                    metadata.lat_max = max(valid_lat);
                end
            end
            
            if ismember('LONG_DD', survey_data.Properties.VariableNames)
                valid_lon = survey_data.LONG_DD(~isnan(survey_data.LONG_DD));
                if ~isempty(valid_lon)
                    metadata.lon_min = min(valid_lon);
                    metadata.lon_max = max(valid_lon);
                end
            end
            
            % Species
            if ismember('SPECCODE', survey_data.Properties.VariableNames)
                metadata.species = unique(survey_data.SPECCODE(~cellfun(@isempty, survey_data.SPECCODE)));
            end
            
            % Platform
            if ismember('PLATFORM', survey_data.Properties.VariableNames)
                metadata.platform = unique(survey_data.PLATFORM(~isnan(survey_data.PLATFORM)));
            end
            
            % Data source
            if ismember('DDSOURCE', survey_data.Properties.VariableNames)
                metadata.source = unique(survey_data.DDSOURCE(~cellfun(@isempty, survey_data.DDSOURCE)));
                if iscell(metadata.source)
                    metadata.source = metadata.source{1};
                end
            end
            
            % Sighting count (non-zero NUMBER)
            if ismember('NUMBER', survey_data.Properties.VariableNames)
                metadata.sighting_count = sum(survey_data.NUMBER > 0);
            end
            
            obj.logger.debug(sprintf('Extracted metadata for %s', metadata.fileid));
        end
        
        function metadata_table = extractAll(obj, extractor)
            % EXTRACTALL Extract metadata for all surveys
            %
            % Inputs:
            %   extractor - SurveyExtractor instance
            %
            % Outputs:
            %   metadata_table - Table with metadata for all surveys
            
            survey_ids = extractor.listSurveys();
            
            % Initialize output
            metadata_list = cell(length(survey_ids), 1);
            
            obj.logger.info(sprintf('Extracting metadata for %d surveys', length(survey_ids)));
            
            for i = 1:length(survey_ids)
                try
                    survey_data = extractor.extract(survey_ids{i});
                    metadata_list{i} = obj.extract(survey_data);
                catch ME
                    obj.logger.error(sprintf('Failed to extract metadata for %s: %s', ...
                        survey_ids{i}, ME.message));
                    metadata_list{i} = struct('fileid', survey_ids{i}, 'error', ME.message);
                end
            end
            
            % Convert to table
            metadata_table = struct2table(vertcat(metadata_list{:}));
            
            obj.logger.info('Metadata extraction complete');
        end
    end
end