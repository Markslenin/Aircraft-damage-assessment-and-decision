function rootDir = project_root(initIfNeeded)
%PROJECT_ROOT Resolve the repository root and optionally bootstrap the workspace.
%
%   rootDir = project_root() returns the absolute path of the repository root
%   (the parent of functions/ and scripts/) so that scripts can build paths
%   without hard-coded locations.
%
%   rootDir = project_root(true) additionally runs scripts/init_project.m.
%
%   Resolution order:
%     1. Walk up from this file
%        (functions/utils/project_root.m -> repo root).
%     2. Confirm the location by checking that scripts/init_project.m exists.
%
%   The function never assumes a particular working directory and is safe to
%   call from any script regardless of cd state.

if nargin < 1
    initIfNeeded = false;
end

% Walk up three levels: utils/ -> functions/ -> repo root.
thisFile = mfilename('fullpath');
rootDir = fileparts(fileparts(fileparts(thisFile)));

% Sanity check: the resolved root should contain the canonical project layout.
if ~isfile(fullfile(rootDir, 'scripts', 'init_project.m'))
    error('project_root:LayoutMismatch', ...
        'Could not locate scripts/init_project.m relative to %s. ', rootDir);
end

if initIfNeeded
    run(fullfile(rootDir, 'scripts', 'init_project.m'));
end
end
