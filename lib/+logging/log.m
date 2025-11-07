% LOG this function will need to grow over time

function msg = log(tag,varargin)   

    % NOTE: to disable/enable logging (un)comment `return` statement below
    % return

    levels = ["DEBUG","INFO","WARNING","ERROR","CRITICAL","FATAL"];
    log_level = find(tag==levels);   

    % NOTE: to disable/enable log tag go to logging and (un)comment `return` statement at start of each individual function. This methodology is significicantly faster than using if or switch statements.

    % NOTE: could add branch here to disable log levels. However, it is faster to disable in actual functions

    LOGGING_LEVEL = 1;
    if log_level<LOGGING_LEVEL
        return
    end


    % NOTE: tags at or above RED_LEVEL are colored red on screen
    RED_LEVEL = 3; 
    cval = 1+double(log_level>=RED_LEVEL);   

    % Edit this to build log message
    msg = sprintf("[%s][%s] %s\n",datetime, pad(tag,8), sprintf(varargin{:}));

    % Include calling function in log if needed
    % stack = dbstack('-completenames');
    % calling_func = stack(3).name;
    % func_line = stack(3).line;
    % caller = stack(end).name;
    % msg = sprintf("[%s][%s] (%s:%d)\t%s\n",datetime, pad(tag,8), calling_func, func_line, sprintf(varargin{:}));


    % NOTE: (un)comment to change behavior. Commenting is faster than branching
    log2screen(msg,cval);
    % log2file(msg);

end

function log2screen(msg,cval)
    arguments
        msg string;
        cval double = 1; % 1 for black, 2 for red
    end
    fprintf(cval,"%s",msg);
end

function log2file(msg)
    arguments
        msg string;
    end
    fname = logging.get_fname();
    % Log to file
    f = fopen(fname,'a');
    fprintf(f,"%s",msg);
    fclose(f);
end