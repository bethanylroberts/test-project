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
            
            if nargin < 1
                num_records = 10;
            end

            % FIXME: this format is not correct
            
            data = table();
            data.ALT = randi([200, 300], num_records, 1);
            data.BEAUFORT = randi([0, 5], num_records, 1);
            data.LAT_DD = 40 + rand(num_records, 1) * 5;
            data.LONG_DD = -72 - rand(num_records, 1) * 5;
            data.YEAR = repmat(2024, num_records, 1);
            data.MONTH = randi([1, 12], num_records, 1);
            data.DAY = randi([1, 28], num_records, 1);
            data.EVENTNO = (1:num_records)';
            data.FILEID = repmat({'TEST001'}, num_records, 1);
            data.DDSOURCE = repmat({'TEST'}, num_records, 1);
            data.SPECCODE = repmat({'RIWH'}, num_records, 1);
            data.NUMBER = randi([1, 5], num_records, 1);
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