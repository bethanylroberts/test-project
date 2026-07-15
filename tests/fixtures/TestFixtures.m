classdef TestFixtures
    % TESTFIXTURES Helper class for loading test fixtures
    %
    % Usage:
    %   data = TestFixtures.load('sample_survey.csv');
    %   config = TestFixtures.config('test_db_config');
    %   TestFixtures.cleanup('test_survey');
    
    methods (Static)
        function data = load(filename)
            % LOAD Load a test fixture file
            %
            % Example:
            %   data = TestFixtures.load('sample_survey.csv');
            
            fixture_dir = fileparts(mfilename('fullpath'));
            filepath = fullfile(fixture_dir, 'sample_data', filename);
            
            if ~exist(filepath, 'file')
                error('Fixture file not found: %s', filename);
            end
            
            [~, ~, ext] = fileparts(filename);
            
            switch lower(ext)
                case '.csv'
                    data = readtable(filepath, 'Delimiter', ',');
                case '.txt'
                    data = readtable(filepath, 'Delimiter', '\t');
                case '.xlsx'
                    data = readtable(filepath);
                case '.mat'
                    loaded = load(filepath);
                    fields = fieldnames(loaded);
                    data = loaded.(fields{1});
                otherwise
                    error('Unsupported file type: %s', ext);
            end
        end
        
        function expected = expected_output(filename)
            % EXPECTED_OUTPUT Load expected output for comparison
            %
            % Example:
            %   expected = TestFixtures.expected_output('parsed_survey.mat');
            
            fixture_dir = fileparts(mfilename('fullpath'));
            filepath = fullfile(fixture_dir, 'expected_outputs', filename);
            
            if ~exist(filepath, 'file')
                error('Expected output file not found: %s', filename);
            end
            
            loaded = load(filepath);
            fields = fieldnames(loaded);
            expected = loaded.(fields{1});
        end
        
        function data = generate_mock_survey(num_records)
            % GENERATE_MOCK_SURVEY Generate mock survey data for testing
            %
            % Example:
            %   data = TestFixtures.generate_mock_survey(100);

            % TODO: add options for sighting and non-sighting
            % TODO: add options for different survey types 
            
            if nargin < 1
                num_records = 10;
            end
            
            data = table();
            
            % === Required Fields (NOT NULL constraints) ===
            data.DDSOURCE = repmat({'NEA'}, num_records, 1);  % New England Aquarium
            data.EVENTNO = (1:num_records)';  % Required
            data.FILEID = repmat({'TEST001'}, num_records, 1);  % Required
            data.IDSOURCE = repmat({'NEA'}, num_records, 1);  % New England Aquarium
            
            % === Temporal Fields ===
            data.YEAR = repmat(2024, num_records, 1);  % Required
            data.MONTH = randi([5, 9], num_records, 1);  % May-September
            data.DAY = randi([1, 28], num_records, 1);
            % Fix TIME to ensure valid HHMMSS format
            hours = randi([6, 18], num_records, 1);  % 06:00 to 18:00
            minutes = randi([0, 59], num_records, 1);
            seconds = randi([0, 59], num_records, 1);
            data.TIME = hours * 10000 + minutes * 100 + seconds;
            data.S_TIME = max(data.TIME - randi([60, 3600], num_records, 1), 0);  % Start time before
            
            % === Position Fields ===
            % Keep within survey area to avoid warnings
            data.LAT_DD = 37 + rand(num_records, 1) * 8;  % 37-45°N (within survey area)
            data.LONG_DD = -73 - rand(num_records, 1) * 2;  % 73-75°W (within survey area)
            data.S_LAT = data.LAT_DD - rand(num_records, 1) * 0.05;
            data.S_LONG = data.LONG_DD + rand(num_records, 1) * 0.05;
            
            % === Platform/Survey Fields ===
            data.ALT = randi([200, 300], num_records, 1);  % Altitude in feet
            valid_platforms = [625, 626, 627, 628, 629, 630, 631, 632, 633];  % FIXME: add more platforms
            data.PLATFORM = valid_platforms(randi([1, length(valid_platforms)], num_records, 1))';
            data.HEADING = rand(num_records, 1) * 360;  % 0-360 degrees
            data.LEGNO = randi([1, 5], num_records, 1);
            data.LEGTYPE = randi([1, 3], num_records, 1);
            data.LEGSTAGE = randi([1, 3], num_records, 1);
            data.SIGHTNO = (1:num_records)';
            
            % === Sighting Fields ===
            data.SPECCODE = repmat({'RIWH'}, num_records, 1);  % Right whale
            data.TAXCODE = repmat(1, num_records, 1);  % Cetacean
            data.NUMBER = randi([1, 5], num_records, 1);  % Group size
            data.NUMCALF = zeros(num_records, 1);  % Most sightings without calves
            % Add some calves to a few sightings
            calf_idx = randi([0, 1], num_records, 1) == 1;
            data.NUMCALF(calf_idx) = min(data.NUMBER(calf_idx), randi([1, 2], sum(calf_idx), 1));
            
            % === Observation Quality Fields ===
            data.CONFIDNC = randi([1, 3], num_records, 1);  % ID confidence
            data.IDREL = randi([1, 3], num_records, 1);  % ID reliability
            data.PHOTOS = randi([1, 2], num_records, 1);  % Photos: 1=NO, 2=YES (not 0)

            
            % === Angle/Distance Fields ===
            data.ANGLEL = randi([0, 90], num_records, 1);  % Left angle
            data.ANGLER = randi([0, 90], num_records, 1);  % Right angle
            data.ANHEAD = randi([1, 8], num_records, 1);  % Animal heading (compass)
            
            % === Environmental Fields ===
            data.BEAUFORT = randi([0, 5], num_records, 1);  % Sea state (0-5 is good surveying)
            valid_cloud = [0, 1, 2, 3, 4, 9];  % Valid cloud cover codes
            data.CLOUD = valid_cloud(randi([1, length(valid_cloud)], num_records, 1))';
            data.GLAREL = randi([0, 2], num_records, 1);  % Left glare
            data.GLARER = randi([0, 2], num_records, 1);  % Right glare
            data.VISIBLTY = 5 + rand(num_records, 1) * 15;  % Visibility 5-20 km
            data.SURFTEMP = 10 + rand(num_records, 1) * 15;  % Surface temp 10-25°C
            data.WX = repmat({'C'}, num_records, 1);  % Weather: Clear
            

            % === Behavior Fields (BEHAV1-BEHAV15) ===
            % Leave empty for mock data - behavioral validation requires specific valid codes
            for i = 1:15
                field_name = sprintf('BEHAV%d', i);
                data.(field_name) = NaN(num_records, 1);
            end            
            
            % Add some behaviors to a subset of sightings
            behav_idx = randi([0, 1], num_records, 1) == 1;
            data.BEHAV1(behav_idx) = randi([1, 10], sum(behav_idx), 1);  % Primary behavior
            
            % === Survey Design Fields ===
            data.BLOCK = repmat({'A'}, num_records, 1);  % CETAP aerial survey block
            data.STRATUM = repmat({'0'}, num_records, 1);  % Non-stratified
            data.STRIP = randi([1, 16], num_records, 1);  % Valid strip values 1-16
            
            % === Reorder columns to match typical order ===
            % Put key fields first
            key_fields = {'FILEID', 'EVENTNO', 'SIGHTNO', 'YEAR', 'MONTH', 'DAY', 'TIME', ...
                        'LAT_DD', 'LONG_DD', 'SPECCODE', 'NUMBER', 'NUMCALF'};
            
            other_fields = setdiff(data.Properties.VariableNames, key_fields, 'stable');
            data = data(:, [key_fields, other_fields]);
        end
        
        function save_fixture(data, filename)
            % SAVE_FIXTURE Save data as a test fixture
            %
            % Example:
            %   TestFixtures.save_fixture(data, 'sample_survey.mat');
            
            fixture_dir = fileparts(mfilename('fullpath'));
            filepath = fullfile(fixture_dir, 'sample_data', filename);
            
            save(filepath, 'data');
        end
        
        function cleanup(pattern)
            % CLEANUP Remove test data from database
            %
            % Example:
            %   TestFixtures.cleanup('TEST%');  % Remove all TEST* FILEIDs
            
            try
                conn = narwc.db.Connection.create();
                query = sprintf("DELETE FROM Master WHERE FILEID LIKE '%s'", pattern);
                conn.execute(query);
                fprintf('Cleaned up test data: %s\n', pattern);
                conn.close();
            catch ME
                warning('Cleanup failed: %s', ME.message);
            end
        end
    end
end