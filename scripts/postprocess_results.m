function postprocess_results()
%POSTPROCESS_RESULTS Create basic figures from batch scenario results.

rootDir = fileparts(fileparts(mfilename('fullpath')));
summaryPath = fullfile(rootDir, 'results', 'batch_run_summary.mat');
if ~isfile(summaryPath)
    run_batch_scenarios();
end

S = load(summaryPath, 'summaryTable');
summaryTable = S.summaryTable;

figDir = fullfile(rootDir, 'results', 'figures');

f1 = figure('Visible', 'off');
scatter(summaryTable.severity, summaryTable.eta_total, 70, double(categorical(summaryTable.scenarioType)), 'filled');
grid on;
xlabel('Damage Severity');
ylabel('eta\_total');
title('Damage Severity vs eta\_total');
save_figure(f1, fullfile(figDir, 'severity_vs_eta_total.png'));

f2 = figure('Visible', 'off');
modeCats = categorical(summaryTable.decisionMode);
modeCounts = countcats(modeCats);
bar(modeCounts);
set(gca, 'XTickLabel', categories(modeCats));
grid on;
xlabel('Decision Mode');
ylabel('Count');
title('Decision Mode Distribution');
save_figure(f2, fullfile(figDir, 'decision_mode_distribution.png'));

f3 = figure('Visible', 'off');
trimCats = categorical(string(summaryTable.is_trimmable), {'true', 'false'}, {'Trimmable', 'Not Trimmable'});
trimCounts = countcats(trimCats);
bar(trimCounts);
set(gca, 'XTickLabel', categories(trimCats));
grid on;
xlabel('Trim Feasibility');
ylabel('Count');
title('Trim Feasibility Statistics');
save_figure(f3, fullfile(figDir, 'trim_feasibility_statistics.png'));

fprintf('Postprocessing complete. Figures saved to %s\n', figDir);
end
