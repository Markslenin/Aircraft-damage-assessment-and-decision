function decisionConsistency = evaluate_decision_consistency()
%EVALUATE_DECISION_CONSISTENCY Summarize closed-loop decision robustness.

rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'scripts', 'init_project.m'));

batchPath = fullfile(rootDir, 'results', 'identifier_closed_loop_batch.mat');
if ~isfile(batchPath)
    run_identifier_closed_loop_batch();
end

S = load(batchPath, 'closedLoopSummary');
closedLoopSummary = S.closedLoopSummary;

modes = {'NORMAL', 'RETURN', 'DIVERT', 'STABILIZE', 'EGRESS_PREP', 'UNRECOVERABLE'};
confMat = zeros(numel(modes));
for i = 1:numel(closedLoopSummary)
    r = find(strcmp(modes, upper(closedLoopSummary(i).oracleDecision)));
    c = find(strcmp(modes, upper(closedLoopSummary(i).identifiedDecision)));
    confMat(r, c) = confMat(r, c) + 1;
end

[precisionVals, recallVals] = compute_precision_recall(confMat);

decisionConsistency = struct();
decisionConsistency.averageEtaError = mean([closedLoopSummary.etaErrorMean]);
decisionConsistency.controllabilityMatchRate = mean([closedLoopSummary.controllabilityMatch]);
decisionConsistency.trimFeasibilityMatchRate = mean([closedLoopSummary.trimInfoConsistency]);
decisionConsistency.decisionModeMatchRate = mean([closedLoopSummary.decisionMatch]);
decisionConsistency.conservativeDecisionRate = mean([closedLoopSummary.conservativeDecision]);
decisionConsistency.conservativeCorrectCount = nnz([closedLoopSummary.conservativeCorrect]);
decisionConsistency.conservativeOvertriggerCount = nnz([closedLoopSummary.conservativeOvertrigger]);
decisionConsistency.unsafeUndertriggerCount = nnz([closedLoopSummary.unsafeUndertrigger]);
decisionConsistency.dangerousMismatchCount = nnz([closedLoopSummary.dangerousMismatch]);
decisionConsistency.modeConfusionMatrix = confMat;
decisionConsistency.perModePrecision = precisionVals;
decisionConsistency.perModeRecall = recallVals;

summaryTable = table( ...
    decisionConsistency.averageEtaError, ...
    decisionConsistency.controllabilityMatchRate, ...
    decisionConsistency.trimFeasibilityMatchRate, ...
    decisionConsistency.decisionModeMatchRate, ...
    decisionConsistency.conservativeDecisionRate, ...
    decisionConsistency.conservativeCorrectCount, ...
    decisionConsistency.conservativeOvertriggerCount, ...
    decisionConsistency.unsafeUndertriggerCount, ...
    decisionConsistency.dangerousMismatchCount, ...
    'VariableNames', {'averageEtaError', 'controllabilityMatchRate', 'trimFeasibilityMatchRate', ...
    'decisionModeMatchRate', 'conservativeDecisionRate', 'conservativeCorrectCount', ...
    'conservativeOvertriggerCount', 'unsafeUndertriggerCount', 'dangerousMismatchCount'});
save(fullfile(rootDir, 'results', 'decision_consistency.mat'), 'decisionConsistency', 'summaryTable', 'closedLoopSummary');
writetable(summaryTable, fullfile(rootDir, 'results', 'decision_consistency_summary.csv'));

decisionConsistencyV2 = decisionConsistency;
summaryTableV2 = summaryTable;
save(fullfile(rootDir, 'results', 'decision_consistency_v2.mat'), 'decisionConsistencyV2', 'summaryTableV2', 'closedLoopSummary');
writetable(summaryTableV2, fullfile(rootDir, 'results', 'decision_consistency_v2_summary.csv'));

figDir = fullfile(rootDir, 'results', 'figures_decision_consistency_v2');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end
plot_consistency_figures(decisionConsistency, confMat, modes, closedLoopSummary, figDir);

legacyFigDir = fullfile(rootDir, 'results', 'figures_decision_consistency');
if ~exist(legacyFigDir, 'dir')
    mkdir(legacyFigDir);
end
plot_consistency_figures(decisionConsistency, confMat, modes, closedLoopSummary, legacyFigDir);

fprintf('Decision consistency evaluation complete.\n');
end

function [precisionVals, recallVals] = compute_precision_recall(confMat)
precisionVals = diag(confMat) ./ max(sum(confMat, 1).', 1);
recallVals = diag(confMat) ./ max(sum(confMat, 2), 1);
end

function plot_consistency_figures(decisionConsistency, confMat, modes, closedLoopSummary, figDir)
f1 = figure('Visible', 'off');
bar([decisionConsistency.controllabilityMatchRate, ...
    decisionConsistency.trimFeasibilityMatchRate, ...
    decisionConsistency.decisionModeMatchRate, ...
    decisionConsistency.conservativeDecisionRate]);
set(gca, 'XTickLabel', {'Controllability', 'Trim', 'Decision', 'Conservative'});
ylim([0 1]);
grid on;
ylabel('Rate');
title('Decision Consistency Rates');
saveas(f1, fullfile(figDir, 'decision_consistency_rates.png'));
close(f1);

f2 = figure('Visible', 'off');
imagesc(confMat);
colorbar;
set(gca, 'XTick', 1:numel(modes), 'XTickLabel', modes, 'YTick', 1:numel(modes), 'YTickLabel', modes);
xtickangle(30);
title('Mode Confusion Matrix');
saveas(f2, fullfile(figDir, 'mode_confusion_matrix.png'));
close(f2);

f3 = figure('Visible', 'off');
bar([decisionConsistency.conservativeCorrectCount, ...
    decisionConsistency.conservativeOvertriggerCount, ...
    decisionConsistency.unsafeUndertriggerCount, ...
    decisionConsistency.dangerousMismatchCount]);
set(gca, 'XTickLabel', {'ConservativeCorrect', 'Overtrigger', 'UnsafeUndertrigger', 'Dangerous'});
xtickangle(20);
grid on;
ylabel('Count');
title('Decision Outcome Categories');
saveas(f3, fullfile(figDir, 'decision_outcome_categories.png'));
close(f3);

f4 = figure('Visible', 'off');
boxplot([closedLoopSummary.etaErrorMean], string({closedLoopSummary.damageCategory}));
grid on;
ylabel('Mean eta Error');
title('eta Error by Damage Category');
saveas(f4, fullfile(figDir, 'eta_error_by_category.png'));
close(f4);
end
