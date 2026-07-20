function [data, report] = apply_known_fixes(data, fileid)
% APPLY_KNOWN_FIXES Normalize Category C data quirks in a survey table.
%
% These corrections handle legitimate historical data-entry artifacts:
% sentinel values (99) used in older surveys as "not recorded" markers,
% non-standard strip numbering, trailing whitespace, etc.
%
% Args:
%   data   : table from CSV parse, pre-validation
%   fileid : string, the survey's FILEID (some fixes are FILEID-specific)
%
% Returns:
%   data   : table with corrections applied
%   report : struct with per-fix counts (e.g., report.photos_0_to_1 = 12)
%
% The eight fixes implemented match apply_known_fixes.sql exactly. Keep
% the two files in sync when adding new corrections.

    report.photos_0_to_1   = 0;
    report.strip_neaq_2021 = 0;
    report.beaufort_99     = 0;
    report.cloud_99        = 0;
    report.glarel_99       = 0;
    report.glarer_99       = 0;
    report.numcalf_99      = 0;
    report.speccode_trim   = 0;
    report.legtype_99      = 0;

    vars = data.Properties.VariableNames;

    % ── Fix 1: PHOTOS = 0 → 1 (sighting rows only) ───────────────────────
    % Valid PHOTOS codes start at 1; 0 was a legacy sentinel for "no photos"
    % before the code table was standardised. Only apply to sighting rows
    % (SPECCODE non-empty); effort-only rows have PHOTOS meaningfully absent.
    if ismember('PHOTOS', vars) && ismember('SPECCODE', vars)
        photos = data.PHOTOS;
        if isnumeric(photos)
            sighting = is_sighting_row(data.SPECCODE);
            mask = (photos == 0) & sighting & ~isnan(photos);
            if any(mask)
                data.PHOTOS(mask) = 1;
                report.photos_0_to_1 = sum(mask);
            end
        end
    end

    % ── Fix 2: STRIP > 16 → NaN for NEAq 2021 surveys ───────────────────
    % Surveys with FILEID matching 'a121*' used a non-standard strip
    % numbering convention that exceeded the valid range (1-16).
    if ismember('STRIP', vars) && strncmp(fileid, 'a121', 4)
        strip = data.STRIP;
        if isnumeric(strip)
            mask = (strip > 16) & ~isnan(strip);
            if any(mask)
                data.STRIP(mask) = NaN;
                report.strip_neaq_2021 = sum(mask);
            end
        end
    end

    % ── Fix 3: BEAUFORT = 99 → NaN ───────────────────────────────────────
    if ismember('BEAUFORT', vars)
        [data.BEAUFORT, report.beaufort_99] = replace_sentinel_99(data.BEAUFORT);
    end

    % ── Fix 4: CLOUD = 99 → NaN ──────────────────────────────────────────
    if ismember('CLOUD', vars)
        [data.CLOUD, report.cloud_99] = replace_sentinel_99(data.CLOUD);
    end

    % ── Fix 5: GLAREL = 99 → NaN and GLARER = 99 → NaN ──────────────────
    if ismember('GLAREL', vars)
        [data.GLAREL, report.glarel_99] = replace_sentinel_99(data.GLAREL);
    end
    if ismember('GLARER', vars)
        [data.GLARER, report.glarer_99] = replace_sentinel_99(data.GLARER);
    end

    % ── Fix 6: NUMCALF = 99 → NaN ────────────────────────────────────────
    if ismember('NUMCALF', vars)
        [data.NUMCALF, report.numcalf_99] = replace_sentinel_99(data.NUMCALF);
    end

    % ── Fix 7: SPECCODE trailing whitespace trim ──────────────────────────
    if ismember('SPECCODE', vars)
        speccode = data.SPECCODE;
        if iscell(speccode)
            nonempty = ~cellfun(@isempty, speccode);
            trimmed  = cellfun(@strtrim, speccode, 'UniformOutput', false);
            changed  = nonempty & ~cellfun(@strcmp, speccode, trimmed);
            if any(changed)
                data.SPECCODE(changed) = trimmed(changed);
                report.speccode_trim = sum(changed);
            end
        elseif isstring(speccode)
            trimmed = strtrim(speccode);
            changed = ~ismissing(speccode) & ~strcmp(speccode, trimmed);
            if any(changed)
                data.SPECCODE(changed) = trimmed(changed);
                report.speccode_trim = sum(changed);
            end
        end
    end

    % ── Fix 8: LEGTYPE = 99 → NaN ────────────────────────────────────────
    if ismember('LEGTYPE', vars)
        [data.LEGTYPE, report.legtype_99] = replace_sentinel_99(data.LEGTYPE);
    end

end


% =========================================================================
% Local helpers
% =========================================================================

function result = is_sighting_row(speccode)
% Return logical mask: true where SPECCODE indicates a sighting (non-empty).
    if iscell(speccode)
        result = ~cellfun(@isempty, speccode);
    elseif isstring(speccode)
        result = ~ismissing(speccode) & strlength(speccode) > 0;
    else
        result = false(height_of(speccode), 1);
    end
end

function n = height_of(col)
    n = numel(col);
end

function [col, n] = replace_sentinel_99(col)
% Replace numeric value 99 with NaN. Returns updated column and count.
    n = 0;
    if isnumeric(col)
        mask = (col == 99) & ~isnan(col);
        if any(mask)
            col(mask) = NaN;
            n = sum(mask);
        end
    end
end
