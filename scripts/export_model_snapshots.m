function export_model_snapshots()
%EXPORT_MODEL_SNAPSHOTS Export main model and key subsystem snapshots.

rootDir = fileparts(fileparts(mfilename('fullpath')));
outDir = fullfile(rootDir, 'results', 'model_snapshots');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

run(fullfile(rootDir, 'scripts', 'init_project.m'));
run(fullfile(rootDir, 'scripts', 'generate_project.m'));
load_system(fullfile(rootDir, 'models', 'main_damaged_aircraft.slx'));

targets = { ...
    'main_damaged_aircraft', ...
    'main_damaged_aircraft/Online Damage Identifier', ...
    'main_damaged_aircraft/Visualization Interface', ...
    'main_damaged_aircraft/Decision_Logic'};
names = {'main_model', 'online_damage_identifier', 'visualization_interface', 'decision_logic'};

for i = 1:numel(targets)
    try
        open_system(targets{i});
        outPath = fullfile(outDir, [names{i} '.png']);
        print(['-s' targets{i}], '-dpng', outPath);
    catch ME
        fid = fopen(fullfile(outDir, [names{i} '_TODO.txt']), 'w');
        fprintf(fid, 'Automatic snapshot export failed for %s\n%s\n', targets{i}, ME.message);
        fprintf(fid, 'Fallback: open the subsystem in Simulink and export manually from the editor.\n');
        fclose(fid);
    end
end
bdclose('all');
end
