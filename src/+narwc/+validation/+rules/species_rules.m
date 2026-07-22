function species_rules(data, collector, config)
    % SPECIES_RULES Validate species-related fields
    %
    % Checks: SPECCODE, TAXCODE, NUMBER, NUMCALF, and cross-field consistency.
    %
    % Inputs:
    %   data - Table with survey data
    %   collector - ErrorCollector instance
    %   config - Configuration struct

    if isfield(config, 'species')
        config = config.species;
    end

    if isempty(config.speccode_table)
        config = load_lookup_tables(config);
    end

    is_sighting = identify_sighting_records(data);

    if ismember('SPECCODE', data.Properties.VariableNames)
        validate_speccode(data, collector, config, is_sighting);
    end

    if ismember('TAXCODE', data.Properties.VariableNames)
        validate_taxcode(data, collector, config, is_sighting);
    end

    if ismember('NUMBER', data.Properties.VariableNames)
        validate_group_size(data, collector, config, is_sighting);
    end

    if ismember('NUMCALF', data.Properties.VariableNames)
        validate_calf_count(data, collector, config, is_sighting);
    end

    if ismember('SPECCODE', data.Properties.VariableNames) && ...
       ismember('TAXCODE', data.Properties.VariableNames)
        validate_speccode_taxcode_match(data, collector, config);
    end

    if ismember('NUMBER', data.Properties.VariableNames) && ...
       ismember('NUMCALF', data.Properties.VariableNames)
        validate_calves_vs_total(data, collector, config);
    end

    if ismember('SPECCODE', data.Properties.VariableNames)
        validate_right_whale_specific(data, collector, config);
    end
end

%% =========================================================================
%  LOOKUP TABLE LOADER
%% =========================================================================

function config = load_lookup_tables(config)
    speccode_file = fullfile(config.lookup_table_dir, 'SPECCODE.csv');
    if exist(speccode_file, 'file')
        try
            opts = detectImportOptions(speccode_file);
            opts = setvartype(opts, 'Value', 'char');
            if ismember('typical_max_group', opts.VariableNames)
                opts = setvartype(opts, 'typical_max_group', 'double');
            end
            if ismember('typical_max_calf', opts.VariableNames)
                opts = setvartype(opts, 'typical_max_calf', 'double');
            end
            config.speccode_table = readtable(speccode_file, opts);
            codes = config.speccode_table.Value;
            if iscell(codes)
                config.speccode_map = containers.Map(codes, num2cell(1:height(config.speccode_table)));
            else
                config.speccode_map = containers.Map(cellstr(codes), num2cell(1:height(config.speccode_table)));
            end
        catch ME
            warning('species_rules:LoadError', 'Failed to load SPECCODE table: %s', ME.message);
            config.speccode_table = [];
            config.speccode_map   = containers.Map();
        end
    else
        config.speccode_table = [];
        config.speccode_map   = containers.Map();
    end

    taxcode_file = fullfile(config.lookup_table_dir, 'TAXCODE.csv');
    if exist(taxcode_file, 'file')
        try
            config.taxcode_table = readtable(taxcode_file);
            codes = config.taxcode_table.Value;
            config.taxcode_map = containers.Map(codes, num2cell(1:height(config.taxcode_table)));
        catch ME
            warning('species_rules:LoadError', 'Failed to load TAXCODE table: %s', ME.message);
            config.taxcode_table = [];
            config.taxcode_map   = containers.Map();
        end
    else
        config.taxcode_table = [];
        config.taxcode_map   = containers.Map();
    end
end

%% =========================================================================
%  HELPERS
%% =========================================================================

function is_sighting = identify_sighting_records(data)
    num_records = height(data);
    is_sighting = false(num_records, 1);
    if ismember('SIGHTNO', data.Properties.VariableNames)
        has_sightno = ~isnan(data.SIGHTNO) & data.SIGHTNO > 0;
        is_sighting = is_sighting | has_sightno;
    end
    if ismember('NUMBER', data.Properties.VariableNames)
        has_number  = ~isnan(data.NUMBER) & data.NUMBER > 0;
        is_sighting = is_sighting | has_number;
    end
    if ismember('SPECCODE', data.Properties.VariableNames)
        platform_codes = {'AC-J', 'AC-P', 'AC-S', 'AC-T', 'BOAT', 'GEAR', 'DEBR'};
        if iscellstr(data.SPECCODE) || isstring(data.SPECCODE) %#ok<ISCLSTR>
            has_speccode = ~cellfun(@isempty, data.SPECCODE);
            is_platform  = ismember(upper(data.SPECCODE), platform_codes);
            is_sighting  = is_sighting | (has_speccode & ~is_platform);
        end
    end
end

