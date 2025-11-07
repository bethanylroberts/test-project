classdef Logger < handle
    % LOGGER Simple logging wrapper class
    %
    % Usage:
    %   logger = logging.Logger('narwc.db.Connection');
    %   logger.debug('Debug message');
    %   logger.info('Info message');
    %   logger.warning('Warning message');
    %   logger.error('Error message');
    
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
            safe_message = obj.escapeMessage(message);
            logging.debug(sprintf('[%s] %s', obj.component, safe_message));
        end
        
        function info(obj, message)
            % INFO Log info message
            safe_message = obj.escapeMessage(message);
            logging.info(sprintf('[%s] %s', obj.component, safe_message));
        end
        
        function warning(obj, message)
            % WARNING Log warning message
            safe_message = obj.escapeMessage(message);
            logging.warning(sprintf('[%s] %s', obj.component, safe_message));
        end
        
        function error(obj, message)
            % ERROR Log error message
            safe_message = obj.escapeMessage(message);
            logging.error(sprintf('[%s] %s', obj.component, safe_message));
        end
        
        function critical(obj, message)
            % CRITICAL Log critical message
            safe_message = obj.escapeMessage(message);
            logging.critical(sprintf('[%s] %s', obj.component, safe_message));
        end
    end
    
    methods (Access = private)
        function safe_message = escapeMessage(obj, message)
            % ESCAPEMESSAGE Escape backslashes for sprintf
            %
            % Windows paths contain backslashes which sprintf treats as
            % escape characters. This doubles them so they print correctly.

            % FIXME: if statements are slow
            
            if ischar(message) || isstring(message)
                safe_message = strrep(message, '\', '\\');
            else
                safe_message = message;
            end
        end
    end
end