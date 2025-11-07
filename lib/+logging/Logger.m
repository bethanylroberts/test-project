classdef Logger < handle
    % LOGGER Simple logging wrapper class
    %
    % Usage:
    %   logger = logging.Logger('narwc.db.Connection');
    %   logger.debug('Debug message');
    %   logger.info('Info message');
    %   logger.warning('Warning message');
    %   logger.error('Error message');

    % TODO: integrate logging config into this
    
    properties
        component  % Component name (e.g., 'narwc.db.Connection')
    end
    
    methods
        function obj = Logger(component)
            % LOGGER Create logger for a component
            if nargin > 0
                obj.component = component;
            else
                obj.component = 'unknown';
            end
        end
        
        function debug(obj, message)
            % DEBUG Log debug message
            logging.debug(sprintf('[%s] %s', obj.component, message));
        end
        
        function info(obj, message)
            % INFO Log info message
            logging.info(sprintf('[%s] %s', obj.component, message));
        end
        
        function warning(obj, message)
            % WARNING Log warning message
            logging.warning(sprintf('[%s] %s', obj.component, message));
        end
        
        function error(obj, message)
            % ERROR Log error message
            logging.error(sprintf('[%s] %s', obj.component, message));
        end
        
        function critical(obj, message)
            % CRITICAL Log critical message
            logging.critical(sprintf('[%s] %s', obj.component, message));
        end
    end
end