function speccode_str = safe_get_speccode(data, idx)
    val = data.SPECCODE(idx);
    if ismissing(val) || (isstring(val) && strlength(val) == 0)
        speccode_str = '';
        return;
    end
    speccode_str = char(val);
end

function eventno = get_eventno(data, row)
    eventno = [];
    if ismember('EVENTNO', data.Properties.VariableNames)
        val = data.EVENTNO(row);
        if isnumeric(val) && ~isnan(val)
            eventno = val;
        end
    end
end

%% =========================================================================
%  VALIDATION FUNCTIONS
%% =========================================================================

function validate_speccode(data, collector, config, is_sighting)
    if isempty(data.SPECCODE) || all(ismissing(data.SPECCODE))
        return;
    end
    if ~(iscellstr(data.SPECCODE) || isstring(data.SPECCODE) || ischar(data.SPECCODE)) %#ok<ISCLSTR>
        collector.addError('SPECCODE', [], ...
            'SPECCODE column has unexpected data type', 'error', ...
            'species_rules.speccode_wrong_type');
        return;
    end
    num_records = height(data);
    for i = 1:num_records
        speccode = safe_get_speccode(data, i);
        if length(speccode) > 4
            eventno = get_eventno(data, i);
            collector.addError('SPECCODE', i, ...
                sprintf('SPECCODE "%s" exceeds 4 characters', speccode), 'error', ...
                'species_rules.speccode_too_long', eventno);
        end
    end
    if config.require_speccode_for_sightings
        for i = 1:num_records
            if is_sighting(i)
                speccode = safe_get_speccode(data, i);
                if isempty(speccode) || strcmp(strtrim(speccode), '')
                    eventno = get_eventno(data, i);
                    collector.addError('SPECCODE', i, ...
                        'SPECCODE is required for sighting records', 'error', ...
                        'species_rules.speccode_missing_for_sighting', eventno);
                end
            end
        end
    end
    if config.validate_speccode_lookup && ~isempty(config.speccode_map)
        for i = 1:num_records
            speccode = safe_get_speccode(data, i);
            if ~isempty(speccode) && ~isKey(config.speccode_map, speccode)
                eventno = get_eventno(data, i);
                collector.addError('SPECCODE', i, ...
                    sprintf('SPECCODE "%s" not found in species lookup table', speccode), ...
                    'error', 'species_rules.speccode_not_in_table', eventno);
            end
        end
    end
    for i = 1:num_records
        speccode = safe_get_speccode(data, i);
        if ~isempty(speccode)
            invalid_chars = regexprep(speccode, '[A-Za-z0-9\-]', '');
            if ~isempty(invalid_chars)
                eventno = get_eventno(data, i);
                collector.addError('SPECCODE', i, ...
                    sprintf('SPECCODE "%s" contains invalid characters: "%s"', speccode, invalid_chars), ...
                    'error', 'species_rules.speccode_invalid_chars', eventno);
            end
        end
    end
end

function validate_taxcode(data, collector, config, is_sighting)
    num_records = height(data);
    for i = 1:num_records
        taxcode = data.TAXCODE(i);
        if ~isnan(taxcode) && ~ismissing(taxcode)
            if ~ismember(taxcode, config.valid_taxcodes)
                eventno = get_eventno(data, i);
                collector.addError('TAXCODE', i, ...
                    sprintf('TAXCODE %d is not valid (must be 0-9)', taxcode), 'error', ...
                    'species_rules.taxcode_out_of_range', eventno);
            end
        end
    end
    if config.require_taxcode_for_sightings
        for i = 1:num_records
            if is_sighting(i)
                taxcode = data.TAXCODE(i);
                if isnan(taxcode) || ismissing(taxcode)
                    eventno = get_eventno(data, i);
                    collector.addError('TAXCODE', i, ...
                        'TAXCODE is required for sighting records', 'error', ...
                        'species_rules.taxcode_missing_for_sighting', eventno);
                end
            end
        end
    end
    if config.validate_taxcode_lookup && ~isempty(config.taxcode_map)
        for i = 1:num_records
            taxcode = data.TAXCODE(i);
            if ~isnan(taxcode) && ~ismissing(taxcode)
                if ~isKey(config.taxcode_map, taxcode)
                    eventno = get_eventno(data, i);
                    collector.addError('TAXCODE', i, ...
                        sprintf('TAXCODE %d not found in lookup table', taxcode), ...
                        'warning', 'species_rules.taxcode_not_in_table', eventno);
                end
            end
        end
    end
end

