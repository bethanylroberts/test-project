function msg = warning(varargin)
    % return
    msg = logging.log("WARNING",varargin{:});
end