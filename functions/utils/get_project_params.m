function Pcfg = get_project_params()
%GET_PROJECT_PARAMS Retrieve the shared project parameter struct.
%
%   Pcfg = get_project_params() returns the configuration struct that
%   scripts/init_project.m places in the base workspace under the name P.
%
%   This wraps the evalin('base','P') idiom used throughout the project.
%   The single point of access has two benefits over scattered evalin calls:
%     - it gives every dependent function a clear, greppable point of
%       coupling to the implicit global, making a future migration to
%       explicit parameter passing easier;
%     - it produces a clearer error message when callers forget to run
%       init_project first.

try
    Pcfg = evalin('base', 'P');
catch
    error('get_project_params:NotInitialized', ...
        ['Project parameters P were not found in the base workspace. ' ...
        'Run scripts/init_project.m before calling project functions.']);
end
end
