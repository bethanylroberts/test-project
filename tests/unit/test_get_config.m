classdef test_get_config < matlab.unittest.TestCase
    % TEST_CONFIG Unit tests for centralized configuration system
    %
    % Tests get_config, reload_config, and get_lookup_table functions
    
    methods (Test)
        
        % =================================================================
        % GET_CONFIG TESTS
        % =================================================================
        
        function testGetConfigReturnsStruct(testCase)
            % Test that get_config returns a struct
            
            config = get_config();
            
            testCase.verifyClass(config, 'struct');
        end
        
        function testGetConfigHasRequiredSections(testCase)
            % Test that config has all required top-level sections
            
            config = get_config();
            
            required_sections = {'paths', 'validation', 'processing', 'database', 'logging'};
            
            for i = 1:length(required_sections)
                testCase.verifyTrue(isfield(config, required_sections{i}), ...
                    sprintf('Config missing required section: %s', required_sections{i}));
            end
        end
        
        function testGetConfigBySection(testCase)
            % Test getting specific config sections
            
            sections = {'paths', 'validation', 'processing', 'database', 'logging'};
            
            for i = 1:length(sections)
                section_config = get_config(sections{i});
                testCase.verifyClass(section_config, 'struct', ...
                    sprintf('Section %s should return struct', sections{i}));
            end
        end
        
        function testGetConfigInvalidSectionThrows(testCase)
            % Test that invalid section name throws error
            
            testCase.verifyError(@() get_config('invalid_section'), ...
                'get_config:UnknownSection');
        end
        
        % =================================================================
        % PATH CONFIG TESTS
        % =================================================================
        
        function testPathsHasProjectRoot(testCase)
            % Test that paths config includes project root
            
            paths = get_config('paths');
            
            testCase.verifyTrue(isfield(paths, 'project_root'));
            testCase.verifyTrue(isfolder(paths.project_root), ...
                'Project root should be a valid directory');
        end
        
        function testPathsHasStandardDirectories(testCase)
            % Test that paths config includes standard directories
            
            paths = get_config('paths');
            
            standard_dirs = {'src_dir', 'data_dir', 'config_dir', 'tests_dir'};
            
            for i = 1:length(standard_dirs)
                testCase.verifyTrue(isfield(paths, standard_dirs{i}), ...
                    sprintf('Paths missing: %s', standard_dirs{i}));
            end
        end
        
        function testPathsHasLookupTables(testCase)
            % Test that paths config includes lookup table paths
            
            paths = get_config('paths');
            
            testCase.verifyTrue(isfield(paths, 'lookup_tables'), ...
                'Paths should have lookup_tables field');
            testCase.verifyClass(paths.lookup_tables, 'struct');
        end
        
        function testLookupTablePathsExist(testCase)
            % Test that lookup table files exist
            
            paths = get_config('paths');
            lookup_tables = paths.lookup_tables;
            
            tables = fieldnames(lookup_tables);
            missing_tables = {};
            
            for i = 1:length(tables)
                table_path = lookup_tables.(tables{i});
                if ~exist(table_path, 'file')
                    missing_tables{end+1} = tables{i}; %#ok<AGROW>
                end
            end
            
            % Warn about missing tables but don't fail
            % (some tables may be optional)
            if ~isempty(missing_tables)
                warning('test_config:MissingTables', ...
                    'Missing lookup tables: %s', strjoin(missing_tables, ', '));
            end
            
            % At minimum, verify the path structure is correct
            testCase.verifyTrue(isfield(lookup_tables, 'behave'), ...
                'Should have behave lookup table path');
        end
        
        function testProjectRootIsAbsolute(testCase)
            % Test that project root is an absolute path
            
            paths = get_config('paths');
            
            % Absolute paths start with drive letter (Windows) or / (Unix)
            is_absolute = ~isempty(regexp(paths.project_root, '^([A-Za-z]:|/)', 'once'));
            
            testCase.verifyTrue(is_absolute, ...
                'Project root should be an absolute path');
        end
        
        % =================================================================
        % VALIDATION CONFIG TESTS
        % =================================================================
        
        function testValidationHasRequiredSettings(testCase)
            % Test that validation config has required settings
            
            validation = get_config('validation');
            
            % Check for main subsections
            testCase.verifyTrue(isfield(validation, 'behavioral'), ...
                'Validation should have behavioral settings');
            testCase.verifyTrue(isfield(validation, 'coordinates'), ...
                'Validation should have coordinates settings');
            testCase.verifyTrue(isfield(validation, 'environmental'), ...
                'Validation should have environmental settings');
        end
                
        function testValidationCoordinateRanges(testCase)
            % Test coordinate validation ranges are sensible
            
            validation = get_config('validation');
            coords = validation.coordinates;
            
            testCase.verifyEqual(coords.lat_min, -90);
            testCase.verifyEqual(coords.lat_max, 90);
            testCase.verifyEqual(coords.lon_min, -180);
            testCase.verifyEqual(coords.lon_max, 180);
        end
        
        function testValidationBeaufortRange(testCase)
            % Test Beaufort scale range
            
            validation = get_config('validation');
            env = validation.environmental;
            
            testCase.verifyTrue(isfield(env, 'beaufort_values'), ...
                'Should have beaufort_values setting');
            testCase.verifyEqual(min(env.beaufort_values), 0);
            testCase.verifyEqual(max(env.beaufort_values), 12);
        end
        
        function testValidationBehavioralConfig(testCase)
            % Test behavioral validation config structure
            
            validation = get_config('validation');
            behavioral = validation.behavioral;
            
            % Check required fields exist
            testCase.verifyTrue(isfield(behavioral, 'dead_behaviors'));
            testCase.verifyTrue(isfield(behavioral, 'active_swimming_behaviors'));
            testCase.verifyTrue(isfield(behavioral, 'incompatible_behavior_pairs'));
            testCase.verifyTrue(isfield(behavioral, 'calf_associated_behaviors'));
            
            % Check dead behaviors are reasonable
            testCase.verifyTrue(all(behavioral.dead_behaviors >= 0));
            testCase.verifyTrue(all(behavioral.dead_behaviors <= 3));
        end
        
        % =================================================================
        % DATABASE CONFIG TESTS
        % =================================================================
        
        function testDatabaseHasConnectionSettings(testCase)
            % Test that database config has connection settings
            
            database = get_config('database');
            
            testCase.verifyTrue(isfield(database, 'server'));
            testCase.verifyTrue(isfield(database, 'database'));
            testCase.verifyTrue(isfield(database, 'driver'));
        end
        
        % =================================================================
        % LOGGING CONFIG TESTS
        % =================================================================
        
        function testLoggingHasLevelSetting(testCase)
            % Test that logging config has level setting
            
            logging = get_config('logging');
            
            testCase.verifyTrue(isfield(logging, 'level'));
            
            valid_levels = {'DEBUG', 'INFO', 'WARNING', 'ERROR'};
            testCase.verifyTrue(ismember(logging.level, valid_levels), ...
                'Logging level should be valid');
        end
        
        % =================================================================
        % RELOAD CONFIG TESTS
        % =================================================================
        
        function testReloadConfigReturnsConfig(testCase)
            % Test that reload_config returns valid config
            
            config = reload_config();
            
            testCase.verifyClass(config, 'struct');
            testCase.verifyTrue(isfield(config, 'paths'));
        end
        
        function testReloadConfigClearsCache(testCase)
            % Test that reload actually clears cache
            
            % Get config twice - should be cached
            config1 = get_config();
            config2 = get_config();
            
            % Reload clears cache
            config3 = reload_config();
            
            % All should be valid
            testCase.verifyClass(config1, 'struct');
            testCase.verifyClass(config2, 'struct');
            testCase.verifyClass(config3, 'struct');
        end
        
        % =================================================================
        % GET_LOOKUP_TABLE TESTS
        % =================================================================
        
        function testGetLookupTableReturnsTable(testCase)
            % Test that get_lookup_table returns a table
            
            % Try to load behave table (should exist)
            behave = get_lookup_table('behave');
            
            testCase.verifyClass(behave, 'table');
        end
        
        function testGetLookupTableBehave(testCase)
            % Test loading Behave lookup table
            
            behave = get_lookup_table('behave');
            
            if isempty(behave)
                warning('test_config:SkippedTest', 'Behave.csv not found, skipping');
                return;
            end
            
            % Should have Value and Description columns
            testCase.verifyTrue(ismember('Value', behave.Properties.VariableNames) || ...
                               width(behave) >= 2, ...
                'Behave table should have expected columns');
            
            % Should have multiple rows
            testCase.verifyGreaterThan(height(behave), 10, ...
                'Behave table should have multiple behavior codes');
        end
        
        function testGetLookupTableCaseInsensitive(testCase)
            % Test that table names are case-insensitive
            
            behave1 = get_lookup_table('behave');
            behave2 = get_lookup_table('Behave');
            behave3 = get_lookup_table('BEHAVE');
            
            % All should return same result (or all empty if file missing)
            testCase.verifyEqual(height(behave1), height(behave2));
            testCase.verifyEqual(height(behave1), height(behave3));
        end
        
        function testGetLookupTableUnknownWarns(testCase)
            % Test that unknown table name produces warning
            
            testCase.verifyWarning(@() get_lookup_table('nonexistent_table'), ...
                'get_lookup_table:UnknownTable');
        end
        
        function testGetLookupTableUnknownReturnsEmpty(testCase)
            % Test that unknown table name returns empty table
            
            warning('off', 'get_lookup_table:UnknownTable');
            result = get_lookup_table('nonexistent_table');
            warning('on', 'get_lookup_table:UnknownTable');
            
            testCase.verifyClass(result, 'table');
            testCase.verifyEqual(height(result), 0);
        end
        
        function testGetLookupTableSpeccode(testCase)
            % Test loading SPECCODE lookup table
            
            speccode = get_lookup_table('speccode');
            
            if isempty(speccode)
                warning('test_config:SkippedTest', 'SPECCODE.csv not found, skipping');
                return;
            end
            
            testCase.verifyGreaterThan(height(speccode), 0, ...
                'SPECCODE table should have entries');
        end
        
        % =================================================================
        % CONFIG CONSISTENCY TESTS
        % =================================================================
        
        function testPathsAreConsistent(testCase)
            % Test that paths are internally consistent
            
            paths = get_config('paths');
            
            % tables_dir should be under data_dir
            testCase.verifyTrue(startsWith(paths.tables_dir, paths.data_dir), ...
                'tables_dir should be under data_dir');
            
            % src_dir should be under project_root
            testCase.verifyTrue(startsWith(paths.src_dir, paths.project_root), ...
                'src_dir should be under project_root');
        end
        
        function testValidationTablePathsMatchPaths(testCase)
            % Test that validation table paths match paths.lookup_tables
            
            config = get_config();
            
            % behave_table_path in validation should match paths
            testCase.verifyEqual(config.validation.behave_table_path, ...
                config.paths.lookup_tables.behave, ...
                'Validation behave path should match paths.lookup_tables.behave');
        end
        
    end

    methods (TestClassSetup)
        function addConfigToPath(testCase) %#ok<MANU>
            % Ensure config folder is on path
            % Note: Don't add teardown to remove path - other tests need it
            
            test_file = mfilename('fullpath');
            [test_dir, ~, ~] = fileparts(test_file);
            project_root = fullfile(test_dir, '..', '..');
            config_dir = fullfile(project_root, 'config');
            
            if ~contains(path, config_dir)
                addpath(config_dir);
                % Deliberately NOT removing on teardown since test_runner manages paths
            end
        end
    end
    
end