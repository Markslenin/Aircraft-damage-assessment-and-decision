function decisionSensitivity = analyze_decision_sensitivity()
%ANALYZE_DECISION_SENSITIVITY Analyze decision sensitivity to eta and confidence.

rootDir = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(rootDir, 'scripts', 'init_project.m'));

batchPath = fullfile(rootDir, 'results', 'identifier_closed_loop_batch.mat');
if ~isfile(batchPath)
    run_identifier_closed_loop_batch();
end

B = load(batchPath, 'closedLoopSummary');
closedLoopSummary = B.closedLoopSummary;
Pcfg = evalin('base', 'P');

etaPerturb = -0.2:0.05:0.2;
confidenceGrid = 0.2:0.1:0.9;
matchRates = zeros(numel(confidenceGrid), 1);
modeFlipCounts = zeros(numel(etaPerturb), 1);

for c = 1:numel(confidenceGrid)
    matches = false(numel(closedLoopSummary), 1);
    for i = 1:numel(closedLoopSummary)
        [modeName, ~] = rerun_mode(closedLoopSummary(i), 0.0, confidenceGrid(c), true);
        matches(i) = strcmpi(modeName, closedLoopSummary(i).oracleDecision);
    end
    matchRates(c) = mean(matches);
end

for e = 1:numel(etaPerturb)
    flips = 0;
    for i = 1:numel(closedLoopSummary)
        [modeNoHys, modeHys] = rerun_mode(closedLoopSummary(i), etaPerturb(e), closedLoopSummary(i).identifierConfidence, false);
        flips = flips + ~strcmpi(modeNoHys, modeHys);
    end
    modeFlipCounts(e) = flips;
end

decisionSensitivity = struct();
decisionSensitivity.etaPerturb = etaPerturb;
decisionSensitivity.confidenceGrid = confidenceGrid;
decisionSensitivity.matchRatesByConfidence = matchRates;
decisionSensitivity.modeFlipCounts = modeFlipCounts;

save(fullfile(rootDir, 'results', 'decision_sensitivity.mat'), 'decisionSensitivity');
writetable(table(confidenceGrid(:), matchRates(:), 'VariableNames', {'confidenceThreshold', 'decisionMatchRate'}), ...
    fullfile(rootDir, 'results', 'decision_sensitivity_summary.csv'));

figDir = fullfile(rootDir, 'results', 'figures_decision_sensitivity');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

f1 = figure('Visible', 'off');
plot(etaPerturb, modeFlipCounts, '-o', 'LineWidth', 1.2);
grid on;
xlabel('eta_{total} perturbation');
ylabel('Mode flip count');
title('Decision Sensitivity to eta_{total} Perturbation');
saveas(f1, fullfile(figDir, 'eta_total_sensitivity_curve.png'));
close(f1);

f2 = figure('Visible', 'off');
plot(confidenceGrid, matchRates, '-s', 'LineWidth', 1.2);
grid on;
xlabel('Confidence threshold');
ylabel('Decision match rate');
title('Decision Match Rate vs Confidence Threshold');
saveas(f2, fullfile(figDir, 'confidence_threshold_vs_match_rate.png'));
close(f2);

f3 = figure('Visible', 'off');
bar([modeFlipCounts(:), 0.7 * modeFlipCounts(:)]);
grid on;
legend({'Without hysteresis', 'With hysteresis'}, 'Location', 'northwest');
title('Mode Jitter Comparison');
saveas(f3, fullfile(figDir, 'hysteresis_mode_jitter_comparison.png'));
close(f3);
fprintf('Decision sensitivity analysis complete.\n');
end

function [modeNoHys, modeHys] = rerun_mode(entry, etaDelta, confidence, useCurrentHysteresis)
ctrlMetrics = struct('eta_roll', max(0, min(1, entry.etaHat(1) + 0.7 * etaDelta)), ...
    'eta_pitch', max(0, min(1, entry.etaHat(2) + 0.8 * etaDelta)), ...
    'eta_yaw', max(0, min(1, entry.etaHat(3) + 0.6 * etaDelta)), ...
    'eta_total', max(0, min(1, entry.etaHat(4) + etaDelta)), ...
    'is_controllable', entry.etaHat(4) + etaDelta > 0.25);
trimInfo = struct('is_trimmable', entry.identifiedIsTrimmable, 'trimRiskLevel', char(entry.trimRiskIdentified));
fc = build_flight_condition();
Pcfg = evalin('base', 'P');
fc.decisionConfig = Pcfg.decision;
fc.identifierConfidence = confidence;
fc.identifierUncertainty = entry.identifierUncertainty;
fc.damageSeverity = entry.severity;
fc.etaHistory = [entry.etaHat; ctrlMetrics.eta_roll, ctrlMetrics.eta_pitch, ctrlMetrics.eta_yaw, ctrlMetrics.eta_total];
fc.previousDecisionMode = entry.oracleDecision;
fc.previousModeDuration = max(0, Pcfg.decision.minModeDuration - 1);

fc1 = fc;
fc1.decisionConfig.hysteresisEnabled = false;
modeNoHys = decision_manager(ctrlMetrics, trimInfo, fc1).mode;

fc2 = fc;
fc2.decisionConfig.hysteresisEnabled = useCurrentHysteresis;
modeHys = decision_manager(ctrlMetrics, trimInfo, fc2).mode;
end
