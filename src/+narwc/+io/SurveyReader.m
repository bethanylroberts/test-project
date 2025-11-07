classdef SurveyReader < handle
    % SURVEYREADER Universal survey file reader
    %
    % Usage:
    %   reader = narwc.io.SurveyReader('survey.csv');
    %   [data, metadata] = reader.read();
    %   
    %   % Or with format hint
    %   reader = narwc.io.SurveyReader('survey.csv', 'FormatHint', 'LegacyFormat');
    %   data = reader.read();
    
    properties (Access = private)
        file_path
        parser
        logger
    end
    
    methods
        function obj = SurveyReader(file_path, options)
            % SURVEYREADER Constructor
            
            arguments
                file_path char
                options.FormatHint char = ''
            end
            
            obj.file_path = file_path;
            obj.logger = logging.Logger('narwc.io.SurveyReader');
            
            % Create appropriate parser
            obj.parser = narwc.io.parsers.ParserFactory.create(file_path, options.FormatHint);
            
            obj.logger.info(sprintf('Created %s parser', obj.parser.FORMAT_NAME));  % FIXME
        end
        
        function [data, metadata] = read(obj)
            % READ Read and parse survey file
            
            [data, metadata] = obj.parser.read();
        end
    end
end