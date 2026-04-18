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

decisionConsistency = struct();
decisionConsistency.averageEtaError = mean([closedLoopSummary.etaErrorMean]);
decisionConsistency.controllabilityMatchRate = mean([closedLoopSummary.controllabilityMatch]);
decisionConsistency.trimFeasibilityMatchRate = mean([closedLoopSummary.trimInfoConsistency]);
decisionConsistency.decisionModeMatchRate = mean([closedLoopSummary.decisionMatch]);
decisionConsistency.conservativeDecisionRate = mean([closedLoopSummary.conservativeDecision]);
decisionConsistency.dangerousMismatchCount = nnz([closedLoopSummary.dangerousMismatch]);

summaryTable = struct2table(decisionConsistency);
save(fullfile(rootDir, 'results', 'decision_consistency.mat'), 'decisionConsistency', 'summaryTable', 'closedLoopSummary');
writetable(summaryTable, fullfile(rootDir, 'results', 'decision_consistency_summary.csv'));

figDir = fullfile(rootDir, 'results', 'figures_decision_consistency');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

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
bar([closedLoopSummary.etaErrorMean]);
grid on;
xlabel('Scenario');
ylabel('Mean eta Error');
title('eta Estimation Error by Scenario');
saveas(f2, fullfile(figDir, 'eta_error_by_scenario.png'));
close(f2);

f3 = figure('Visible', 'off');
bar([nnz([closedLoopSummary.dangerousMismatch]), numel(closedLoopSummary) - nnz([closedLoopSummary.dangerousMismatch])]);
set(gca, 'XTickLabel', {'Dangerous', 'Non-dangerous'});
grid on;
ylabel('Count');
title('Dangerous Mismatch Count');
saveas(f3, fullfile(figDir, 'dangerous_mismatch_count.png'));
close(f3);

fprintf('Decision consistency evaluation complete.\n');
end
