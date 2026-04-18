function visualizationToolchainInfo = check_visualization_toolchain(printToConsole)
%CHECK_VISUALIZATION_TOOLCHAIN Inspect available visualization toolboxes.
%   Output:
%     visualizationToolchainInfo.hasAerospaceBlockset
%     visualizationToolchainInfo.hasSimulink3DAnimation
%     visualizationToolchainInfo.hasSimulation3DBlocks
%     visualizationToolchainInfo.recommendedVisualizationMode

if nargin < 1
    printToConsole = true;
end

v = ver;
names = string({v.Name});
hasAerospaceBlockset = any(names == "Aerospace Blockset");
hasSimulink3DAnimation = any(names == "Simulink 3D Animation");
hasSimulation3DBlocks = false;
try
    load_system('sim3dlib');
    hasSimulation3DBlocks = true;
    close_system('sim3dlib', 0);
catch
end

if hasSimulation3DBlocks
    recommendedMode = 'unreal_3d';
elseif hasSimulink3DAnimation || hasAerospaceBlockset
    recommendedMode = 'matlab_plot_only';
else
    recommendedMode = 'fallback_no_3d';
end

visualizationToolchainInfo = struct( ...
    'hasAerospaceBlockset', hasAerospaceBlockset, ...
    'hasSimulink3DAnimation', hasSimulink3DAnimation, ...
    'hasSimulation3DBlocks', hasSimulation3DBlocks, ...
    'recommendedVisualizationMode', recommendedMode);

if printToConsole
    fprintf('Visualization toolchain check\n');
    fprintf('  hasAerospaceBlockset: %d\n', hasAerospaceBlockset);
    fprintf('  hasSimulink3DAnimation: %d\n', hasSimulink3DAnimation);
    fprintf('  hasSimulation3DBlocks: %d\n', hasSimulation3DBlocks);
    fprintf('  recommendedVisualizationMode: %s\n', recommendedMode);
end
end
