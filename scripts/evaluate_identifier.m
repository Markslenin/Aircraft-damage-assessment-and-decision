function evalResult = evaluate_identifier()
%EVALUATE_IDENTIFIER Train and evaluate default P3.5 identifier models.

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
    get_identifier_model_config('shallow_mlp', 'residual_coupling_summary')};

evalEntries = struct('modelType', {}, 'identifierModel', {}, 'normalizationInfo', {}, 'trainingReport', {}, 'summaryTable', {});

for k = 1:numel(configs)
    [identifierModel, normalizationInfo, trainingReport] = train_damage_identifier(identifierDataset, configs{k});
    summaryTable = build_eval_table(trainingReport, trainingReport.targetNames, configs{k});
    evalEntries(k).modelType = identifierModel.modelType;
    evalEntries(k).identifierModel = identifierModel;
    evalEntries(k).normalizationInfo = normalizationInfo;
    evalEntries(k).trainingReport = trainingReport;
    evalEntries(k).summaryTable = summaryTable;
end

figDir = fullfile(rootDir, 'results', 'figures_identifier');
plot_identifier_figures(evalEntries(1), figDir);

summaryTable = vertcat(evalEntries.summaryTable);
save(fullfile(rootDir, 'results', 'identifier_eval.mat'), 'evalEntries', 'summaryTable');
writetable(summaryTable, fullfile(rootDir, 'results', 'identifier_eval_summary.csv'));

evalResult = struct('entries', evalEntries, 'summaryTable', summaryTable);
fprintf('Identifier evaluation complete for %d model configurations.\n', numel(evalEntries));
end

function tbl = build_eval_table(trainingReport, targetNames, cfg)
n = numel(targetNames);
tbl = table( ...
    repmat(string(trainingReport.modelType), n, 1), ...
    repmat(string(cfg.featureMode), n, 1), ...
    string(targetNames(:)), ...
    trainingReport.trainMae(:), ...
    trainingReport.valMae(:), ...
    trainingReport.testMae(:), ...
    trainingReport.testRmse(:), ...
    'VariableNames', {'modelType', 'featureMode', 'targetName', 'trainMae', 'valMae', 'testMae', 'testRmse'});
end

function plot_identifier_figures(evalEntry, figDir)
Ytrue = evalEntry.trainingReport.Ytrue;
Yhat = evalEntry.trainingReport.Yhat;
targetNames = evalEntry.trainingReport.targetNames;
testMeta = evalEntry.trainingReport.testSampleMeta;

f1 = figure('Visible', 'off');
scatter(Ytrue(:, end), Yhat(:, end), 30, 'filled');
grid on;
xlabel('eta_{total,true}');
ylabel('eta_{total,hat}');
title(sprintf('eta true vs eta hat (%s)', evalEntry.modelType));
save_figure(f1, fullfile(figDir, 'eta_true_vs_hat_scatter.png'));

f2 = figure('Visible', 'off');
bar([mean(abs(Yhat - Ytrue), 1); sqrt(mean((Yhat - Ytrue).^2, 1))].');
set(gca, 'XTickLabel', targetNames);
xtickangle(25);
legend({'MAE', 'RMSE'}, 'Location', 'northwest');
grid on;
ylabel('Error');
title('Identifier Channel Error Statistics');
save_figure(f2, fullfile(figDir, 'channel_error_statistics.png'));

cats = categorical(string({testMeta.damageCategory}));
f3 = figure('Visible', 'off');
boxplot(abs(Yhat(:, end) - Ytrue(:, end)), cats);
grid on;
ylabel('Absolute eta_{total} Error');
title('eta_{total} Error by Damage Category');
save_figure(f3, fullfile(figDir, 'damage_category_error_distribution.png'));
end
