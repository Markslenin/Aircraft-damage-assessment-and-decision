function benchmarkResult = benchmark_identifier_models()
%BENCHMARK_IDENTIFIER_MODELS Legacy compact benchmark kept for compatibility.

rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'scripts', 'init_project.m'));

datasetPath = fullfile(rootDir, 'data', 'identifier_dataset_v3.mat');
if ~isfile(datasetPath)
    generate_identifier_dataset();
end

S = load(datasetPath, 'identifierDataset');
identifierDataset = S.identifierDataset;

configs = { ...
    get_identifier_model_config('ridge', 'normalized_summary'), ...
    get_identifier_model_config('shallow_mlp', 'summary_plus_residual_energy'), ...
    get_identifier_model_config('sequence_placeholder', 'hybrid_sequence_summary_v2')};

entries = struct('label', {}, 'identifierModel', {}, 'trainingReport', {});
summaryRows = [];

for i = 1:numel(configs)
    [identifierModel, ~, trainingReport] = train_damage_identifier(identifierDataset, configs{i});
    label = sprintf('%s + %s', configs{i}.modelType, configs{i}.featureMode);
    entries(i).label = label;
    entries(i).identifierModel = identifierModel;
    entries(i).trainingReport = trainingReport;
    summaryRows = [summaryRows; struct( ... %#ok<AGROW>
        'label', label, ...
        'eta_total_mae', trainingReport.testMae(end), ...
        'eta_total_rmse', trainingReport.testRmse(end), ...
        'eta_roll_mae', trainingReport.testMae(1), ...
        'eta_pitch_mae', trainingReport.testMae(2), ...
        'eta_yaw_mae', trainingReport.testMae(3))];
end

summaryTable = struct2table(summaryRows);

figDir = fullfile(rootDir, 'results', 'figures_identifier_benchmark');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end
plot_benchmark_figures(entries, summaryTable, identifierDataset, figDir);

benchmarkResult = struct('entries', entries, 'summaryTable', summaryTable);
save(fullfile(rootDir, 'results', 'identifier_benchmark.mat'), 'benchmarkResult', 'summaryTable');
writetable(summaryTable, fullfile(rootDir, 'results', 'identifier_benchmark_summary.csv'));
fprintf('Identifier benchmark complete for %d configurations.\n', numel(entries));
end

function plot_benchmark_figures(entries, summaryTable, identifierDataset, figDir)
f1 = figure('Visible', 'off');
bar(summaryTable.eta_total_mae);
set(gca, 'XTickLabel', summaryTable.label);
xtickangle(25);
grid on;
ylabel('eta_{total} MAE');
title('Benchmark: eta_{total} Error');
saveas(f1, fullfile(figDir, 'eta_total_error_comparison.png'));
close(f1);

f2 = figure('Visible', 'off');
vals = [summaryTable.eta_roll_mae, summaryTable.eta_pitch_mae, summaryTable.eta_yaw_mae];
bar(vals);
set(gca, 'XTickLabel', summaryTable.label);
xtickangle(25);
legend({'eta\_roll', 'eta\_pitch', 'eta\_yaw'}, 'Location', 'northwest');
grid on;
ylabel('MAE');
title('Benchmark: Channel MAE Comparison');
saveas(f2, fullfile(figDir, 'channel_mae_comparison.png'));
close(f2);

testIdx = entries(1).trainingReport.testIdx;
scenarioTypes = strings(numel(testIdx), 1);
for i = 1:numel(testIdx)
    scenarioTypes(i) = string(identifierDataset.samples(testIdx(i)).scenarioInfo.scenarioType);
end
groups = categories(categorical(scenarioTypes));
perf = zeros(numel(groups), numel(entries));
for j = 1:numel(entries)
    err = abs(entries(j).trainingReport.Yhat(:, end) - entries(j).trainingReport.Ytrue(:, end));
    for g = 1:numel(groups)
        perf(g, j) = mean(err(categorical(scenarioTypes) == groups{g}));
    end
end
f3 = figure('Visible', 'off');
bar(perf);
set(gca, 'XTickLabel', groups);
legend({entries.label}, 'Location', 'northwest');
grid on;
ylabel('eta_{total} MAE');
title('Benchmark: Damage Category Performance');
saveas(f3, fullfile(figDir, 'damage_category_performance.png'));
close(f3);
end
