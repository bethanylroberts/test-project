classdef SummaryStatistics < handle
    % SUMMARYSTATISTICS Generate survey summary statistics (Markdown)
    %
    % Usage:
    %   report = narwc.reports.SummaryStatistics(survey_data, survey_id);
    %   report.generate('summary.md');

    % NOTE: only used by test_reports
    
    properties (Access = private)
        data
        survey_id
        stats
    end
    
    methods
        function obj = SummaryStatistics(survey_data, survey_id)
            % SUMMARYSTATISTICS Constructor
            
            obj.data = survey_data;
            
            if nargin > 1
                obj.survey_id = survey_id;
            else
                obj.survey_id = 'Unknown';
            end
            
            obj.calculateStats();
        end
        
        function calculateStats(obj)
            % CALCULATESTATS Calculate summary statistics
            
            obj.stats = struct();
            
            % Basic counts
            obj.stats.total_records = height(obj.data);
            
            % Temporal coverage
            if ismember('YEAR', obj.data.Properties.VariableNames)
                years = obj.data.YEAR(~isnan(obj.data.YEAR));
                if ~isempty(years)
                    obj.stats.year_range = [min(years), max(years)];
                    obj.stats.years = unique(years);
                end
            end
            
            if ismember('MONTH', obj.data.Properties.VariableNames)
                months = obj.data.MONTH(~isnan(obj.data.MONTH));
                if ~isempty(months)
                    obj.stats.months = unique(months);
                end
            end
            
            % Spatial coverage
            if ismember('LAT_DD', obj.data.Properties.VariableNames)
                lat = obj.data.LAT_DD(~isnan(obj.data.LAT_DD));
                if ~isempty(lat)
                    obj.stats.lat_range = [min(lat), max(lat)];
                end
            end
            
            if ismember('LONG_DD', obj.data.Properties.VariableNames)
                lon = obj.data.LONG_DD(~isnan(obj.data.LONG_DD));
                if ~isempty(lon)
                    obj.stats.lon_range = [min(lon), max(lon)];
                end
            end
            
            % Species counts
            if ismember('SPECCODE', obj.data.Properties.VariableNames)
                species = obj.data.SPECCODE(~cellfun(@isempty, obj.data.SPECCODE));
                if ~isempty(species)
                    [unique_species, ~, idx] = unique(species);
                    counts = accumarray(idx, 1);
                    obj.stats.species = containers.Map(unique_species, num2cell(counts));
                end
            end
            
            % Sighting count
            if ismember('NUMBER', obj.data.Properties.VariableNames)
                sightings = obj.data.NUMBER > 0;
                obj.stats.sightings = sum(sightings);
                obj.stats.total_animals = sum(obj.data.NUMBER(~isnan(obj.data.NUMBER)));
            end
            
            % Platform
            if ismember('PLATFORM', obj.data.Properties.VariableNames)
                platforms = obj.data.PLATFORM(~isnan(obj.data.PLATFORM));
                if ~isempty(platforms)
                    obj.stats.platforms = unique(platforms);
                end
            end
            
            % Data source
            if ismember('DDSOURCE', obj.data.Properties.VariableNames)
                sources = obj.data.DDSOURCE(~cellfun(@isempty, obj.data.DDSOURCE));
                if ~isempty(sources)
                    obj.stats.sources = unique(sources);
                end
            end
        end
        
        function generate(obj, output_file)
            % GENERATE Generate summary report
            
            % Create output directory
            output_dir = fileparts(output_file);
            if ~isempty(output_dir) && ~exist(output_dir, 'dir')
                mkdir(output_dir);
            end
            
            % Generate markdown
            content = obj.generateMarkdown();
            
            % Write to file
            fid = fopen(output_file, 'w');
            fprintf(fid, '%s', content);
            fclose(fid);
            
            fprintf('Summary report generated: %s\n', output_file);
        end
        
        function md = generateMarkdown(obj)
            % GENERATEMARKDOWN Generate markdown report
            
            md = sprintf('# Survey Summary Statistics\n\n');
            md = [md sprintf('**Survey:** %s  \n', obj.survey_id)];
            md = [md sprintf('**Generated:** %s  \n\n', char(datetime('now')))];
            md = [md sprintf('---\n\n')];
            
            % Basic statistics
            md = [md sprintf('## Overview\n\n')];
            md = [md sprintf('- **Total Records:** %d\n', obj.stats.total_records)];
            
            if isfield(obj.stats, 'sightings')
                md = [md sprintf('- **Sightings:** %d\n', obj.stats.sightings)];
                md = [md sprintf('- **Total Animals:** %d\n', obj.stats.total_animals)];
            end
            
            md = [md sprintf('\n')];
            
            % Temporal coverage
            if isfield(obj.stats, 'year_range')
                md = [md sprintf('## Temporal Coverage\n\n')];
                md = [md sprintf('- **Year Range:** %d - %d\n', ...
                    obj.stats.year_range(1), obj.stats.year_range(2))];
                
                if isfield(obj.stats, 'months')
                    month_names = {'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', ...
                                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'};
                    months_str = strjoin(month_names(obj.stats.months), ', ');
                    md = [md sprintf('- **Months:** %s\n', months_str)];
                end
                
                md = [md sprintf('\n')];
            end
            
            % Spatial coverage
            if isfield(obj.stats, 'lat_range')
                md = [md sprintf('## Spatial Coverage\n\n')];
                md = [md sprintf('- **Latitude Range:** %.4f° to %.4f°\n', ...
                    obj.stats.lat_range(1), obj.stats.lat_range(2))];
                md = [md sprintf('- **Longitude Range:** %.4f° to %.4f°\n', ...
                    obj.stats.lon_range(1), obj.stats.lon_range(2))];
                md = [md sprintf('\n')];
            end
            
            % Species composition
            if isfield(obj.stats, 'species')
                md = [md sprintf('## Species Composition\n\n')];
                md = [md sprintf('| Species | Sightings |\n')];
                md = [md sprintf('|---------|----------|\n')];
                
                species_list = keys(obj.stats.species);
                counts = cell2mat(values(obj.stats.species));
                [counts, sort_idx] = sort(counts, 'descend');
                species_list = species_list(sort_idx);
                
                for i = 1:length(species_list)
                    md = [md sprintf('| %s | %d |\n', species_list{i}, counts(i))];
                end
                
                md = [md sprintf('\n')];
            end
            
            % Platform
            if isfield(obj.stats, 'platforms')
                md = [md sprintf('## Survey Platform\n\n')];
                platforms_str = strjoin(arrayfun(@num2str, obj.stats.platforms, ...
                    'UniformOutput', false), ', ');
                md = [md sprintf('- **Platform(s):** %s\n\n', platforms_str)];
            end
            
            % Data source
            if isfield(obj.stats, 'sources')
                md = [md sprintf('## Data Source\n\n')];
                sources_str = strjoin(obj.stats.sources, ', ');
                md = [md sprintf('- **Source(s):** %s\n\n', sources_str)];
            end
            
            md = [md sprintf('---\n\n')];
            md = [md sprintf('*Report generated by NARWC Database System*\n')];
        end
    end
end