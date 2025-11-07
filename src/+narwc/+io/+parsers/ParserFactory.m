classdef ParserFactory
    % PARSERFACTORY Auto-detect format and return appropriate parser
    %
    % Usage:
    %   parser = narwc.io.parsers.ParserFactory.create('survey.csv');
    %   [data, metadata] = parser.read();
    
    methods (Static)
        function parser = create(file_path, format_hint)
            % CREATE Create appropriate parser for file
            %
            % Inputs:
            %   file_path - Path to survey file
            %   format_hint - Optional format name (bypasses auto-detection)
            %
            % Outputs:
            %   parser - Parser instance
            
            if nargin > 1 && ~isempty(format_hint)
                % Use specified format
                parser = narwc.io.parsers.ParserFactory.createByName(file_path, format_hint);
            else
                % Auto-detect format
                parser = narwc.io.parsers.ParserFactory.detectAndCreate(file_path);
            end
        end
        
        function parser = detectAndCreate(file_path)
            % DETECTANDCREATE Auto-detect format and create parser
            
            % Get all available parsers
            parsers = narwc.io.parsers.ParserFactory.getAvailableParsers();
            
            % Test each parser
            best_confidence = 0;
            best_parser = '';
            
            for i = 1:length(parsers)
                parser_name = parsers{i};
                parser_class = str2func(['narwc.io.parsers.' parser_name]);
                
                try
                    confidence = parser_class.detectFormat(file_path);
                    
                    if confidence > best_confidence
                        best_confidence = confidence;
                        best_parser = parser_name;
                    end
                catch ME
                    warning('Format detection failed for %s: %s', parser_name, ME.message);
                end
            end
            
            % Create parser
            if best_confidence > 0.5
                fprintf('Auto-detected format: %s (confidence: %.2f)\n', ...
                    best_parser, best_confidence);
                parser = narwc.io.parsers.ParserFactory.createByName(file_path, best_parser);
            else
                error('Could not detect file format. Please specify format explicitly.');
            end
        end
        
        function parser = createByName(file_path, format_name)
            % CREATEBYNAME Create parser by format name
            
            parser_class = str2func(['narwc.io.parsers.' format_name]);
            parser = parser_class(file_path);
        end
        
        function parsers = getAvailableParsers()
            % GETAVAILABLEPARSERS Get list of available parser classes
            
            parsers = {
                'StandardFormat'
                'LegacyFormat'
                'NEAQFormat'
                % TODO: Add more as implemented
            };
        end
        
        function listFormats()
            % LISTFORMATS Display available formats
            
            parsers = narwc.io.parsers.ParserFactory.getAvailableParsers();
            
            fprintf('\nAvailable Survey Formats:\n');
            fprintf('=========================\n\n');
            
            for i = 1:length(parsers)
                try
                    parser_class = str2func(['narwc.io.parsers.' parsers{i}]);
                    % Create dummy instance to get properties
                    temp = parser_class('dummy.txt');
                    fprintf('%d. %s\n', i, temp.FORMAT_NAME);
                    fprintf('   %s\n\n', temp.DESCRIPTION);
                catch
                    fprintf('%d. %s (error loading)\n\n', i, parsers{i});
                end
            end
        end
    end
end