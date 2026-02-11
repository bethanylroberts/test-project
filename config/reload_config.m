function config = reload_config()
    % RELOAD_CONFIG Clear cached config and reload
    %
    % Use this after modifying configuration to pick up changes.
    
    clear get_config
    config = get_config();
    
    fprintf('Configuration reloaded from: %s\n', config.paths.project_root);
end