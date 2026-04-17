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
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

f1 = figure('Visible', 'off');
scatter(summaryTable.severity, summaryTable.eta_total, 70, double(categorical(summaryTable.scenarioType)), 'filled');
grid on;
xlabel('Damage Severity');
ylabel('eta\_total');
title('Damage Severity vs eta\_total');
saveas(f1, fullfile(figDir, 'severity_vs_eta_total.png'));
close(f1);

f2 = figure('Visible', 'off');
modeCats = categorical(summaryTable.decisionMode);
modeCounts = countcats(modeCats);
bar(modeCounts);
set(gca, 'XTickLabel', categories(modeCats));
grid on;
xlabel('Decision Mode');
ylabel('Count');
title('Decision Mode Distribution');
saveas(f2, fullfile(figDir, 'decision_mode_distribution.png'));
close(f2);

f3 = figure('Visible', 'off');
trimCats = categorical(string(summaryTable.is_trimmable), {'true', 'false'}, {'Trimmable', 'Not Trimmable'});
trimCounts = countcats(trimCats);
bar(trimCounts);
set(gca, 'XTickLabel', categories(trimCats));
grid on;
xlabel('Trim Feasibility');
ylabel('Count');
title('Trim Feasibility Statistics');
saveas(f3, fullfile(figDir, 'trim_feasibility_statistics.png'));
close(f3);

fprintf('Postprocessing complete. Figures saved to %s\n', figDir);
end
