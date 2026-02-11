function config = validation_config()
    % VALIDATION_CONFIG Configuration for validation rules

    % TODO: likely need a different config for porting the DB vs normal curation
    % FIXME: I do not think this is being used at all adding an error to pop if anything calls it
    error("Unexpected call of validation config")
    
    %% Coordinate validation
    config.coordinates.lat_range = [-90, 90];
    config.coordinates.lon_range = [-180, 180];
    config.coordinates.survey_lat_range = [35, 50];  % NARW typical range
    config.coordinates.survey_lon_range = [-75, -60];
    config.coordinates.check_land = false;  % Requires coastline data
    
    %% Temporal validation
    config.temporal.min_year = 1970;
    config.temporal.max_year = year(datetime('today')) + 1;  % Allow next year
    config.temporal.valid_months = 1:12;
    config.temporal.valid_days = 1:31;
    
    %% Species validation
    config.species.valid_codes = {
        'RIWH',  % Right Whale
        'FIWH',  % Fin Whale
        'HUWH',  % Humpback Whale
        'SEWH',  % Sei Whale
        'BLWH',  % Blue Whale
        'MIWH',  % Minke Whale
        'SPWH',  % Sperm Whale
        'UNCH',  % Unidentified cetacean
        'DOLA',  % Common Dolphin
        'GRSE',  % Gray Seal
        'HASE'   % Harbor Seal
    };

    % FIXME: check against DB look up tables
    
    %% Platform validation
    config.platform.altitude_range = [0, 5000];  % meters
    config.platform.beaufort_range = [0, 9];
    config.platform.visibility_range = [0, 50];  % nautical miles
    
    %% Behavioral validation
    config.behavioral.valid_codes = 0:99;  % Behavior codes
    
    %% Validation options
    config.options.treat_warnings_as_errors = false;
    config.options.stop_on_first_error = false;
end