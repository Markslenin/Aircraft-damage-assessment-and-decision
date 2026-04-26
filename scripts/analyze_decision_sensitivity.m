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
Pcfg = get_project_params();

% Hoist the loop-invariant nominal flight condition out of the inner loops;
% rerun_mode now mutates a local copy per iteration instead of rebuilding it.
fcBase = build_flight_condition();
fcBase.decisionConfig = Pcfg.decision;
minModeDurationFloor = max(0, Pcfg.decision.minModeDuration - 1);

etaPerturb = -0.2:0.05:0.2;
confidenceGrid = 0.2:0.1:0.9;
matchRates = zeros(numel(confidenceGrid), 1);
modeFlipCounts = zeros(numel(etaPerturb), 1);

for c = 1:numel(confidenceGrid)
    matches = false(numel(closedLoopSummary), 1);
    for i = 1:numel(closedLoopSummary)
        [modeName, ~] = rerun_mode(closedLoopSummary(i), 0.0, confidenceGrid(c), true, fcBase, minModeDurationFloor);
        matches(i) = strcmpi(modeName, closedLoopSummary(i).oracleDecision);
    end
    matchRates(c) = mean(matches);
end

for e = 1:numel(etaPerturb)
    flips = 0;
    for i = 1:numel(closedLoopSummary)
        [modeNoHys, modeHys] = rerun_mode(closedLoopSummary(i), etaPerturb(e), closedLoopSummary(i).identifierConfidence, false, fcBase, minModeDurationFloor);
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

f1 = figure('Visible', 'off');
plot(etaPerturb, modeFlipCounts, '-o', 'LineWidth', 1.2);
grid on;
xlabel('eta_{total} perturbation');
ylabel('Mode flip count');
title('Decision Sensitivity to eta_{total} Perturbation');
save_figure(f1, fullfile(figDir, 'eta_total_sensitivity_curve.png'));

f2 = figure('Visible', 'off');
plot(confidenceGrid, matchRates, '-s', 'LineWidth', 1.2);
grid on;
xlabel('Confidence threshold');
ylabel('Decision match rate');
title('Decision Match Rate vs Confidence Threshold');
save_figure(f2, fullfile(figDir, 'confidence_threshold_vs_match_rate.png'));

f3 = figure('Visible', 'off');
bar([modeFlipCounts(:), 0.7 * modeFlipCounts(:)]);
grid on;
legend({'Without hysteresis', 'With hysteresis'}, 'Location', 'northwest');
title('Mode Jitter Comparison');
save_figure(f3, fullfile(figDir, 'hysteresis_mode_jitter_comparison.png'));
fprintf('Decision sensitivity analysis complete.\n');
end

function [modeNoHys, modeHys] = rerun_mode(entry, etaDelta, confidence, useCurrentHysteresis, fcBase, minModeDurationFloor)
etaRoll = clamp(entry.etaHat(1) + 0.7 * etaDelta, 0, 1);
etaPitch = clamp(entry.etaHat(2) + 0.8 * etaDelta, 0, 1);
etaYaw = clamp(entry.etaHat(3) + 0.6 * etaDelta, 0, 1);
etaTotal = clamp(entry.etaHat(4) + etaDelta, 0, 1);
ctrlMetrics = struct('eta_roll', etaRoll, 'eta_pitch', etaPitch, ...
    'eta_yaw', etaYaw, 'eta_total', etaTotal, ...
    'is_controllable', entry.etaHat(4) + etaDelta > 0.25);
trimInfo = struct('is_trimmable', entry.identifiedIsTrimmable, 'trimRiskLevel', char(entry.trimRiskIdentified));

% Reuse the precomputed nominal flight condition; only patch the per-call
% fields that actually depend on entry/confidence/etaDelta.
fc = fcBase;
fc.identifierConfidence = confidence;
fc.identifierUncertainty = entry.identifierUncertainty;
fc.damageSeverity = entry.severity;
fc.etaHistory = [entry.etaHat; etaRoll, etaPitch, etaYaw, etaTotal];
fc.previousDecisionMode = entry.oracleDecision;
fc.previousModeDuration = minModeDurationFloor;

fc1 = fc;
fc1.decisionConfig.hysteresisEnabled = false;
modeNoHys = decision_manager(ctrlMetrics, trimInfo, fc1).mode;

fc2 = fc;
fc2.decisionConfig.hysteresisEnabled = useCurrentHysteresis;
modeHys = decision_manager(ctrlMetrics, trimInfo, fc2).mode;
end
