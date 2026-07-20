function [flat, detail] = flatten_tally_map(m)
    % FLATTEN_TALLY_MAP Convert a rule_id-keyed containers.Map (as produced
    % by tally_validation_by_rule) into:
    %   flat   - struct, rule_key -> count (for chart/report code that wants
    %            a flat numeric struct)
    %   detail - struct, rule_key -> struct(rule_id, count, survey_count)

    flat = struct();
    detail = struct();
    keys_list = keys(m);
    for i = 1:numel(keys_list)
        key = keys_list{i};
        e = m(key);
        flat.(key) = e.count;
        detail.(key) = struct('rule_id', e.rule_id, 'count', e.count, ...
            'survey_count', numel(unique(e.fileids)));
    end
end