function validate_speccode_taxcode_match(data, collector, config)
    if ~config.validate_speccode_taxcode_match
        return;
    end
    if isempty(config.speccode_table) || ...
       ~ismember('TAXCODE', config.speccode_table.Properties.VariableNames)
        return;
    end
    num_records = height(data);
    for i = 1:num_records
        speccode = safe_get_speccode(data, i);
        taxcode  = data.TAXCODE(i);
        if isempty(speccode) || isnan(taxcode) || ismissing(taxcode)
            continue;
        end
        if isKey(config.speccode_map, speccode)
            table_row       = config.speccode_map(speccode);
            expected_taxcode = config.speccode_table.TAXCODE(table_row);
            if iscell(expected_taxcode)
                expected_taxcode = expected_taxcode{1};
            end
            if isempty(expected_taxcode) || ...
               (isnumeric(expected_taxcode) && isnan(expected_taxcode)) || ...
               (ischar(expected_taxcode) && strcmp(expected_taxcode, ''))
                continue;
            end
            if ischar(expected_taxcode) || isstring(expected_taxcode)
                expected_taxcode = str2double(expected_taxcode);
            end
            if ~isnan(expected_taxcode) && expected_taxcode ~= taxcode
                eventno = get_eventno(data, i);
                collector.addError('TAXCODE', i, ...
                    sprintf('TAXCODE mismatch: got %d, expected %d for SPECCODE "%s"', ...
                    taxcode, expected_taxcode, speccode), ...
                    'error', 'species_rules.speccode_taxcode_mismatch', eventno);
            end
        end
    end
end

function validate_group_size(data, collector, config, is_sighting)
    num_records   = height(data);
    has_speccode  = ismember('SPECCODE', data.Properties.VariableNames);
    has_taxcode   = ismember('TAXCODE',  data.Properties.VariableNames);
    for i = 1:num_records
        number = data.NUMBER(i);
        if isnan(number) || ismissing(number)
            continue;
        end
        if number < 0
            collector.addError('NUMBER', i, ...
                sprintf('NUMBER cannot be negative (got %d)', number), 'error', ...
                'species_rules.number_negative');
            continue;
        end
        if is_sighting(i) && number == 0
            eventno = get_eventno(data, i);
            collector.addError('NUMBER', i, ...
                'NUMBER is zero for sighting record', 'warning', ...
                'species_rules.number_zero_for_sighting', eventno);
        end
        speccode = '';
        if has_speccode
            speccode = safe_get_speccode(data, i);
        end
        taxcode = NaN;
        if has_taxcode
            tc = data.TAXCODE(i);
            if ~ismissing(tc) && ~isnan(tc)
                taxcode = tc;
            end
        end
        [threshold, source] = get_max_group_threshold(speccode, taxcode, config);
        if number > threshold
            eventno = get_eventno(data, i);
            collector.addError('NUMBER', i, ...
                sprintf('NUMBER=%d exceeds threshold %d for SPECCODE=%s (source: %s). Verify count.', ...
                number, threshold, speccode, source), 'warning', ...
                'species_rules.number_unusual', eventno);
        end
        if number ~= floor(number)
            collector.addError('NUMBER', i, ...
                sprintf('NUMBER must be an integer (got %.2f)', number), 'error', ...
                'species_rules.number_not_integer');
        end
    end
end

function validate_calf_count(data, collector, config, is_sighting) %#ok<INUSD>
    num_records  = height(data);
    has_speccode = ismember('SPECCODE', data.Properties.VariableNames);
    has_taxcode  = ismember('TAXCODE',  data.Properties.VariableNames);
    for i = 1:num_records
        numcalf = data.NUMCALF(i);
        if isnan(numcalf) || ismissing(numcalf)
            continue;
        end
        if numcalf < 0
            collector.addError('NUMCALF', i, ...
                sprintf('NUMCALF cannot be negative (got %d)', numcalf), 'error', ...
                'species_rules.numcalf_negative');
            continue;
        end
        speccode = '';
        if has_speccode
            speccode = safe_get_speccode(data, i);
        end
        taxcode = NaN;
        if has_taxcode
            tc = data.TAXCODE(i);
            if ~ismissing(tc) && ~isnan(tc)
                taxcode = tc;
            end
        end
        [threshold, source] = get_max_calf_threshold(speccode, taxcode, config);
        if numcalf > threshold
            eventno = get_eventno(data, i);
            collector.addError('NUMCALF', i, ...
                sprintf('NUMCALF=%d exceeds threshold %d for SPECCODE=%s (source: %s). Verify count.', ...
                numcalf, threshold, speccode, source), 'warning', ...
                'species_rules.numcalf_unusual', eventno);
        end
        if numcalf > 0 && has_taxcode && ~isnan(taxcode)
            if ~ismember(taxcode, config.marine_mammal_taxcodes)
                eventno = get_eventno(data, i);
                collector.addError('NUMCALF', i, ...
                    sprintf('NUMCALF=%d for non-mammal species (TAXCODE=%d)', ...
                    numcalf, taxcode), 'warning', ...
                    'species_rules.numcalf_non_mammal', eventno);
            end
        end
        if numcalf ~= floor(numcalf)
            collector.addError('NUMCALF', i, ...
                sprintf('NUMCALF must be an integer (got %.2f)', numcalf), 'error', ...
                'species_rules.numcalf_not_integer');
        end
    end
