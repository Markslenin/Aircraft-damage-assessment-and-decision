function exportPaths = export_demo_figures(vizResult, outputDir)
%EXPORT_DEMO_FIGURES Save demo-ready scenario figures to disk.

if nargin < 1 || isempty(vizResult)
    error('vizResult is required.');
end
if nargin < 2 || isempty(outputDir)
    rootDir = fileparts(fileparts(mfilename('fullpath')));
    outputDir = fullfile(rootDir, 'results', 'demo_figures');
end
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

baseName = regexprep(char(vizResult.scenarioName), '[^a-zA-Z0-9_-]', '_');
figNames = fieldnames(vizResult.figures);
exportPaths = struct();
for i = 1:numel(figNames)
    outPath = fullfile(outputDir, sprintf('%s_%s.png', baseName, figNames{i}));
    exportgraphics(vizResult.figures.(figNames{i}), outPath, 'Resolution', 160);
    exportPaths.(figNames{i}) = outPath;
end
end
