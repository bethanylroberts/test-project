function available = has_live_db()
% HAS_LIVE_DB Return true if a live database connection is reachable.
%
% Result is cached in a persistent variable for the duration of the
% MATLAB session so the probe runs only once per test run.
%
% Usage (in TestClassSetup):
%   testCase.assumeTrue(has_live_db(), 'No live DB - test skipped');

persistent cached;

if ~isempty(cached)
    available = cached;
    return;
end

try
    conn = narwc.db.Connection.create();
    conn.fetch('SELECT 1');
    conn.close();
    cached = true;
catch
    cached = false;
end

available = cached;
end
