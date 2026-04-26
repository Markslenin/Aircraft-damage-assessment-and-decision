function errorBreakdown = analyze_identifier_error_breakdown()
%ANALYZE_IDENTIFIER_ERROR_BREAKDOWN Decompose identifier error sources.

rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'scripts', 'init_project.m'));

sweepPath = fullfile(rootDir, 'results', 'identifier_hyperparam_sweep.mat');
if ~isfile(sweepPath)
    run_identifier_hyperparam_sweep();
end

S = load(sweepPath, 'sweepResult');
sweepResult = S.sweepResult;
% Pre-count rows so the struct array can be preallocated rather than grown.
totalRows = 0;
for i = 1:numel(sweepResult.entries)
    totalRows = totalRows + numel(sweepResult.entries(i).trainingReport.testSampleMeta);
end
rows = repmat(struct( ...
    'damageCategory', "", 'damageSeverityLevel', "", ...
    'featureMode', "", 'modelType', "", ...
    'flightConditionTag', "", 'etaTotalError', 0), totalRows, 1);
rowIdx = 0;

for i = 1:numel(sweepResult.entries)
    entry = sweepResult.entries(i);
    meta = entry.trainingReport.testSampleMeta;
    err = entry.trainingReport.Yhat(:, end) - entry.trainingReport.Ytrue(:, end);
    featureMode = string(entry.config.featureMode);
    modelType = string(entry.config.modelType);
    for j = 1:numel(meta)
        rowIdx = rowIdx + 1;
        rows(rowIdx).damageCategory = string(meta(j).damageCategory);
        rows(rowIdx).damageSeverityLevel = string(meta(j).damageSeverityLevel);
        rows(rowIdx).featureMode = featureMode;
        rows(rowIdx).modelType = modelType;
        rows(rowIdx).flightConditionTag = string(meta(j).flightConditionTag);
        rows(rowIdx).etaTotalError = err(j);
    end
end

T = struct2table(rows);
errorBreakdown = struct();
errorBreakdown.byDamageCategory = compute_error_breakdown_stats(T.etaTotalError, T.damageCategory);
errorBreakdown.bySeverity = compute_error_breakdown_stats(T.etaTotalError, T.damageSeverityLevel);
errorBreakdown.byFeatureMode = compute_error_breakdown_stats(T.etaTotalError, T.featureMode);
errorBreakdown.byModelType = compute_error_breakdown_stats(T.etaTotalError, T.modelType);
errorBreakdown.byFlightCondition = compute_error_breakdown_stats(T.etaTotalError, T.flightConditionTag);
errorBreakdown.table = T;

save(fullfile(rootDir, 'results', 'error_breakdown.mat'), 'errorBreakdown', 'T');
writetable(T, fullfile(rootDir, 'results', 'error_breakdown_summary.csv'));

figDir = fullfile(rootDir, 'results', 'figures_error_breakdown');
plot_error_breakdown_figures(T, figDir);
fprintf('Identifier error breakdown analysis complete.\n');
end

function plot_error_breakdown_figures(T, figDir)
f1 = figure('Visible', 'off');
boxplot(abs(T.etaTotalError), categorical(T.damageCategory));
grid on;
ylabel('Absolute eta_{total} Error');
title('eta_{total} Error by Damage Category');
save_figure(f1, fullfile(figDir, 'error_boxplot_by_damage_category.png'));

sevOrder = categories(categorical(T.damageSeverityLevel));
mae = zeros(numel(sevOrder), 1);
rmse = zeros(numel(sevOrder), 1);
for i = 1:numel(sevOrder)
    idx = categorical(T.damageSeverityLevel) == sevOrder{i};
    mae(i) = mean(abs(T.etaTotalError(idx)));
    rmse(i) = sqrt(mean(T.etaTotalError(idx).^2));
end
f2 = figure('Visible', 'off');
plot(1:numel(sevOrder), mae, '-o', 1:numel(sevOrder), rmse, '-s', 'LineWidth', 1.2);
grid on;
set(gca, 'XTick', 1:numel(sevOrder), 'XTickLabel', sevOrder);
legend({'MAE', 'RMSE'}, 'Location', 'northwest');
title('Error vs Damage Severity');
save_figure(f2, fullfile(figDir, 'error_by_damage_severity.png'));

[featureCats, ~, iFeature] = unique(T.featureMode);
[modelCats, ~, iModel] = unique(T.modelType);
perfMat = nan(numel(modelCats), numel(featureCats));
for m = 1:numel(modelCats)
    for f = 1:numel(featureCats)
        idx = iModel == m & iFeature == f;
        perfMat(m, f) = mean(abs(T.etaTotalError(idx)));
    end
end
f3 = figure('Visible', 'off');
imagesc(perfMat);
colorbar;
set(gca, 'XTick', 1:numel(featureCats), 'XTickLabel', featureCats, 'YTick', 1:numel(modelCats), 'YTickLabel', modelCats);
xtickangle(25);
title('Model Type and Feature Mode Heatmap');
save_figure(f3, fullfile(figDir, 'model_feature_heatmap.png'));
end
