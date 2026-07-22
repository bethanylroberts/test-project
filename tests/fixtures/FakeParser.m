classdef FakeParser < handle
    % FAKEPARSER Minimal parser stub for convert_contributor_batch tests.
    %
    % Duck-types the parse(file_path) contract any BaseParser subclass
    % satisfies, without needing a real per-contributor format. Returns
    % preset table(s) regardless of file content, and records call count
    % and the paths it was called with.
    %
    % Usage:
    %   parser = FakeParser(some_table);            % same table every call
    %   parser = FakeParser({table1, table2});       % one table per call, in order

    properties
        data_sequence cell = {}
        call_index = 0
        parse_call_count = 0
        parsed_paths = {}
    end

    methods
        function obj = FakeParser(data_or_sequence)
            if nargin > 0
                if iscell(data_or_sequence)
                    obj.data_sequence = data_or_sequence;
                else
                    obj.data_sequence = {data_or_sequence};
                end
            end
        end

        function [data, metadata] = parse(obj, file_path)
            obj.parse_call_count = obj.parse_call_count + 1;
            obj.parsed_paths{end+1} = file_path;
            obj.call_index = obj.call_index + 1;
            idx = min(obj.call_index, numel(obj.data_sequence));
            data = obj.data_sequence{idx};
            metadata = struct('row_count', height(data));
        end
    end
end
