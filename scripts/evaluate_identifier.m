function evalResult = evaluate_identifier()
%EVALUATE_IDENTIFIER Train and evaluate baseline identifier models.

rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'scripts', 'init_project.m'));

datasetPath = fullfile(rootDir, 'data', 'identifier_dataset.mat');
if ~isfile(datasetPath)
    generate_identifier_dataset();
end

S = load(datasetPath, 'identifierDataset');
identifierDataset = S.identifierDataset;
baseConfig = identifierDataset.config;

modelTypes = {'ridge', 'mlp'};
evalEntries = struct('modelType', {}, 'identifierModel', {}, 'trainingReport', {}, 'summaryTable', {});

for k = 1:numel(modelTypes)
    cfg = baseConfig;
    cfg.primaryModelType = modelTypes{k};
    [identifierModel, trainingReport] = train_damage_identifier(identifierDataset, cfg);
    summaryTable = build_eval_table(trainingReport, cfg.targetNames);

    evalEntries(k).modelType = identifierModel.modelType;
    evalEntries(k).identifierModel = identifierModel;
    evalEntries(k).trainingReport = trainingReport;
    evalEntries(k).summaryTable = summaryTable;
end

figDir = fullfile(rootDir, 'results', 'figures_identifier');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

plot_identifier_figures(evalEntries(1), identifierDataset, figDir);

summaryTable = vertcat(evalEntries.summaryTable);
save(fullfile(rootDir, 'results', 'identifier_eval.mat'), 'evalEntries', 'summaryTable');
writetable(summaryTable, fullfile(rootDir, 'results', 'identifier_eval_summary.csv'));

evalResult = struct('entries', evalEntries, 'summaryTable', summaryTable);
fprintf('Identifier evaluation complete for %d model configurations.\n', numel(evalEntries));
end

function tbl = build_eval_table(trainingReport, targetNames)
rmse = trainingReport.rmse(:);
mae = trainingReport.mae(:);
tbl = table(repmat(string(trainingReport.modelType), numel(targetNames), 1), ...
    string(targetNames(:)), rmse, mae, ...
    'VariableNames', {'modelType', 'targetName', 'rmse', 'mae'});
end

function plot_identifier_figures(evalEntry, identifierDataset, figDir)
Ytrue = evalEntry.trainingReport.Ytrue;
Yhat = evalEntry.trainingReport.Yhat;
targetNames = evalEntry.trainingReport.targetNames;

f1 = figure('Visible', 'off');
scatter(Ytrue(:, end), Yhat(:, end), 70, 'filled');
grid on;
xlabel('eta_{total,true}');
ylabel('eta_{total,hat}');
title(sprintf('eta true vs eta hat (%s)', evalEntry.modelType));
saveas(f1, fullfile(figDir, 'eta_true_vs_hat_scatter.png'));
close(f1);

f2 = figure('Visible', 'off');
bar(mean(abs(Yhat - Ytrue), 1));
set(gca, 'XTickLabel', targetNames);
xtickangle(25);
grid on;
ylabel('MAE');
title('Identifier Channel Error Statistics');
saveas(f2, fullfile(figDir, 'channel_error_statistics.png'));
close(f2);

f3 = figure('Visible', 'off');
scenarioTypes = strings(numel(identifierDataset.samples), 1);
for i = 1:numel(identifierDataset.samples)
    scenarioTypes(i) = string(identifierDataset.samples(i).scenarioInfo.scenarioType);
end
testScenarioTypes = scenarioTypes(evalEntry.trainingReport.testIdx);
boxplot(abs(Yhat(:, end) - Ytrue(:, end)), categorical(testScenarioTypes));
grid on;
ylabel('Absolute eta_{total} Error');
title('eta_{total} Error by Damage Category');
saveas(f3, fullfile(figDir, 'damage_category_error_distribution.png'));
close(f3);
end
