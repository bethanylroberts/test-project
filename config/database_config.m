% config/database_config.m
% 
% 2025 russ.shomberg@marineacoustics.com

classdef database_config
    properties (Constant)
        HOST = 'localhost'
        PORT = 3306
        DATABASE = 'NARWCDB'
        USER = 'matlab_api'
        % TODO: impliment security
        % Password via environment variable or secure storage
    end
end