function merged = merge_flat_counts(a, b)
    % MERGE_FLAT_COUNTS Additively merge two flat rule_key -> count structs
    % (as produced by flatten_tally_map).
    merged = a;
    bf = fieldnames(b);
    for i = 1:numel(bf)
        k = bf{i};
        if isfield(merged, k)
            merged.(k) = merged.(k) + b.(k);
        else
            merged.(k) = b.(k);
        end
    end
end
