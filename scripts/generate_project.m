function generate_project()
%GENERATE_PROJECT Create the MATLAB Project skeleton and rebuild the model.
%
%   Project plumbing only — folders, paths, startup file, shortcut. The
%   Simulink model itself is rebuilt by scripts/build_main_model.m, which
%   used to be inlined here as a single 478-line function. Splitting them
%   makes either half independently runnable: re-run generate_project to
%   re-attach folders, or call build_main_model(rootDir) to refresh the
%   model wiring without touching the Project metadata.

rootDir = fileparts(fileparts(mfilename('fullpath')));
projectName = "DamagedAircraftOnlineIDDecision";

dirs = ["models", "scripts", "functions", "data", "results", "docs"];
for d = dirs
    if ~exist(fullfile(rootDir, d), 'dir')
        mkdir(fullfile(rootDir, d));
    end
end

projFile = dir(fullfile(rootDir, "*.prj"));
if isempty(projFile)
    proj = matlab.project.createProject('Folder', rootDir, 'Name', projectName);
else
    proj = openProject(rootDir);
end

proj.addFolderIncludingChildFiles(fullfile(rootDir, "models"));
proj.addFolderIncludingChildFiles(fullfile(rootDir, "scripts"));
proj.addFolderIncludingChildFiles(fullfile(rootDir, "functions"));
proj.addFolderIncludingChildFiles(fullfile(rootDir, "data"));
proj.addFolderIncludingChildFiles(fullfile(rootDir, "results"));
proj.addFolderIncludingChildFiles(fullfile(rootDir, "docs"));

proj.addPath(fullfile(rootDir, "scripts"));
proj.addPath(fullfile(rootDir, "functions"));
proj.addPath(fullfile(rootDir, "data"));
proj.addStartupFile(fullfile(rootDir, "scripts", "init_project.m"));

try
    proj.addShortcut(fullfile(rootDir, "models", "main_damaged_aircraft.slx"));
catch
end

init_project();
build_main_model(rootDir);
disp("Project generation complete.");
end
