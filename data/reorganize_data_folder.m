function reorganize_data_folder(options)
    % REORGANIZE_DATA_FOLDER One-time move from the pre-unification data/
    % layout to the current data/surveys/{raw,pending,processed,rejected,skipped}
    % layout described in data/README.md.
    %
    % This file lives inside data/, which is otherwise gitignored (data/*
    % except data/tables, data/README.md, and this file — see .gitignore) --
    % it's tracked as a one-time exception purely so it can be pulled onto
    % another machine (e.g. the Windows box with the real data/ folder).
    % Run it once on a machine whose data/ folder still has the old layout,
    % then delete it (and its .gitignore exception) once it's no longer needed.
    %
    % Old layout (pre-unification):
    %   data/raw/{incoming,pending,processed,rejected}/
    %   data/legacy/original_csv/
    %   data/legacy/surveys/{pending,processed,failed,skipped}/
    %
    % New layout (current):
    %   data/surveys/{raw,pending,processed,rejected,skipped}/
    %   data/surveys/raw/legacy/  (the legacy monolith CSV)
    %
    % Usage:
    %   reorganize_data_folder()               % dry run -- prints the plan, moves nothing
    %   reorganize_data_folder('Apply', true)   % actually performs the moves
    %
    % Safe to re-run: any old path that doesn't exist is silently skipped, and
    % moves are done file-by-file via movefile (never a bulk directory move),
    % so a name collision at the destination (e.g. partial re-run, or a real
    % file already dropped in the new location) surfaces as a reported error
    % for that one item rather than silently overwriting anything. Nothing is
    % ever deleted -- movefile relocates, and this script never removes the
    % old data/raw/ or data/legacy/ shells even once they're empty (delete
    % those yourself once you've confirmed everything landed correctly).

    arguments
        options.Apply logical = false
    end

    here = fileparts(mfilename('fullpath'));  % this file's own directory: data/

    old_raw            = fullfile(here, 'raw');
    old_legacy         = fullfile(here, 'legacy');
    new_surveys        = fullfile(here, 'surveys');

    mappings = {
        fullfile(old_raw, 'incoming'),                fullfile(new_surveys, 'raw');
        fullfile(old_raw, 'pending'),                 fullfile(new_surveys, 'pending');
        fullfile(old_raw, 'processed'),                fullfile(new_surveys, 'processed');
        fullfile(old_raw, 'rejected'),                 fullfile(new_surveys, 'rejected');
        fullfile(old_legacy, 'original_csv'),          fullfile(new_surveys, 'raw', 'legacy');
        fullfile(old_legacy, 'surveys', 'pending'),    fullfile(new_surveys, 'pending');
        fullfile(old_legacy, 'surveys', 'processed'),  fullfile(new_surveys, 'processed');
        fullfile(old_legacy, 'surveys', 'failed'),     fullfile(new_surveys, 'rejected');
        fullfile(old_legacy, 'surveys', 'skipped'),    fullfile(new_surveys, 'skipped');
    };

    if options.Apply
        fprintf('=== Reorganizing %s (APPLY mode -- files will be moved) ===\n\n', here);
    else
        fprintf('=== Reorganizing %s (DRY RUN -- nothing will be moved) ===\n', here);
        fprintf('    Re-run as reorganize_data_folder(''Apply'', true) to execute this plan.\n\n');
    end

    total_moved = 0;
    total_planned = 0;
    total_errors = 0;

    for i = 1:size(mappings, 1)
        src_dir = mappings{i, 1};
        dest_dir = mappings{i, 2};

        if ~exist(src_dir, 'dir')
            continue;  % nothing here -- skip silently, safe to re-run
        end

        entries = dir(src_dir);
        entries = entries(~ismember({entries.name}, {'.', '..'}));

        if isempty(entries)
            fprintf('%s -- empty, nothing to move\n', src_dir);
            continue;
        end

        fprintf('%s  ->  %s  (%d item(s))\n', src_dir, dest_dir, numel(entries));

        if options.Apply && ~exist(dest_dir, 'dir')
            mkdir(dest_dir);
        end

        for j = 1:numel(entries)
            src_item = fullfile(src_dir, entries(j).name);
            dest_item = fullfile(dest_dir, entries(j).name);
            total_planned = total_planned + 1;

            if options.Apply
                try
                    movefile(src_item, dest_item);
                    total_moved = total_moved + 1;
                catch ME
                    total_errors = total_errors + 1;
                    fprintf('  ERROR moving %s -> %s: %s\n', src_item, dest_item, ME.message);
                end
            else
                fprintf('  would move: %s -> %s\n', src_item, dest_item);
            end
        end
    end

    fprintf('\n');
    if options.Apply
        fprintf('Done. Moved %d item(s), %d error(s).\n', total_moved, total_errors);
        if total_errors > 0
            fprintf('Resolve the errors above manually -- nothing was deleted, so no data was lost.\n');
        end
        fprintf(['Once you''ve confirmed everything under %s looks right, you can manually delete\n' ...
            'the now-empty %s and %s folders.\n'], new_surveys, old_raw, old_legacy);
    else
        fprintf('Dry run complete: %d item(s) would be moved. No changes made.\n', total_planned);
    end
end