end

function validate_calves_vs_total(data, collector, config)
    num_records = height(data);
    for i = 1:num_records
        number  = data.NUMBER(i);
        numcalf = data.NUMCALF(i);
        if isnan(number) || isnan(numcalf) || ismissing(number) || ismissing(numcalf)
            continue;
        end
        if numcalf > number
            collector.addError('NUMCALF', i, ...
                sprintf('NUMCALF (%d) exceeds total NUMBER (%d)', numcalf, number), ...
                'error', 'species_rules.numcalf_exceeds_total');
        end
        if ~config.allow_numcalf_exceeds_half && numcalf > 0 && number > 0 && numcalf > number / 2
            eventno = get_eventno(data, i);
            collector.addError('NUMCALF', i, ...
                sprintf('NUMCALF (%d) is more than half of NUMBER (%d) - verify count', ...
                numcalf, number), 'warning', ...
                'species_rules.numcalf_exceeds_half', eventno);
        end
    end
end

function [t, source] = get_max_group_threshold(speccode, taxcode, config)
    % Cascade: SPECCODE override → TAXCODE default → global default
    if ~isempty(speccode) && ~isempty(config.speccode_table) && ...
            ismember('typical_max_group', config.speccode_table.Properties.VariableNames) && ...
            isKey(config.speccode_map, speccode)
        row_idx = config.speccode_map(speccode);
        val = config.speccode_table.typical_max_group(row_idx);
        if isnumeric(val) && ~isnan(val)
            t = val;
            source = 'SPECCODE override';
            return
        end
    end
    if ~isnan(taxcode) && ~isempty(config.taxcode_table) && ...
            ismember('typical_max_group', config.taxcode_table.Properties.VariableNames) && ...
            isKey(config.taxcode_map, taxcode)
        row_idx = config.taxcode_map(taxcode);
        val = config.taxcode_table.typical_max_group(row_idx);
        if isnumeric(val) && ~isnan(val)
            t = val;
            source = sprintf('TAXCODE %d default', taxcode);
            return
        end
    end
    t = config.thresholds.group_size_default;
    source = 'global default';
end

function [t, source] = get_max_calf_threshold(speccode, taxcode, config)
    % Cascade: SPECCODE override → TAXCODE default → global default
    if ~isempty(speccode) && ~isempty(config.speccode_table) && ...
            ismember('typical_max_calf', config.speccode_table.Properties.VariableNames) && ...
            isKey(config.speccode_map, speccode)
        row_idx = config.speccode_map(speccode);
        val = config.speccode_table.typical_max_calf(row_idx);
        if isnumeric(val) && ~isnan(val)
            t = val;
            source = 'SPECCODE override';
            return
        end
    end
    if ~isnan(taxcode) && ~isempty(config.taxcode_table) && ...
            ismember('typical_max_calf', config.taxcode_table.Properties.VariableNames) && ...
            isKey(config.taxcode_map, taxcode)
        row_idx = config.taxcode_map(taxcode);
        val = config.taxcode_table.typical_max_calf(row_idx);
        if isnumeric(val) && ~isnan(val)
            t = val;
            source = sprintf('TAXCODE %d default', taxcode);
            return
        end
    end
    t = config.thresholds.calf_count_default;
    source = 'global default';
end

function validate_right_whale_specific(data, collector, config)
    num_records  = height(data);
    has_number   = ismember('NUMBER',  data.Properties.VariableNames);
    has_numcalf  = ismember('NUMCALF', data.Properties.VariableNames);
    for i = 1:num_records
        speccode = safe_get_speccode(data, i);
        if ~ismember(upper(speccode), config.right_whale_codes)
            continue;
        end
        if has_number
            number = data.NUMBER(i);
            if ~isnan(number) && number > config.right_whale_max_group
                eventno = get_eventno(data, i);
                collector.addError('NUMBER', i, ...
                    sprintf('Right whale group size (%d) unusually large - verify count', number), ...
                    'warning', 'species_rules.right_whale_large_group', eventno);
            end
        end
        if has_numcalf
            numcalf = data.NUMCALF(i);
            if ~isnan(numcalf) && numcalf > config.right_whale_max_calves
                eventno = get_eventno(data, i);
                collector.addError('NUMCALF', i, ...
                    sprintf('Right whale calf count (%d) unusually high - verify count', numcalf), ...
                    'warning', 'species_rules.right_whale_high_calf_count', eventno);
            end
        end
    end
end
