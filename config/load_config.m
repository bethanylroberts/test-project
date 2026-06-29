function config = load_config(batch_name)
% LOAD_CONFIG Load merged configuration from defaults, local, and batch overrides.
%
% Args:
%   batch_name : string (optional) — name of a batch config in config/batches/
%
% Returns:
%   config : struct with merged settings (config.db, config.validation, config.pipeline)
%
% Merge order: defaults < local < batch (batch wins).
%
% Usage:
%   config = load_config()              % defaults + local, no batch
%   config = load_config('migration')   % adds migration batch overrides

    if nargin < 1
        batch_name = '';
    end

    this_dir = fileparts(mfilename('fullpath'));

    % Load defaults (always required)
    defaults_dir = fullfile(this_dir, 'defaults');
    if ~exist(defaults_dir, 'dir')
        error('load_config:MissingDefaults', ...
            'Required defaults directory not found: %s', defaults_dir);
    end
    addpath(defaults_dir);

    config.db         = db_config_default();
    config.validation = validation_config_default();
    config.pipeline   = pipeline_config_default();

    % Apply local overrides (gitignored, contains credentials)
    local_db_path = fullfile(this_dir, 'local', 'db_config_local.m');
    if exist(local_db_path, 'file')
        addpath(fullfile(this_dir, 'local'));
        local_db    = db_config_local();
        config.db   = merge_structs(config.db, local_db);
    end

    % Apply batch overrides
    if ~isempty(batch_name)
        batch_path = fullfile(this_dir, 'batches', [batch_name '.m']);
        if ~exist(batch_path, 'file')
            error('load_config:BatchNotFound', ...
                'Batch config not found: %s', batch_path);
        end
        addpath(fullfile(this_dir, 'batches'));
        overrides = feval(batch_name);
        config    = merge_structs(config, overrides);
    end
end

function base = merge_structs(base, override)
% Recursively overlay override fields onto base struct.
    if ~isstruct(override)
        return;
    end
    fields = fieldnames(override);
    for i = 1:numel(fields)
        f = fields{i};
        if isfield(base, f) && isstruct(base.(f)) && isstruct(override.(f))
            base.(f) = merge_structs(base.(f), override.(f));
        else
            base.(f) = override.(f);
        end
    end
end
