classdef ParserFactory
    % PARSERFACTORY Explicit, by-name parser selection.
    %
    % Usage:
    %   parser = narwc.io.parsers.ParserFactory.createByName('StandardFormat');
    %   [data, metadata] = parser.parse('survey.csv');
    %
    % Deliberately does NOT auto-detect format from file content -- the
    % caller (a migration script, or a routine-ingestion script mapping a
    % contributor's subfolder to its parser) always knows which parser to
    % use. See CLAUDE.md and CCSAerialFormat.m for how per-contributor
    % parsers plug into this.

    methods (Static)
        function parser = createByName(format_name)
            % CREATEBYNAME Create a parser instance for an explicit format name.
            parser_class = str2func(['narwc.io.parsers.' format_name]);
            parser = parser_class();
        end

        function parsers = getAvailableParsers()
            % GETAVAILABLEPARSERS Get list of available parser class names.
            parsers = {
                'StandardFormat'
                'CCSAerialFormat'
                'CCSVesselFormat'
                'CCSOpportunisticFormat'
                'NEAQVesselFormat'
                'NEAQAerialFormat'
                % TODO: Add more as contributor parsers are implemented
                % (NMFS-NEFSC, SEUS EWS -- see PROJECT_STATUS.md).
            };
        end

        function listFormats()
            % LISTFORMATS Display available formats.
            parsers = narwc.io.parsers.ParserFactory.getAvailableParsers();

            fprintf('\nAvailable Survey Formats:\n');
            fprintf('=========================\n\n');

            for i = 1:length(parsers)
                try
                    parser_class = str2func(['narwc.io.parsers.' parsers{i}]);
                    temp = parser_class();
                    fprintf('%d. %s\n', i, temp.FORMAT_NAME);
                    fprintf('   %s\n\n', temp.DESCRIPTION);
                catch
                    fprintf('%d. %s (error loading)\n\n', i, parsers{i});
                end
            end
        end
    end
end
