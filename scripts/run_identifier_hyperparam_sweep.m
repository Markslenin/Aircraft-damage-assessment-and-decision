function sweepResult = run_identifier_hyperparam_sweep()
%RUN_IDENTIFIER_HYPERPARAM_SWEEP Compare model/feature/filter configurations.

rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'scripts', 'init_project.m'));

datasetPath = fullfile(rootDir, 'data', 'identifier_dataset_v3.mat');
if ~isfile(datasetPath)
    generate_identifier_dataset();
end

D = load(datasetPath, 'identifierDataset');
identifierDataset = D.identifierDataset;

configs = build_sweep_configs();
entries = repmat(struct('config', [], 'identifierModel', [], 'trainingReport', [], 'etaTotalMae', NaN, 'decisionMatchRate', NaN), numel(configs), 1);

for i = 1:numel(configs)
    [identifierModel, ~, trainingReport] = train_damage_identifier(identifierDataset, configs{i});
    decisionStats = evaluate_model_decision_match(identifierDataset, identifierModel, trainingReport.testIdx);
    entries(i).config = configs{i};
    entries(i).identifierModel = identifierModel;
    entries(i).trainingReport = trainingReport;
    entries(i).etaTotalMae = trainingReport.testMae(end);
    entries(i).decisionMatchRate = decisionStats.matchRate;
    entries(i).controllabilityMatchRate = decisionStats.controllabilityMatchRate;
    entries(i).decisionStats = decisionStats;
end

summaryTable = build_sweep_table(entries);
[~, bestIndex] = min(summaryTable.etaTotalMae);
sweepResult = struct('entries', entries, 'summaryTable', summaryTable, 'bestIndex', bestIndex, 'bestConfig', entries(bestIndex).config);

save(fullfile(rootDir, 'results', 'identifier_hyperparam_sweep.mat'), 'sweepResult', 'summaryTable');
writetable(summaryTable, fullfile(rootDir, 'results', 'identifier_hyperparam_sweep_summary.csv'));

figDir = fullfile(rootDir, 'results', 'figures_hyperparam_sweep');
plot_sweep_figures(summaryTable, figDir);
fprintf('Hyperparameter sweep complete for %d configurations.\n', numel(entries));
end

function configs = build_sweep_configs()
spec = { ...
    {'ridge', 'normalized_summary', 'moving_average', 40, 'zscore'}, ...
    {'ridge', 'residual_coupling_summary', 'moving_average', 50, 'zscore'}, ...
    {'shallow_mlp', 'summary_plus_residual_energy', 'moving_average', 40, 'zscore'}, ...
    {'shallow_mlp', 'normalized_summary', 'lowpass_placeholder', 50, 'zscore'}, ...
    {'ensemble_summary', 'residual_coupling_summary', 'moving_average', 50, 'zscore'}, ...
    {'sequence_placeholder', 'hybrid_sequence_summary_v2', 'moving_average', 60, 'zscore'}};
configs = cell(size(spec));
for i = 1:numel(spec)
    row = spec{i};
    configs{i} = get_identifier_model_config(row{1}, row{2}, ...
        'residualFilterMode', row{3}, ...
        'sequenceLength', row{4}, ...
        'normalizationMode', row{5});
end
end

function stats = evaluate_model_decision_match(identifierDataset, identifierModel, testIdx)
n = numel(testIdx);
decisionMatch = false(n, 1);
controllabilityMatch = false(n, 1);
for i = 1:n
    sample = identifierDataset.samples(testIdx(i));
    % Reuse the cached sample to bypass simulate_identifier_timeseries.
    result = run_online_assessment_pipeline(sample.theta_d, identifierModel, identifierModel.config, 'identified', sample.scenarioInfo, sample);
    decisionMatch(i) = result.decisionMatch;
    controllabilityMatch(i) = result.controllabilityMatch;
end
stats = struct('matchRate', mean(decisionMatch), 'controllabilityMatchRate', mean(controllabilityMatch));
end

function tbl = build_sweep_table(entries)
n = numel(entries);
tbl = table('Size', [n 7], ...
    'VariableTypes', {'string', 'string', 'string', 'double', 'string', 'double', 'double'}, ...
    'VariableNames', {'modelType', 'featureMode', 'residualFilterMode', 'sequenceLength', 'normalizationMode', 'etaTotalMae', 'decisionMatchRate'});
for i = 1:n
    cfg = entries(i).config;
    tbl.modelType(i) = string(cfg.modelType);
    tbl.featureMode(i) = string(cfg.featureMode);
    tbl.residualFilterMode(i) = string(cfg.residualFilterMode);
    tbl.sequenceLength(i) = cfg.sequenceLength;
    tbl.normalizationMode(i) = string(cfg.normalizationMode);
    tbl.etaTotalMae(i) = entries(i).etaTotalMae;
    tbl.decisionMatchRate(i) = entries(i).decisionMatchRate;
end
tbl = sortrows(tbl, 'etaTotalMae', 'ascend');
end

function plot_sweep_figures(summaryTable, figDir)
f1 = figure('Visible', 'off');
bar(summaryTable.etaTotalMae);
set(gca, 'XTickLabel', strcat(summaryTable.modelType, " / ", summaryTable.featureMode));
xtickangle(35);
grid on;
ylabel('eta_{total} MAE');
title('Hyperparameter Sweep Ranking by eta_{total} MAE');
save_figure(f1, fullfile(figDir, 'eta_total_mae_ranking.png'));

f2 = figure('Visible', 'off');
bar(summaryTable.decisionMatchRate);
set(gca, 'XTickLabel', strcat(summaryTable.modelType, " / ", summaryTable.featureMode));
xtickangle(35);
grid on;
ylabel('Decision Match Rate');
title('Hyperparameter Sweep Ranking by Decision Match Rate');
save_figure(f2, fullfile(figDir, 'decision_match_rate_ranking.png'));

[featureCats, ~, iFeature] = unique(summaryTable.featureMode);
[modelCats, ~, iModel] = unique(summaryTable.modelType);
perfMat = nan(numel(modelCats), numel(featureCats));
for i = 1:height(summaryTable)
    perfMat(iModel(i), iFeature(i)) = summaryTable.etaTotalMae(i);
end
f3 = figure('Visible', 'off');
imagesc(perfMat);
colorbar;
set(gca, 'XTick', 1:numel(featureCats), 'XTickLabel', featureCats, 'YTick', 1:numel(modelCats), 'YTickLabel', modelCats);
xtickangle(30);
title('modelType x featureMode Performance Matrix');
save_figure(f3, fullfile(figDir, 'model_feature_performance_matrix.png'));
end
