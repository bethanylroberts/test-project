function ts = run_timestamp()
% RUN_TIMESTAMP Return a filename-safe timestamp for the current run.
%
% Format: YYYY-MM-DD_HH-MM-SS
% Used to disambiguate log files across runs. Generate once at run start
% and reuse throughout so all logs from the same run share the start-time stamp.

    ts = datestr(now, 'yyyy-mm-dd_HH-MM-SS'); %#ok<TNOW1,DATST>
end
