classdef TemplateFormat < narwc.io.parsers.BaseParser
    % TEMPLATEFORMAT Copy this file (and rename the class + filename
    % together, e.g. to CCSFormat.m / classdef CCSFormat) to add a new
    % contributor's format.
    %
    % See narwc.io.parsers.CCSAerialFormat or narwc.io.parsers.NEAQVesselFormat
    % for filled-in reference implementations of this exact pattern, and
    % narwc.io.parsers.StandardFormat for the legacy-CSV parser this pattern
    % was generalized from.
    %
    % PATTERN NOTES (read before copying):
    %
    % 1. All methods are Static, including parse() and detectFormat(),
    %    even though narwc.io.parsers.BaseParser declares parse(obj, file_path)
    %    as an abstract INSTANCE method. This is intentional, not a bug to
    %    "fix" -- MATLAB resolves instance.staticMethod(args) via dot-call
    %    sugar, so `parser = MyFormat(); parser.parse(file_path)` works.
    %    This is exercised by a real passing test
    %    (tests/unit/test_characterization_parser.m) -- do not change
    %    BaseParser to require instance methods; that would break the one
    %    thing proven to work end-to-end.
    %
    % 2. Don't hand-fabricate a full field layout you haven't verified
    %    against a real file from this contributor -- see CCSAerialFormat.m/
    %    NEAQVesselFormat.m for examples of FIELD_MAPPING built only from
    %    confirmed real headers, with a comment citing the sample file used.
    %
    % 3. If the raw files don't carry a FILEID column (true of every
    %    contributor parsed so far), see
    %    narwc.io.parsers.StandardFormat.fileidFromFilename() -- assign it
    %    to every row before remapToDatabase, or SurveyFileWriter silently
    %    drops the rows.
    %
    % 4. Always end parse() with StandardFormat.remapToDatabase() -- this
    %    is the shared helper that coerces any table into canonical
    %    FieldDefinitions.getDatabaseOrder() column order/typing,
    %    regardless of what the contributor's native columns look like.
    %
    % 5. The MATLAB class name MUST exactly match the filename. Rename
    %    both together, and do not leave a leading underscore or other
    %    non-letter-starting name -- MATLAB identifiers must start with a
    %    letter.
    %
    % 6. Register the new parser name in
    %    narwc.io.parsers.ParserFactory.getAvailableParsers() so it's
    %    selectable via ParserFactory.createByName().

    properties (Constant)
        FORMAT_NAME = 'TODO: Human-readable format name'
        DESCRIPTION = 'TODO: One-line description of this contributor''s file layout'

        % Native column name -> canonical DB field name, for whatever
        % columns you've actually confirmed (from a real sample file or
        % documented spec). Do not invent entries you haven't verified.
        FIELD_MAPPING = {
            % 'NativeColumnName', 'CANONICAL_DB_FIELD';
        };
    end

    methods (Static)
        function [data, metadata] = parse(file_path)
            % PARSE Parse a file in this contributor's format

            if ~exist(file_path, 'file')
                error('File not found: %s', file_path);
            end

            import_opts = narwc.io.parsers.TemplateFormat.createImportOptions(file_path);
            raw_data = readtable(file_path, import_opts);

            rename_map = narwc.io.parsers.TemplateFormat.FIELD_MAPPING;
            for i = 1:size(rename_map, 1)
                native_name = rename_map{i, 1};
                canonical_name = rename_map{i, 2};
                if ismember(native_name, raw_data.Properties.VariableNames)
                    raw_data = renamevars(raw_data, native_name, canonical_name);
                end
            end

            data = narwc.io.parsers.StandardFormat.remapToDatabase(raw_data);

            metadata.row_count = height(data);
            metadata.column_count = width(data);
            metadata.format = narwc.io.parsers.TemplateFormat.FORMAT_NAME;
        end

        function import_opts = createImportOptions(file_path)
            % CREATEIMPORTOPTIONS TODO: adjust header row / delimiter for
            % this contributor's actual file layout. detectImportOptions
            % reads whatever columns are actually present rather than
            % requiring a hardcoded positional field list -- prefer this
            % unless the format is headerless like the legacy CSV (see
            % StandardFormat.createImportOptions for that case instead).
            import_opts = detectImportOptions(file_path, ...
                'NumHeaderLines', 0, 'Delimiter', ',');
        end

        function confidence = detectFormat(file_path)
            % DETECTFORMAT TODO: score confidence based on distinctive,
            % confirmed column names or other real markers of this
            % contributor's format -- see NEAQVesselFormat.detectFormat for
            % the pattern (checks FIELD_MAPPING's native names against the
            % header row).

            try
                if ~exist(file_path, 'file')
                    confidence = 0;
                    return;
                end
                confidence = 0;   % TODO: implement
            catch
                confidence = 0;
            end
        end
    end
end
